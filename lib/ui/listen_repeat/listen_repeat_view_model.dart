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

  ListenRepeatState({
    this.currentItem,
    this.pool = const [],
    this.shuffledPool = const [],
    this.isPlaying = false,
    this.totalWordsSeen = 0,
    this.isSpeaking = false,
  });

  ListenRepeatState copyWith({
    LanguageItem? currentItem,
    List<LanguageItem>? pool,
    List<LanguageItem>? shuffledPool,
    bool? isPlaying,
    int? totalWordsSeen,
    bool? isSpeaking,
  }) {
    return ListenRepeatState(
      currentItem: currentItem ?? this.currentItem,
      pool: pool ?? this.pool,
      shuffledPool: shuffledPool ?? this.shuffledPool,
      isPlaying: isPlaying ?? this.isPlaying,
      totalWordsSeen: totalWordsSeen ?? this.totalWordsSeen,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

class ListenRepeatViewModel extends Notifier<ListenRepeatState> {
  final Random _random = Random();
  bool _isAutoPlayActive = false;
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  // ignore: deprecated_member_use
  ConcatenatingAudioSource? _playlist;
  final List<LanguageItem> _playlistWords = [];
  StreamSubscription? _currentIndexSubscription;

  @override
  ListenRepeatState build() {
    ref.onDispose(() {
      _bgAudioPlayer.dispose();
      _currentIndexSubscription?.cancel();
      _isAutoPlayActive = false;
    });

    _bgAudioPlayer.playingStream.listen((isPlaying) {
      if (state.isPlaying != isPlaying && _isAutoPlayActive) {
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
        _appendNextWordInBackground();
      }
    });

    return ListenRepeatState();
  }

  Future<void> startSession() async {
    AppLogger.log("startSession() called", name: 'ListenRepeat');
    if (state.isPlaying || _isAutoPlayActive) return;

    final storage = ref.read(storageServiceProvider);
    final allItems = storage.getAllItems();

    if (allItems.isEmpty) return;

    final shuffled = List<LanguageItem>.from(allItems)..shuffle(_random);

    state = ListenRepeatState(
      pool: allItems,
      shuffledPool: shuffled,
      isPlaying: true,
      totalWordsSeen: 0,
    );

    _isAutoPlayActive = true;
    _playlistWords.clear();
    _playlist = null;
    
    try {
      final initialSequence = await _generateNextWordSequence();
      if (initialSequence == null) {
        throw Exception("Failed to generate initial word sequence");
      }
      
      // ignore: deprecated_member_use
      _playlist = ConcatenatingAudioSource(children: initialSequence);
      await _bgAudioPlayer.setAudioSource(_playlist!);
      
      // Play immediately
      await _bgAudioPlayer.play();
    } catch (e) {
      AppLogger.error('Error starting audio session', name: 'ListenRepeat', error: e);
      _isAutoPlayActive = false;
      state = state.copyWith(isPlaying: false);
      rethrow; // Rethrow to let CarPlay handle the error
    }
  }

  Future<List<AudioSource>?> _generateNextWordSequence() async {
    if (!_isAutoPlayActive || state.shuffledPool.isEmpty) return null;

    final wordIndexToGenerate = _playlistWords.length;
    final item = state.shuffledPool[wordIndexToGenerate % state.shuffledPool.length];
    
    _playlistWords.add(item);

    try {
      final tts = ref.read(ttsServiceProvider);
      final dir = await getTemporaryDirectory();
      
      final safeId = item.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final ext = Platform.isAndroid ? 'wav' : 'caf';
      final ptFilePath = '${dir.path}/pt_$safeId.$ext';
      final enFilePath = '${dir.path}/en_$safeId.$ext';
      
      final ptFile = File(ptFilePath);
      final enFile = File(enFilePath);

      if (!ptFile.existsSync() || ptFile.lengthSync() == 0) {
        await tts.synthesizeToFile(item.portuguese, ptFilePath, language: 'pt-PT');
        int attempts = 0;
        while ((!ptFile.existsSync() || ptFile.lengthSync() == 0) && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }
      }
      
      if (!enFile.existsSync() || enFile.lengthSync() == 0) {
        await tts.synthesizeToFile(item.english, enFilePath, language: 'en-US');
        int attempts = 0;
        while ((!enFile.existsSync() || enFile.lengthSync() == 0) && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 50));
          attempts++;
        }
      }
      
      if (!ptFile.existsSync() || ptFile.lengthSync() == 0) {
         throw Exception("Failed to synthesize Portuguese audio to disk");
      }

      final artUri = await DynamicArtService.generateWordArt(item);
      final mediaItem = MediaItem(
        id: 'listen_repeat_${item.id}_$wordIndexToGenerate', // Make globally unique per playlist index
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

      return sequence;

    } catch (e) {
      AppLogger.error('Error in _generateNextWordSequence', name: 'ListenRepeat', error: e);
      _playlistWords.removeLast(); // Revert the addition
      return null;
    }
  }

  Future<void> _appendNextWordInBackground() async {
    final sequence = await _generateNextWordSequence();
    if (sequence != null && _playlist != null && _isAutoPlayActive) {
      await _playlist!.addAll(sequence);
    } else if (_isAutoPlayActive) {
      // Retry in background if failed
      await Future.delayed(const Duration(seconds: 2));
      _appendNextWordInBackground();
    }
  }

  void replayCurrentWord() {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ 4;
    _bgAudioPlayer.seek(Duration.zero, index: currentWordIndex * 4);
    _bgAudioPlayer.play();
  }

  void nextWord() async {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null || _playlist == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ 4;
    
    if (currentWordIndex + 1 >= _playlistWords.length) {
      // Wait for it to be generated if we hit next too fast
      final sequence = await _generateNextWordSequence();
      if (sequence != null) {
        await _playlist!.addAll(sequence);
      }
    }
    
    _bgAudioPlayer.seek(Duration.zero, index: (currentWordIndex + 1) * 4);
  }
  
  void previousWord() {
    if (!_isAutoPlayActive || _bgAudioPlayer.currentIndex == null) return;
    final currentWordIndex = _bgAudioPlayer.currentIndex! ~/ 4;
    if (currentWordIndex > 0) {
      _bgAudioPlayer.seek(Duration.zero, index: (currentWordIndex - 1) * 4);
    } else {
      replayCurrentWord();
    }
  }

  void togglePlayPause() {
    if (_bgAudioPlayer.playing) {
      pause();
    } else {
      if (_isAutoPlayActive) {
        _bgAudioPlayer.play();
      } else {
        startSession();
      }
    }
  }

  void pause() {
    _bgAudioPlayer.pause();
    state = state.copyWith(isPlaying: false);
  }

  void stopSession() {
    _isAutoPlayActive = false;
    _currentIndexSubscription?.cancel();
    _bgAudioPlayer.stop();
    state = ListenRepeatState();
  }

  void shufflePool() {
    if (state.pool.isEmpty) return;

    final shuffled = List<LanguageItem>.from(state.pool)..shuffle(_random);
    state = state.copyWith(shuffledPool: shuffled);

    startSession();
  }
}

final listenRepeatViewModelProvider =
    NotifierProvider<ListenRepeatViewModel, ListenRepeatState>(
      ListenRepeatViewModel.new,
    );


