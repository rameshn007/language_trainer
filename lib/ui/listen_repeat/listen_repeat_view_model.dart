import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/language_item.dart';
import '../../models/progress_data.dart';
import '../../main.dart';
import '../../services/dynamic_art_service.dart';
import '../../services/listen_repeat_content_service.dart';
import '../../services/progress_service.dart';
import '../../utils/logger.dart';
import '../../utils/tts_text_sanitizer.dart';

class ListenRepeatState {
  final LanguageItem? currentItem;
  final List<LanguageItem> pool;
  final List<LanguageItem> shuffledPool;
  final bool isPlaying;
  final int totalWordsSeen;
  final bool isSpeaking;
  final double playbackSpeed;
  final ListenRepeatMode mode;

  /// Non-null when a session failed to start. Surfaced in the UI so a broken
  /// session is not mistaken for an empty vocabulary.
  final String? failure;

  ListenRepeatState({
    this.currentItem,
    this.pool = const [],
    this.shuffledPool = const [],
    this.isPlaying = false,
    this.totalWordsSeen = 0,
    this.isSpeaking = false,
    this.playbackSpeed = 1.0,
    this.mode = ListenRepeatMode.all,
    this.failure,
  });

  ListenRepeatState copyWith({
    LanguageItem? currentItem,
    List<LanguageItem>? pool,
    List<LanguageItem>? shuffledPool,
    bool? isPlaying,
    int? totalWordsSeen,
    bool? isSpeaking,
    double? playbackSpeed,
    ListenRepeatMode? mode,
    String? failure,
  }) {
    return ListenRepeatState(
      currentItem: currentItem ?? this.currentItem,
      pool: pool ?? this.pool,
      shuffledPool: shuffledPool ?? this.shuffledPool,
      isPlaying: isPlaying ?? this.isPlaying,
      totalWordsSeen: totalWordsSeen ?? this.totalWordsSeen,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      mode: mode ?? this.mode,
      failure: failure ?? this.failure,
    );
  }
}

class ListenRepeatViewModel extends Notifier<ListenRepeatState> with WidgetsBindingObserver {
  static const int _kSourcesPerWord = 5;
  final Random _random = Random();
  bool _isAutoPlayActive = false;
  int _sessionId = 0;
  bool _isStarting = false;
  static const int _maxEmptyLoadAttempts = 5;
  Future<void>? _generationFuture;
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  // ignore: deprecated_member_use
  ConcatenatingAudioSource? _playlist;
  final List<LanguageItem> _playlistWords = [];
  final List<LanguageItem> _shuffledPool = [];
  StreamSubscription? _currentIndexSubscription;
  final Set<String> _failedItemIds = {};
  int _consecutiveFailures = 0;
  int _sessionConsecutiveFailures = 0;

  bool _isValidAudioFile(File file) {
    return file.existsSync() && file.lengthSync() > 512;
  }

  @override
  ListenRepeatState build() {
    WidgetsBinding.instance.addObserver(this);
    
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _bgAudioPlayer.dispose();
      _currentIndexSubscription?.cancel();
      _isAutoPlayActive = false;
    });

    _bgAudioPlayer.playingStream.listen((isPlaying) {
      if (state.isPlaying != isPlaying) {
        state = state.copyWith(isPlaying: isPlaying, isSpeaking: isPlaying);
      }
    });

    _currentIndexSubscription = _bgAudioPlayer.currentIndexStream.listen((index) {
      if (!_isAutoPlayActive) return;
      _syncCurrentIndex(index);
    });

    return ListenRepeatState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isAutoPlayActive) {
      // Dart stream events might be dropped while the isolate is suspended in background.
      // Manually sync the current word index when returning to the app.
      _syncCurrentIndex(_bgAudioPlayer.currentIndex);
    }
  }

  void _syncCurrentIndex(int? index) {
    if (index == null) return;
    final wordIndex = index ~/ _kSourcesPerWord;
    if (wordIndex < _playlistWords.length) {
      final currentWord = _playlistWords[wordIndex];
      if (state.currentItem != currentWord) {
        state = state.copyWith(
          currentItem: currentWord,
          totalWordsSeen: wordIndex + 1,
        );
      }
    }

    // Maintain a buffer of up to 3 words
    if (wordIndex >= _playlistWords.length - 3) {
      _appendNextWordInBackground(_sessionId);
    }
  }

  /// Guard so only one start attempt runs at a time.
  /// If a start is already in flight (e.g. during a rapid mode-switch),
  /// wait briefly for the previous attempt to abort or complete instead of
  /// silently dropping the call and leaving the UI stuck on "No words loaded".
  Future<void> startSession() async {
    int waitCount = 0;
    while (_isStarting && waitCount < 40) {
      await Future.delayed(const Duration(milliseconds: 50));
      waitCount++;
    }
    if (_isStarting) {
      AppLogger.log('[LR] startSession TIMED OUT waiting for previous start', name: 'ListenRepeat');
      return;
    }
    _isStarting = true;
    try {
      await _startSession();
    } catch (e, st) {
      // Also catches anything thrown outside the playback section (a closed
      // Hive box, say), which would otherwise surface as an unhandled async
      // error and leave the screen sitting on a spinner.
      AppLogger.log('[LR] startSession ERROR: $e', name: 'ListenRepeat');
      AppLogger.log('[LR] stack: $st', name: 'ListenRepeat');
      _reportFailure(_describeError(e));
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _startSession() async {
    AppLogger.log('[LR] startSession ENTER', name: 'ListenRepeat');
    if (state.isPlaying || _isAutoPlayActive) {
      AppLogger.log('[LR] startSession RETURNED (playing or active)', name: 'ListenRepeat');
      return;
    }

    // Cancel token for the waits below: stopSession() bumps _sessionId, and the
    // screen's dispose() calls stopSession(), so backing out mid-load aborts
    // the attempt instead of starting speech on a screen that is gone.
    final startingSessionId = _sessionId;

    final contentService = ref.read(listenRepeatContentServiceProvider);
    AppLogger.log('[LR] loading content for mode ${state.mode}...', name: 'ListenRepeat');
    var allItems = await contentService.loadContent(mode: state.mode);
    AppLogger.log('[LR] allItems count: ${allItems.length}', name: 'ListenRepeat');

    // The startup data load may still be in flight when this screen opens, so
    // give it a few seconds - but never forever. An endless retry left the
    // screen stuck on the "no words" message and hid the real failure.
    var attempts = 0;
    while (allItems.isEmpty && attempts < _maxEmptyLoadAttempts) {
      attempts++;
      state = ListenRepeatState(
        isPlaying: true,
        playbackSpeed: state.playbackSpeed,
        mode: state.mode,
      );
      AppLogger.log('[LR] no items yet, retry $attempts/$_maxEmptyLoadAttempts in 1s...', name: 'ListenRepeat');
      await Future.delayed(const Duration(seconds: 1));

      if (startingSessionId != _sessionId) {
        AppLogger.log('[LR] load wait aborted (session cancelled)', name: 'ListenRepeat');
        state = ListenRepeatState(
          playbackSpeed: state.playbackSpeed,
          mode: state.mode,
        );
        return;
      }
      allItems = await contentService.loadContent(mode: state.mode);
      AppLogger.log('[LR] retry $attempts count: ${allItems.length}', name: 'ListenRepeat');
    }

    if (allItems.isEmpty) {
      // Nothing to play, but nothing broken either. Keep the screen's empty
      // state ("add vocabulary") rather than the error panel: there is no
      // action a user can take on an empty library from an error screen.
      AppLogger.log('[LR] still no items after $attempts attempts - empty vocabulary', name: 'ListenRepeat');
      state = ListenRepeatState(
        playbackSpeed: state.playbackSpeed,
        mode: state.mode,
      );
      return;
    }

    AppLogger.log('[LR] Got ${allItems.length} items, proceeding...', name: 'ListenRepeat');

    _failedItemIds.clear();
    _consecutiveFailures = 0;
    _sessionConsecutiveFailures = 0;
    _shuffledPool.clear();
    _shuffledPool.addAll(allItems);
    _shuffledPool.shuffle(_random);
    AppLogger.log('[LR] shuffled ${_shuffledPool.length} items', name: 'ListenRepeat');

    AppLogger.log('[LR] calling stopSession...', name: 'ListenRepeat');
    await stopSession();
    AppLogger.log('[LR] stopSession done', name: 'ListenRepeat');

    _sessionId++;
    final currentSessionId = _sessionId;
    _isAutoPlayActive = true;
    _playlistWords.clear();
    _playlist = null;
    
    // Show loading spinner immediately. Built from scratch instead of via
    // copyWith so the previous session's word and failure message are cleared
    // (copyWith ignores nulls, which left the stale word on screen).
    state = ListenRepeatState(
      pool: allItems,
      shuffledPool: List.unmodifiable(_shuffledPool),
      isPlaying: true,
      playbackSpeed: state.playbackSpeed,
      mode: state.mode,
    );

    try {
      AppLogger.log('[LR] generating initial sequence...', name: 'ListenRepeat');
      await _ensureNextWordAppended(currentSessionId);
      
      if (currentSessionId != _sessionId) {
        AppLogger.log('[LR] Session aborted during start', name: 'ListenRepeat');
        return;
      }
      
      if (_playlistWords.isEmpty) {
        throw Exception("Failed to generate initial word sequence");
      }

      AppLogger.log('[LR] setting audio source...', name: 'ListenRepeat');
      await _bgAudioPlayer.setAudioSource(_playlist!);
      AppLogger.log('[LR] audio source set, ready to play.', name: 'ListenRepeat');

      state = ListenRepeatState(
        currentItem: _playlistWords.isNotEmpty ? _playlistWords.first : null,
        pool: allItems,
        shuffledPool: List.unmodifiable(_shuffledPool),
        isPlaying: true,
        isSpeaking: true,
        totalWordsSeen: 1,
        playbackSpeed: state.playbackSpeed,
        mode: state.mode,
      );
      _bgAudioPlayer.setSpeed(state.playbackSpeed);
      AppLogger.log('[LR] state updated, session started!', name: 'ListenRepeat');

      // Play immediately (do not await, as just_audio play() blocks until playback finishes)
      _bgAudioPlayer.play().catchError((e) {
        AppLogger.error('Error during playback', name: 'ListenRepeat', error: e);
      });
      AppLogger.log('[LR] playing started', name: 'ListenRepeat');
    } catch (e, st) {
      AppLogger.log('[LR] ERROR: $e', name: 'ListenRepeat');
      AppLogger.log('[LR] stack: $st', name: 'ListenRepeat');
      _reportFailure(_describeError(e));
    }
  }

  /// tears down the half-built session and shows why on screen.
  void _reportFailure(String reason) {
    _isAutoPlayActive = false;
    _playlist = null;
    _playlistWords.clear();
    state = ListenRepeatState(
      playbackSpeed: state.playbackSpeed,
      mode: state.mode,
      failure: 'Session could not start: $reason',
    );
  }

  /// Compact, readable form of a failure for the UI. Deliberately keeps the
  /// exception class and message: that detail is what makes an audio-session
  /// failure diagnosable from a screenshot.
  String _describeError(Object e) {
    final text = e.toString();
    return text.length > 180 ? '${text.substring(0, 177)}…' : text;
  }

  Future<void> _ensureNextWordAppended(int sessionId) async {
    // Wait for any ongoing generation to finish first (Mutex lock)
    while (_generationFuture != null) {
      await _generationFuture;
    }
    if (sessionId != _sessionId || !_isAutoPlayActive) return;

    final completer = Completer<void>();
    _generationFuture = completer.future;

    try {
      final sequence = await _generateNextWordSequence(sessionId);
      if (sequence != null && _isAutoPlayActive && sessionId == _sessionId) {
        if (_playlist == null) {
          // ignore: deprecated_member_use
          _playlist = ConcatenatingAudioSource(children: sequence);
        } else {
          await _playlist!.addAll(sequence);
          
          if (_isAutoPlayActive && state.isPlaying && _bgAudioPlayer.processingState == ProcessingState.completed) {
            AppLogger.log('[LR] Resuming playback after appending sequence (queue ran out)', name: 'ListenRepeat');
            _bgAudioPlayer.play().catchError((e) {
              AppLogger.error('Error auto-resuming', name: 'ListenRepeat', error: e);
            });
          }
        }
      } else if (_isAutoPlayActive && sessionId == _sessionId) {
        // Retry in background if failed
        await Future.delayed(const Duration(seconds: 2));
        if (_isAutoPlayActive && sessionId == _sessionId) {
          // Release lock before retrying so we don't deadlock
          completer.complete();
          _generationFuture = null;
          return await _ensureNextWordAppended(sessionId);
        }
      }
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
        _generationFuture = null;
      }
    }
  }

  Future<List<AudioSource>?> _generateNextWordSequence(int sessionId) async {
    if (!_isAutoPlayActive || _shuffledPool.isEmpty || sessionId != _sessionId) {
      AppLogger.log('[LR-gen] ABORT: !_isAutoPlayActive=$_isAutoPlayActive _shuffledPool.isEmpty=${_shuffledPool.isEmpty}', name: 'ListenRepeat');
      return null;
    }

    final candidates = _shuffledPool.where((item) => !_failedItemIds.contains(item.id)).toList();
    if (candidates.isEmpty) {
      AppLogger.log('[LR-gen] ABORT: all pool items failed', name: 'ListenRepeat');
      _reportFailure('All available words failed speech synthesis.');
      return null;
    }

    final wordIndexToGenerate = _playlistWords.length;
    final item = candidates[wordIndexToGenerate % candidates.length];
    AppLogger.log('[LR-gen] item: ${item.portuguese} (id=${item.id}, failed=${_failedItemIds.length})', name: 'ListenRepeat');

    _playlistWords.add(item);

    try {
      final tts = ref.read(ttsServiceProvider);
      AppLogger.log('[LR-gen] tts: $tts', name: 'ListenRepeat');
      final dir = await getTemporaryDirectory();
      AppLogger.log('[LR-gen] temp dir: ${dir.path}', name: 'ListenRepeat');

      final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final ext = Platform.isAndroid ? 'wav' : 'caf';
      final ptFilePath = '${dir.path}/pt_v2_$safeId.$ext';
      final enFilePath = '${dir.path}/en_v2_$safeId.$ext';
      AppLogger.log('[LR-gen] pt: $ptFilePath', name: 'ListenRepeat');
      AppLogger.log('[LR-gen] en: $enFilePath', name: 'ListenRepeat');

      final ptFile = File(ptFilePath);
      final enFile = File(enFilePath);

      // Sanitize text before synthesizing speech
      final cleanPt = TtsTextSanitizer.sanitizePt(item.portuguese);
      final cleanEn = TtsTextSanitizer.sanitizeEn(item.english);
      final ptToSpeak = cleanPt.isNotEmpty ? cleanPt : item.portuguese;
      final enToSpeak = cleanEn.isNotEmpty ? cleanEn : item.english;

      if (!_isValidAudioFile(ptFile)) {
        AppLogger.log('[LR-gen] synthesizing PT...', name: 'ListenRepeat');
        await tts.synthesizeToFile(ptToSpeak, ptFilePath, language: 'pt-PT');
        AppLogger.log('[LR-gen] PT synthesize returned. Waiting for file to exist...', name: 'ListenRepeat');
        int attempts = 0;
        while (!_isValidAudioFile(ptFile) && attempts < 200 && sessionId == _sessionId) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }
        AppLogger.log('[LR-gen] PT after wait, exists: ${ptFile.existsSync()}, size: ${ptFile.existsSync() ? ptFile.lengthSync() : 0}', name: 'ListenRepeat');
      } else {
        AppLogger.log('[LR-gen] PT file already exists, size: ${ptFile.lengthSync()}', name: 'ListenRepeat');
      }

      if (sessionId != _sessionId) throw Exception("Session aborted");

      if (!_isValidAudioFile(enFile)) {
        AppLogger.log('[LR-gen] synthesizing EN...', name: 'ListenRepeat');
        await tts.synthesizeToFile(enToSpeak, enFilePath, language: 'en-US');
        AppLogger.log('[LR-gen] EN synthesize returned. Waiting for file to exist...', name: 'ListenRepeat');
        int attempts = 0;
        while (!_isValidAudioFile(enFile) && attempts < 200 && sessionId == _sessionId) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }
        AppLogger.log('[LR-gen] EN after wait, exists: ${enFile.existsSync()}, size: ${enFile.existsSync() ? enFile.lengthSync() : 0}', name: 'ListenRepeat');
      } else {
        AppLogger.log('[LR-gen] EN file already exists, size: ${enFile.lengthSync()}', name: 'ListenRepeat');
      }

      if (!_isValidAudioFile(ptFile)) {
         AppLogger.log('[LR-gen] THROW: PT file missing or empty', name: 'ListenRepeat');
         throw Exception("Failed to synthesize Portuguese audio to disk");
      }

      AppLogger.log('[LR-gen] generating word art...', name: 'ListenRepeat');
      final artUri = await DynamicArtService.generateWordArt(item);
      AppLogger.log('[LR-gen] word art: $artUri', name: 'ListenRepeat');
      final mediaItem = MediaItem(
        id: 'listen_repeat_${item.id}_$wordIndexToGenerate',
        album: item.notes.isNotEmpty ? item.notes : 'Language Trainer',
        title: item.portuguese,
        artist: item.english,
        artUri: artUri,
      );

      // Sequence with 5 sources per word:
      // PT -> Silence 1 -> Silence 2 (~2.1s repetition pause) -> EN -> Silence 3 (~1.0s)
      final sequence = [
        AudioSource.uri(Uri.file(ptFilePath), tag: mediaItem.copyWith(id: '${mediaItem.id}_pt')),
        AudioSource.asset('assets/audio/silence.mp3', tag: mediaItem.copyWith(id: '${mediaItem.id}_silence1')),
        AudioSource.asset('assets/audio/silence.mp3', tag: mediaItem.copyWith(id: '${mediaItem.id}_silence2')),
        AudioSource.uri(Uri.file(enFilePath), tag: mediaItem.copyWith(id: '${mediaItem.id}_en')),
        AudioSource.asset('assets/audio/silence.mp3', tag: mediaItem.copyWith(id: '${mediaItem.id}_silence3')),
      ];

      if (sessionId != _sessionId) throw Exception("Session aborted");

      _consecutiveFailures = 0;
      _sessionConsecutiveFailures = 0;
      AppLogger.log('[LR-gen] SUCCESS: returning ${sequence.length} audio sources', name: 'ListenRepeat');
      return sequence;

    } catch (e, st) {
      if (sessionId == _sessionId) {
        AppLogger.log('[LR-gen] ERROR: $e', name: 'ListenRepeat');
        AppLogger.log('[LR-gen] stack: $st', name: 'ListenRepeat');
        AppLogger.error('Error in _generateNextWordSequence', name: 'ListenRepeat', error: e);
        if (_playlistWords.isNotEmpty && _playlistWords.last == item) {
          _playlistWords.removeLast(); // Revert the addition if it was the last one added
        }

        // Poison-pill protection: If an item fails twice, skip it and track its ID
        _consecutiveFailures++;
        _sessionConsecutiveFailures++;
        if (_consecutiveFailures >= 2) {
          _failedItemIds.add(item.id);
          _consecutiveFailures = 0;
          AppLogger.log('[LR-gen] Skipped failing item ${item.id} (${_failedItemIds.length} failed total)', name: 'ListenRepeat');
        }

        // Wholesale TTS failure check: if 6 consecutive attempts fail overall across items
        if (_sessionConsecutiveFailures >= 6) {
          AppLogger.log('[LR-gen] Wholesale synthesis failure: $_sessionConsecutiveFailures consecutive failures', name: 'ListenRepeat');
          _reportFailure('Audio synthesis repeatedly failed ($e)');
          return null;
        }
      }
      return null;
    }
  }

  Future<void> _appendNextWordInBackground(int sessionId) async {
    while (_playlistWords.length - ((_bgAudioPlayer.currentIndex ?? 0) ~/ _kSourcesPerWord) < 3) {
      if (sessionId != _sessionId || !_isAutoPlayActive) break;
      // Yield heavily to the event loop to prevent UI jank, especially on start
      await Future.delayed(const Duration(seconds: 1));
      if (sessionId != _sessionId || !_isAutoPlayActive) break;
      
      await _ensureNextWordAppended(sessionId);
    }
  }

  Future<void> replayCurrentWord() async {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ _kSourcesPerWord;
    try {
      await _bgAudioPlayer.seek(Duration.zero, index: currentWordIndex * _kSourcesPerWord);
      await _bgAudioPlayer.play();
    } catch (e) {
      AppLogger.error('Non-fatal error replaying word', name: 'ListenRepeat', error: e);
    }
  }

  Future<void> nextWord() async {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null || _playlist == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ _kSourcesPerWord;
    final currentSessionId = _sessionId;

    if (currentWordIndex + 1 >= _playlistWords.length) {
      // Wait for it to be generated if we hit next too fast
      await _ensureNextWordAppended(currentSessionId);
    }

    // After waiting, check if session is still active
    if (currentSessionId != _sessionId || !_isAutoPlayActive) return;

    try {
      await _bgAudioPlayer.seek(Duration.zero, index: (currentWordIndex + 1) * _kSourcesPerWord);
    } catch (e) {
      AppLogger.error('Non-fatal error seeking to next word', name: 'ListenRepeat', error: e);
    }
  }
  
  Future<void> previousWord() async {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ _kSourcesPerWord;
    if (currentWordIndex > 0) {
      try {
        await _bgAudioPlayer.seek(Duration.zero, index: (currentWordIndex - 1) * _kSourcesPerWord);
      } catch (e) {
        AppLogger.error('Non-fatal error seeking to previous word', name: 'ListenRepeat', error: e);
      }
    } else {
      await replayCurrentWord();
    }
  }

  Future<void> togglePlayPause() async {
    if (_bgAudioPlayer.playing) {
      await pause();
    } else {
      if (_isAutoPlayActive) {
        await _bgAudioPlayer.play();
      } else {
        await startSession();
      }
    }
  }

  Future<void> pause() async {
    try {
      await _bgAudioPlayer.pause();
    } catch (e) {
      AppLogger.error('Non-fatal error pausing audio player', name: 'ListenRepeat', error: e);
    }
    state = state.copyWith(isPlaying: false);
  }

  Future<int> stopSession() async {
    _sessionId++; // Invalidate any ongoing generation for this session
    _isAutoPlayActive = false;
    try {
      await _bgAudioPlayer.stop();
      await _bgAudioPlayer.seek(Duration.zero);
    } catch (e) {
      // seek after stop can throw on just_audio_background (native handler
      // is already torn down). Ignore — we are stopping the session anyway.
      AppLogger.error('Non-fatal error stopping audio player', name: 'ListenRepeat', error: e);
    }
    _playlist = null;
    _playlistWords.clear();
    
    int earnedXP = 0;
    if (state.totalWordsSeen > 0) {
      // Award 2 XP per word seen for Listen & Repeat
      final sessionXP = state.totalWordsSeen * 2;
      earnedXP = await ref.read(progressServiceProvider.notifier).recordSessionComplete(
        storage: ref.read(storageServiceProvider),
        activityType: ActivityType.listenRepeat,
        score: state.totalWordsSeen,
        total: state.totalWordsSeen,
        sessionXP: sessionXP,
      );
    }

    // Note: _shuffledPool is NOT cleared here — startSession() repopulates it
    // and stopSession may be called mid-startSession (e.g., when switching
    // from shuffle). Clearing it would destroy data needed by
    // _generateNextWordSequence().
    state = ListenRepeatState(
      playbackSpeed: state.playbackSpeed,
      mode: state.mode,
    );
    return earnedXP;
  }

  double cycleSpeed() {
    double newSpeed = state.playbackSpeed;
    if (newSpeed == 1.0) {
      newSpeed = 1.25;
    } else if (newSpeed == 1.25) {
      newSpeed = 1.5;
    } else if (newSpeed == 1.5) {
      newSpeed = 0.5;
    } else if (newSpeed == 0.5) {
      newSpeed = 0.75;
    } else {
      newSpeed = 1.0;
    }
    _bgAudioPlayer.setSpeed(newSpeed);
    state = state.copyWith(playbackSpeed: newSpeed);
    return newSpeed;
  }

  Future<void> setMode(ListenRepeatMode newMode) async {
    if (state.mode == newMode) return;
    state = state.copyWith(mode: newMode);
    await stopSession();
    await startSession();
  }

  Future<void> shufflePool() async {
    if (state.pool.isEmpty) return;

    _shuffledPool.clear();
    _shuffledPool.addAll(state.pool);
    _shuffledPool.shuffle(_random);
    state = state.copyWith(shuffledPool: List.unmodifiable(_shuffledPool));

    // A plain startSession() while playing hits the "already playing" 
    // guard, so the reshuffled deck would be ignored and the current 
    // playlist would keep playing in its old order. Tear the session down
    // first so the shuffle actually takes effect.
    if (_isAutoPlayActive) {
      await stopSession();
    }
    await startSession();
  }
}

final listenRepeatViewModelProvider =
    NotifierProvider<ListenRepeatViewModel, ListenRepeatState>(
      ListenRepeatViewModel.new,
    );


