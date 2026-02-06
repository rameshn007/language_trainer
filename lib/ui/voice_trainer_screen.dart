import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../models/language_item.dart';
import '../services/voice_quiz_service.dart';
import '../main.dart';
import 'dart:math';
import 'vocabulary/vocabulary_list_screen.dart';

class VoiceTrainerScreen extends ConsumerStatefulWidget {
  const VoiceTrainerScreen({super.key});

  @override
  ConsumerState<VoiceTrainerScreen> createState() => _VoiceTrainerScreenState();
}

class _VoiceTrainerScreenState extends ConsumerState<VoiceTrainerScreen> {
  final VoiceQuizService _voiceService = VoiceQuizService();

  List<LanguageItem> _sessionQueue = [];
  LanguageItem? _currentItem;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _statusText = "Ready to start";
  String _userSpokenText = "";

  double _speechRate = 0.5; // 0.5 is often "normal" on iOS
  double _soundLevel = 0.0;
  StreamSubscription<double>? _levelSubscription;

  bool _isPlaying = false;
  bool _isPortugueseQuestion =
      true; // true = "What does [PT] mean?", false = "How to say [EN]?"

  // Stats for this session
  int _correctCount = 0;
  int _totalAsked = 0;

  @override
  void initState() {
    super.initState();
    _initTrainer();
  }

  Future<void> _initTrainer() async {
    await _voiceService.init();
    await _voiceService.setSpeechRate(_speechRate);
    _buildSessionQueue();
    if (mounted) setState(() {});
  }

  void _cycleSpeed() {
    setState(() {
      if (_speechRate == 0.4) {
        _speechRate = 0.5;
      } else if (_speechRate == 0.5) {
        _speechRate = 0.6;
      } else {
        _speechRate = 0.4;
      }
    });
    _voiceService.setSpeechRate(_speechRate);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Speed: ${_speechRate}x"),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _openVocabularyList() async {
    // Pause if playing
    bool wasPlaying = _isPlaying;
    if (wasPlaying) {
      await _stopSession(); // Clean pause
    }

    if (!mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const VocabularyListScreen()));

    // On return
    if (mounted) {
      _buildSessionQueue(); // Refresh queue
      if (wasPlaying) {
        _startSession(); // Auto-resume
      }
    }
  }

  void _buildSessionQueue() {
    final storage = ref.read(storageServiceProvider);
    final allItems = storage.getAllItems();

    // Weighted sort:
    // 1. Never reviewed (lastReviewed == null)
    // 2. Oldest reviewed

    // Filter out items that are "Mastered" (level 5) if we want to focus on learning?
    // Or keep them for maintenance. Let's include all but strict sort.

    // Weighted sort with randomization:
    // 1. Never reviewed (Priority) -> Shuffle
    final neverReviewed = allItems
        .where((i) => i.lastReviewed == null)
        .toList();
    neverReviewed.shuffle();

    // 2. Reviewed -> Oldest first
    final reviewed = allItems.where((i) => i.lastReviewed != null).toList();
    reviewed.sort((a, b) => a.lastReviewed!.compareTo(b.lastReviewed!));

    // Combine
    _sessionQueue = [...neverReviewed, ...reviewed].take(20).toList();
    if (_sessionQueue.isNotEmpty) {
      _statusText = "Session ready (${_sessionQueue.length} words)";
    } else {
      _statusText = "No words found in vocabulary.";
    }

    // Filter out current item from queue to avoid immediate repeat if it was just added
    if (_currentItem != null) {
      _sessionQueue.removeWhere((item) => item.id == _currentItem!.id);
    }
  }

  @override
  void dispose() {
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_sessionQueue.isEmpty && _currentItem == null) return;

    if (_currentItem != null) {
      // RESUME
      setState(() {
        _isPlaying = true;
        _statusText = "Listen...";
      });
      await _playCurrentItem();
    } else {
      // START NEW
      setState(() {
        _isPlaying = true;
        _correctCount = 0;
        _totalAsked = 0;
      });
      await _nextItem();
    }
  }

  Future<void> _nextItem() async {
    if (!mounted) return;

    if (_sessionQueue.isEmpty) {
      setState(() {
        _statusText = "Session Complete!";
        _isPlaying = false;
        _currentItem = null;
      });
      await _voiceService.speak("Session complete. Great job!");
      return;
    }

    // Pop next item
    setState(() {
      _currentItem = _sessionQueue.removeAt(0);
      _statusText = "Listen...";
      _userSpokenText = "";
      // New Challenge Direction
      _isPortugueseQuestion = Random().nextBool();
    });

    await _playCurrentItem();
  }

  Future<void> _playCurrentItem() async {
    if (_currentItem == null) return;

    if (mounted) setState(() => _isSpeaking = true);
    await _voiceService.speakVocabularyChallenge(
      _currentItem!,
      isPortuguese: _isPortugueseQuestion,
    );
    if (mounted) setState(() => _isSpeaking = false);

    if (!mounted || !_isPlaying) return;

    // Auto-listen after question?
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || !_isPlaying) return;
    await _listen();
  }

  Future<void> _listen() async {
    if (!mounted) return;

    setState(() {
      _isListening = true;
      _statusText = "Listening...";
      _soundLevel = 0.0;
    });

    _levelSubscription?.cancel();
    _levelSubscription = _voiceService.soundLevelStream.listen((level) {
      // Level is usually -10 to 10 or similar logic depending on library.
      // normalize to 0.0 - 1.0 range if possible, or just raw.
      // Assuming positive magnitude for visualization.
      if (mounted) {
        setState(() {
          _soundLevel = level.clamp(0.0, 10.0) / 10.0;
        });
      }
    });

    final spoken = await _voiceService.listenForAnswer(
      const Duration(seconds: 15),
      localeId: _isPortugueseQuestion ? "en-US" : "pt-PT",
    );

    if (!mounted) return;

    _levelSubscription?.cancel();

    setState(() {
      _isListening = false;
      _userSpokenText = spoken ?? "(No speech detected)";
    });

    if (!_isPlaying) return;

    _processAnswer(spoken);
  }

  Future<void> _processAnswer(String? spoken) async {
    if (_currentItem == null || !_isPlaying) return;

    bool correct = false;
    if (spoken != null) {
      if (_isPortugueseQuestion) {
        // Asked: PT, Expected: EN check
        correct = _voiceService.isCorrect(spoken, _currentItem!.english);
      } else {
        // Asked: EN, Expected: PT check
        correct = _voiceService.isCorrect(spoken, _currentItem!.portuguese);
      }
    }

    final storage = ref.read(storageServiceProvider);

    if (!mounted) return;

    if (correct) {
      setState(() {
        _statusText = "Correct!";
        _correctCount++;
        _totalAsked++;
      });
      await _voiceService.speakFeedback(
        true,
        locale: _isPortugueseQuestion ? "en-US" : "pt-PT",
      );
      if (!mounted || !_isPlaying) return;

      // Reinforce
      if (_isPortugueseQuestion) {
        await _voiceService.speak("It means ${_currentItem!.english}");
      } else {
        // await _voiceService.setSpeechRate(0.85); // Slightly slower for PT
        await _voiceService.speak(
          "É ${_currentItem!.portuguese}",
        ); // "It is..."
        // await _voiceService.setSpeechRate(_speechRate); // Restore
      }

      // Update Stats
      await storage.updateMastery(_currentItem!.id, true);
    } else {
      setState(() {
        _statusText = "Incorrect. It was: ${_currentItem!.english}";
        _totalAsked++;
      });
      await _voiceService.speakFeedback(
        false,
        locale: _isPortugueseQuestion ? "en-US" : "pt-PT",
      );
      if (!mounted || !_isPlaying) return;

      if (_isPortugueseQuestion) {
        await _voiceService.speak("The answer is ${_currentItem!.english}");
      } else {
        // await _voiceService.setSpeechRate(0.85);
        await _voiceService.speak("A resposta é ${_currentItem!.portuguese}");
        // await _voiceService.setSpeechRate(_speechRate);
      }

      // Update Stats
      await storage.updateMastery(_currentItem!.id, false);

      // RETRY LOGIC: Add back to queue (random position or simple append?)
      // Append for now to retry at end of session (or sooner?)
      // Let's insert it 3 spots later or at end if < 3 items.
      if (_sessionQueue.length > 3) {
        _sessionQueue.insert(3, _currentItem!);
      } else {
        _sessionQueue.add(_currentItem!);
      }
    }

    if (!mounted) return;

    // Delay before next
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && _isPlaying) {
      await _nextItem();
    }
  }

  Future<void> _stopSession() async {
    _voiceService.stop();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _statusText = "Stopped";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Voice Trainer"),
        actions: [
          TextButton(
            onPressed: _cycleSpeed,
            child: Text(
              "${_speechRate}x",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _openVocabularyList,
            tooltip: "Vocabulary List",
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Stats / Progress
            if (_isPlaying)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: LinearProgressIndicator(
                  value: _totalAsked > 0 ? _correctCount / _totalAsked : 0,
                ),
              ),

            const Spacer(),

            // Current Word Display
            if (_currentItem != null) ...[
              Text(
                _isPortugueseQuestion
                    ? _currentItem!.portuguese
                    : _currentItem!.english,
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (_isSpeaking)
                const Text("Speaking...", style: TextStyle(color: Colors.blue))
              else
                Text(
                  _isPortugueseQuestion
                      ? "What does it mean?"
                      : "How do you say it in Portuguese?",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],

            const Spacer(),

            // Status & Feedback
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _statusText.startsWith("Correct") ? Colors.green : null,
              ),
              textAlign: TextAlign.center,
            ),
            if (_userSpokenText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  "You said: \"$_userSpokenText\"",
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),

            const Spacer(),

            // Controls
            AvatarGlow(
              animate: _isListening,
              glowColor: Colors.blue,
              duration: const Duration(milliseconds: 2000),
              repeat: true,
              child: FloatingActionButton.large(
                onPressed: _isPlaying
                    ? (_isListening ? null : _listen) // Tap to listen retry?
                    : _startSession,
                backgroundColor: _isListening
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                child: Transform.scale(
                  scale: 1.0 + (_soundLevel * 0.5), // Modulate size
                  child: Icon(
                    _isPlaying
                        ? (_isListening ? Icons.mic : Icons.mic_none)
                        : Icons.play_arrow,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_isPlaying)
              TextButton.icon(
                onPressed: _stopSession,
                icon: const Icon(Icons.stop),
                label: const Text("Stop Session"),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
