import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/language_item.dart';
import '../services/tts_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class PhraseTrainerScreen extends ConsumerStatefulWidget {
  const PhraseTrainerScreen({super.key});

  @override
  ConsumerState<PhraseTrainerScreen> createState() =>
      _PhraseTrainerScreenState();
}

class _PhraseTrainerScreenState extends ConsumerState<PhraseTrainerScreen> {
  List<LanguageItem> _phrases = [];
  int _currentIndex = 0;
  bool _isAutoPlaying = false;
  double _speechRate = 0.8;

  final TtsService _ttsService = TtsService();

  @override
  void initState() {
    super.initState();
    _loadPhrases();
  }

  @override
  void dispose() {
    _isAutoPlaying = false;
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _loadPhrases() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/phrases.json',
      );
      final List<dynamic> data = json.decode(response);

      setState(() {
        _phrases = data
            .map(
              (item) => LanguageItem(
                id: '${item['portuguese']}_${item['english']}'.replaceAll(
                  ' ',
                  '_',
                ),
                portuguese: item['portuguese'],
                english: item['english'],
              ),
            )
            .toList();
        _phrases.shuffle();
        _currentIndex = 0;
      });
    } catch (e) {
      // Fallback to sample data if JSON loading fails
      setState(() {
        _phrases = [
          LanguageItem(
            id: 'phrase1',
            portuguese: 'Olá, como você está?',
            english: 'Hello, how are you?',
          ),
          LanguageItem(
            id: 'phrase2',
            portuguese: 'Obrigado por sua ajuda.',
            english: 'Thank you for your help.',
          ),
          LanguageItem(
            id: 'phrase3',
            portuguese: 'Eu não entendo.',
            english: "I don't understand.",
          ),
          LanguageItem(
            id: 'phrase4',
            portuguese: 'Posso ajudar?',
            english: 'Can I help?',
          ),
          LanguageItem(
            id: 'phrase5',
            portuguese: 'Qual é o seu nome?',
            english: 'What is your name?',
          ),
        ];
        _phrases.shuffle();
        _currentIndex = 0;
      });
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
    });

    if (_isAutoPlaying) {
      _runAutoPlayLoop();
    } else {
      _ttsService.stop();
    }
  }

  Future<void> _runAutoPlayLoop() async {
    while (_isAutoPlaying && mounted) {
      if (_currentIndex >= _phrases.length) {
        setState(() => _isAutoPlaying = false);
        break;
      }

      final phrase = _phrases[_currentIndex];

      // Speak Portuguese (1st time)
      await _ttsService.setRate(_speechRate);
      await _ttsService.speak(phrase.portuguese, language: 'pt-PT');

      // Wait 2 seconds
      if (!_isAutoPlaying || !mounted) break;
      await Future.delayed(const Duration(seconds: 2));

      // Speak Portuguese (2nd time)
      if (!_isAutoPlaying || !mounted) break;
      await _ttsService.speak(phrase.portuguese, language: 'pt-PT');

      // Wait 3 seconds
      if (!_isAutoPlaying || !mounted) break;
      await Future.delayed(const Duration(seconds: 3));

      // Speak English
      if (!_isAutoPlaying || !mounted) break;
      await _ttsService.speak(phrase.english, language: 'en-US');

      // Wait 3 seconds
      if (!_isAutoPlaying || !mounted) break;
      await Future.delayed(const Duration(seconds: 3));

      // Move to next
      if (!_isAutoPlaying || !mounted) break;
      if (_currentIndex < _phrases.length - 1) {
        setState(() => _currentIndex++);
      } else {
        // Stop if at end
        setState(() => _isAutoPlaying = false);
      }
    }
  }

  void _nextPhrase() {
    if (_currentIndex < _phrases.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _previousPhrase() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _cycleSpeed() {
    setState(() {
      if (_speechRate == 0.4) {
        _speechRate = 0.5;
      } else if (_speechRate == 0.5) {
        _speechRate = 0.6;
      } else if (_speechRate == 0.6) {
        _speechRate = 0.8;
      } else {
        _speechRate = 0.4;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Speed: ${_speechRate}x'),
        duration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrase Trainer'),
        actions: [
          TextButton(
            onPressed: _cycleSpeed,
            child: Text(
              '${_speechRate}x',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            if (_phrases.isNotEmpty && _currentIndex < _phrases.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _phrases[_currentIndex].portuguese,
                  style: Theme.of(context).textTheme.displayMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            if (_phrases.isNotEmpty && _currentIndex < _phrases.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _phrases[_currentIndex].english,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            FloatingActionButton.large(
              onPressed: _toggleAutoPlay,
              backgroundColor: _isAutoPlaying
                  ? Colors.amber
                  : Theme.of(context).colorScheme.primary,
              child: Icon(
                _isAutoPlaying ? Icons.pause : Icons.play_arrow,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: 140,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _currentIndex > 0 ? _previousPhrase : null,
                    icon: const Icon(Icons.arrow_left),
                    label: const Text('Previous'),
                  ),
                ),
                SizedBox(
                  width: 140,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _currentIndex < _phrases.length - 1
                        ? _nextPhrase
                        : null,
                    icon: const Icon(Icons.arrow_right),
                    label: const Text('Next'),
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
