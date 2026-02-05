import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../models/language_item.dart';
import '../services/voice_quiz_service.dart';
import '../main.dart';

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
  bool _isPlaying = false;

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
    _buildSessionQueue();
    if (mounted) setState(() {});
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
  }

  @override
  void dispose() {
    _voiceService.stop();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_sessionQueue.isEmpty) return;

    setState(() {
      _isPlaying = true;
      _correctCount = 0;
      _totalAsked = 0;
    });

    await _nextItem();
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
    });

    if (_currentItem == null) return;

    // Challenge Flow
    if (mounted) setState(() => _isSpeaking = true);
    await _voiceService.speakVocabularyChallenge(_currentItem!);
    if (mounted) setState(() => _isSpeaking = false);

    if (!mounted) return;

    // Auto-listen after question?

    // Auto-listen after question?
    // Let's allow user to tap mic, OR auto-listen.
    // For hands-free, auto-listen is better.
    await _listen();
  }

  Future<void> _listen() async {
    if (!mounted) return;

    setState(() {
      _isListening = true;
      _statusText = "Listening...";
    });

    final spoken = await _voiceService.listenForAnswer(
      const Duration(seconds: 15),
    );

    if (!mounted) return;

    setState(() {
      _isListening = false;
      _userSpokenText = spoken ?? "(No speech detected)";
    });

    _processAnswer(spoken);
  }

  Future<void> _processAnswer(String? spoken) async {
    if (_currentItem == null) return;

    bool correct = false;
    if (spoken != null) {
      correct = _voiceService.isCorrect(spoken, _currentItem!.english);
    }

    final storage = ref.read(storageServiceProvider);

    if (!mounted) return;

    if (correct) {
      setState(() {
        _statusText = "Correct!";
        _correctCount++;
        _totalAsked++;
      });
      await _voiceService.speakFeedback(true);
      if (!mounted) return;
      await _voiceService.speak(
        "It means ${_currentItem!.english}",
      ); // Reinforce

      // Update Stats
      await storage.updateMastery(_currentItem!.id, true);
    } else {
      setState(() {
        _statusText = "Incorrect. It was: ${_currentItem!.english}";
        _totalAsked++;
      });
      await _voiceService.speakFeedback(false);
      if (!mounted) return;
      await _voiceService.speak("The answer is ${_currentItem!.english}");

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
      appBar: AppBar(title: const Text("Voice Trainer")),
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
                _currentItem!.portuguese,
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (_isSpeaking)
                const Text("Speaking...", style: TextStyle(color: Colors.blue))
              else
                const Text("What does it mean?"),
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
                child: Icon(
                  _isPlaying
                      ? (_isListening ? Icons.mic : Icons.mic_none)
                      : Icons.play_arrow,
                  size: 40,
                  color: Colors.white,
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
