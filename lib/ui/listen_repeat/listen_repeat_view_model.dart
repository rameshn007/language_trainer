import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/language_item.dart';
import '../../main.dart';
import '../../services/dynamic_art_service.dart';
import '../../utils/logger.dart';

class ListenRepeatState {
  final LanguageItem? currentItem;
  final List<LanguageItem> pool;
  final List<LanguageItem> shuffledPool;
  final bool isPlaying;
  final int totalWordsSeen;
  final bool isSpeaking;
  final double playbackSpeed;

  ListenRepeatState({
    this.currentItem,
    this.pool = const [],
    this.shuffledPool = const [],
    this.isPlaying = false,
    this.totalWordsSeen = 0,
    this.isSpeaking = false,
    this.playbackSpeed = 1.0,
  });

  ListenRepeatState copyWith({
    LanguageItem? currentItem,
    List<LanguageItem>? pool,
    List<LanguageItem>? shuffledPool,
    bool? isPlaying,
    int? totalWordsSeen,
    bool? isSpeaking,
    double? playbackSpeed,
  }) {
    return ListenRepeatState(
      currentItem: currentItem ?? this.currentItem,
      pool: pool ?? this.pool,
      shuffledPool: shuffledPool ?? this.shuffledPool,
      isPlaying: isPlaying ?? this.isPlaying,
      totalWordsSeen: totalWordsSeen ?? this.totalWordsSeen,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }
}

class ListenRepeatViewModel extends Notifier<ListenRepeatState> {
  final Random _random = Random();
  bool _isAutoPlayActive = false;
  int _sessionId = 0;
  Future<void>? _generationFuture;
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  // ignore: deprecated_member_use
  ConcatenatingAudioSource? _playlist;
  final List<LanguageItem> _playlistWords = [];
  final List<LanguageItem> _shuffledPool = [];
  StreamSubscription? _currentIndexSubscription;

  @override
  ListenRepeatState build() {
    ref.onDispose(() {
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
      if (index == null || !_isAutoPlayActive) return;

      final wordIndex = index ~/ 4;
      if (wordIndex < _playlistWords.length) {
        final currentWord = _playlistWords[wordIndex];
        if (state.currentItem != currentWord) {
          state = state.copyWith(
            currentItem: currentWord,
            totalWordsSeen: wordIndex + 1,
          );
        }
      }

      // Pre-fetch next word when we are on the last word in the playlist
      if (wordIndex >= _playlistWords.length - 1) {
        _appendNextWordInBackground(_sessionId);
      }
    });

    return ListenRepeatState();
  }

  Future<void> startSession() async {
    AppLogger.log('[LR] startSession ENTER', name: 'ListenRepeat');
    if (state.isPlaying || _isAutoPlayActive) {
      AppLogger.log('[LR] startSession RETURNED (playing or active)', name: 'ListenRepeat');
      return;
    }

    final storage = ref.read(storageServiceProvider);
    AppLogger.log('[LR] storage: $storage', name: 'ListenRepeat');
    final allItems = storage.getAllItems();
    AppLogger.log('[LR] allItems count: ${allItems.length}', name: 'ListenRepeat');

    if (allItems.isEmpty) {
      AppLogger.log('[LR] No items yet, retrying in 1s...', name: 'ListenRepeat');
      await Future.delayed(const Duration(seconds: 1));
      AppLogger.log('[LR] Retrying startSession...', name: 'ListenRepeat');
      return await startSession();
    }
    AppLogger.log('[LR] Got ${allItems.length} items, proceeding...', name: 'ListenRepeat');

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
    
    // Show loading spinner immediately
    state = state.copyWith(isPlaying: true, currentItem: null);

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
      _isAutoPlayActive = false;
      _playlist = null;
      _playlistWords.clear();
      state = ListenRepeatState();
    }
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
        }
      } else if (_isAutoPlayActive && sessionId == _sessionId) {
        // Retry in background if failed
        await Future.delayed(const Duration(seconds: 2));
        if (_isAutoPlayActive && sessionId == _sessionId) {
          // Release lock before retrying so we don't deadlock
          completer.complete();
          _generationFuture = null;
          return _ensureNextWordAppended(sessionId);
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

    final wordIndexToGenerate = _playlistWords.length;
    final item = _shuffledPool[wordIndexToGenerate % _shuffledPool.length];
    AppLogger.log('[LR-gen] item: ${item.portuguese} (id=${item.id})', name: 'ListenRepeat');

    _playlistWords.add(item);

    try {
      final tts = ref.read(ttsServiceProvider);
      AppLogger.log('[LR-gen] tts: $tts', name: 'ListenRepeat');
      final dir = await getTemporaryDirectory();
      AppLogger.log('[LR-gen] temp dir: ${dir.path}', name: 'ListenRepeat');

      final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final ext = Platform.isAndroid ? 'wav' : 'caf';
      final ptFilePath = '${dir.path}/pt_$safeId.$ext';
      final enFilePath = '${dir.path}/en_$safeId.$ext';
      AppLogger.log('[LR-gen] pt: $ptFilePath', name: 'ListenRepeat');
      AppLogger.log('[LR-gen] en: $enFilePath', name: 'ListenRepeat');

      final ptFile = File(ptFilePath);
      final enFile = File(enFilePath);

      if (!ptFile.existsSync() || ptFile.lengthSync() == 0) {
        AppLogger.log('[LR-gen] synthesizing PT...', name: 'ListenRepeat');
        await tts.synthesizeToFile(item.portuguese, ptFilePath, language: 'pt-PT');
        AppLogger.log('[LR-gen] PT synthesize returned. Waiting for file to exist...', name: 'ListenRepeat');
        int attempts = 0;
        while ((!ptFile.existsSync() || ptFile.lengthSync() == 0) && attempts < 200 && sessionId == _sessionId) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }
        AppLogger.log('[LR-gen] PT after wait, exists: ${ptFile.existsSync()}, size: ${ptFile.existsSync() ? ptFile.lengthSync() : 0}', name: 'ListenRepeat');
      } else {
        AppLogger.log('[LR-gen] PT file already exists, size: ${ptFile.lengthSync()}', name: 'ListenRepeat');
      }

      if (sessionId != _sessionId) throw Exception("Session aborted");

      if (!enFile.existsSync() || enFile.lengthSync() == 0) {
        AppLogger.log('[LR-gen] synthesizing EN...', name: 'ListenRepeat');
        await tts.synthesizeToFile(item.english, enFilePath, language: 'en-US');
        AppLogger.log('[LR-gen] EN synthesize returned. Waiting for file to exist...', name: 'ListenRepeat');
        int attempts = 0;
        while ((!enFile.existsSync() || enFile.lengthSync() == 0) && attempts < 200 && sessionId == _sessionId) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }
        AppLogger.log('[LR-gen] EN after wait, exists: ${enFile.existsSync()}, size: ${enFile.existsSync() ? enFile.lengthSync() : 0}', name: 'ListenRepeat');
      } else {
        AppLogger.log('[LR-gen] EN file already exists, size: ${enFile.lengthSync()}', name: 'ListenRepeat');
      }

      if (!ptFile.existsSync() || ptFile.lengthSync() == 0) {
         AppLogger.log('[LR-gen] THROW: PT file missing or empty', name: 'ListenRepeat');
         throw Exception("Failed to synthesize Portuguese audio to disk");
      }

      AppLogger.log('[LR-gen] generating word art...', name: 'ListenRepeat');
      final artUri = await DynamicArtService.generateWordArt(item);
      AppLogger.log('[LR-gen] word art: $artUri', name: 'ListenRepeat');
      final mediaItem = MediaItem(
        id: 'listen_repeat_${item.id}_$wordIndexToGenerate',
        album: 'Language Trainer',
        title: item.portuguese,
        artist: item.english,
        artUri: artUri,
      );

      final sequence = [
        AudioSource.uri(Uri.file(ptFilePath), tag: mediaItem.copyWith(id: '${mediaItem.id}_pt')),
        AudioSource.asset('assets/audio/silence.mp3', tag: mediaItem.copyWith(id: '${mediaItem.id}_silence1')),
        AudioSource.uri(Uri.file(enFilePath), tag: mediaItem.copyWith(id: '${mediaItem.id}_en')),
        AudioSource.asset('assets/audio/silence.mp3', tag: mediaItem.copyWith(id: '${mediaItem.id}_silence2')),
      ];

      if (sessionId != _sessionId) throw Exception("Session aborted");

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
      }
      return null;
    }
  }

  Future<void> _appendNextWordInBackground(int sessionId) async {
    await _ensureNextWordAppended(sessionId);
  }

  Future<void> replayCurrentWord() async {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ 4;
    try {
      await _bgAudioPlayer.seek(Duration.zero, index: currentWordIndex * 4);
      await _bgAudioPlayer.play();
    } catch (e) {
      AppLogger.error('Non-fatal error replaying word', name: 'ListenRepeat', error: e);
    }
  }

  Future<void> nextWord() async {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null || _playlist == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ 4;
    final currentSessionId = _sessionId;

    if (currentWordIndex + 1 >= _playlistWords.length) {
      // Wait for it to be generated if we hit next too fast
      await _ensureNextWordAppended(currentSessionId);
    }

    // After waiting, check if session is still active
    if (currentSessionId != _sessionId || !_isAutoPlayActive) return;

    try {
      await _bgAudioPlayer.seek(Duration.zero, index: (currentWordIndex + 1) * 4);
    } catch (e) {
      AppLogger.error('Non-fatal error seeking to next word', name: 'ListenRepeat', error: e);
    }
  }
  
  Future<void> previousWord() async {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ 4;
    if (currentWordIndex > 0) {
      try {
        await _bgAudioPlayer.seek(Duration.zero, index: (currentWordIndex - 1) * 4);
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

  Future<void> stopSession() async {
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
    // Note: _shuffledPool is NOT cleared here — startSession() repopulates it
    // and stopSession may be called mid-startSession (e.g., when switching
    // from shuffle). Clearing it would destroy data needed by
    // _generateNextWordSequence().
    state = ListenRepeatState(playbackSpeed: state.playbackSpeed);
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

  void shufflePool() {
    if (state.pool.isEmpty) return;

    _shuffledPool.clear();
    _shuffledPool.addAll(state.pool);
    _shuffledPool.shuffle(_random);
    state = state.copyWith(shuffledPool: List.unmodifiable(_shuffledPool));

    startSession();
  }
}

final listenRepeatViewModelProvider =
    NotifierProvider<ListenRepeatViewModel, ListenRepeatState>(
      ListenRepeatViewModel.new,
    );


