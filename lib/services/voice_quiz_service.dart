import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/question.dart';
import '../models/language_item.dart';
import '../utils/logger.dart';

class VoiceQuizService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  String _lastRecognizedWords = '';
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();

  Stream<double> get soundLevelStream => _soundLevelController.stream;

  // Initialize TTS and STT
  Future<void> init() async {
    AppLogger.log("init() called", name: 'VoiceService');
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5); // Slower for clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      AppLogger.log("TTS initialized", name: 'VoiceService');
    } catch (e) {
      AppLogger.error("Error initializing TTS", name: 'VoiceService', error: e);
    }
  }

  double _currentRate = 0.5;

  Future<void> setSpeechRate(double rate) async {
    _currentRate = rate;
    await _tts.setSpeechRate(rate);
  }

  // Play the full question flow
  Future<void> playQuestion(Question q) async {
    // 1. Speak the English part (Context)
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(_currentRate);
    await speak("Translate this:");

    // REMOVED: await speak(q.sourceItem.english);
    // Reason: Spoilers if question is PT->EN, and redundancy if EN->PT.
    // We only read the questionText now.

    // If Question Text contains the prompt?
    // Let's play the question text.
    // Determine language:
    bool isPortuguese = (q.questionText == q.sourceItem.portuguese);

    await _tts.setLanguage(isPortuguese ? "pt-PT" : "en-US");
    await speak(q.questionText);

    // Let's skip complex parsing for now and just read options clearly.

    await speak("Is it?");

    // 3. Read Options
    for (int i = 0; i < q.options.length; i++) {
      final option = q.options[i];

      await _tts.setLanguage("pt-PT");
      await speak(option);

      if (i < q.options.length - 1) {
        await _tts.setLanguage("pt-PT"); // "ou" is Portuguese
        await speak("ou");
      }
    }
  }

  Future<void> speak(String text, {bool waitForCompletion = true}) async {
    if (text.isEmpty) return;
    AppLogger.log(
      "Speaking '$text' (wait: $waitForCompletion)...",
      name: 'VoiceService',
    );

    // Create completer only if we need to wait
    Completer<void>? completer;
    if (waitForCompletion) {
      completer = Completer();
      _tts.setCompletionHandler(() {
        AppLogger.log("Finished speaking '$text'", name: 'VoiceService');
        if (completer != null && !completer.isCompleted) completer.complete();
      });

      _tts.setErrorHandler((msg) {
        AppLogger.error("TTS Error: $msg", name: 'VoiceService');
        if (completer != null && !completer.isCompleted) completer.complete();
      });
    } else {
      // If not waiting, we assume fire-and-forget logic for handlers,
      // or we rely on the final "wait=true" call to set the handler that matters.
      // However, to be safe, we might clear handlers or leave them.
      // Leaving them is fine as long as we don't rely on them.
    }

    await _tts.speak(text);

    if (waitForCompletion && completer != null) {
      // Timeout to prevent hanging
      try {
        await completer.future.timeout(Duration(seconds: 10));
      } catch (e) {
        AppLogger.error(
          "Timeout waiting for speech completion '$text'",
          name: 'VoiceService',
          error: e,
        );
      }
    }
  }

  Future<String?> listenForAnswer(
    Duration duration, {
    String localeId = "pt-PT",
  }) async {
    Completer<String?> completer = Completer();

    // Helper to complete safely
    void complete(String? val) {
      if (!completer.isCompleted) completer.complete(val);
    }

    // Attempt to initialize (or re-initialize) to set listeners
    try {
      bool available = await _stt.initialize(
        onStatus: (status) {
          AppLogger.log("STT Status: $status", name: 'VoiceService');
          if (status == 'notListening' || status == 'done') {
            complete(
              _lastRecognizedWords.isNotEmpty ? _lastRecognizedWords : null,
            );
          }
        },
        onError: (val) {
          AppLogger.error("STT Error: $val", name: 'VoiceService');
          complete(null);
        },
      );

      if (!available) {
        AppLogger.log("STT not available", name: 'VoiceService');
        return null;
      }
    } catch (e) {
      AppLogger.error("Init warning", name: 'VoiceService', error: e);
      // If re-init fails, we rely on isAvailable check
      if (!_stt.isAvailable) return null;
    }

    _lastRecognizedWords = '';

    await _stt.listen(
      onResult: (result) {
        AppLogger.log(
          "STT Result: '${result.recognizedWords}' (final: ${result.finalResult})",
          name: 'VoiceService',
        );
        _lastRecognizedWords = result.recognizedWords;
        // If final result (due to pause timeout), complete
        if (result.finalResult) {
          complete(_lastRecognizedWords);
        }
      },
      localeId: localeId, // Dynamic locale
      listenFor: duration,
      pauseFor: const Duration(seconds: 3),
      onSoundLevelChange: (level) {
        _soundLevelController.add(level);
      },
    );

    // Timeout safety (max duration + buffer)
    return completer.future.timeout(
      duration + const Duration(seconds: 1),
      onTimeout: () async {
        await _stt.stop();
        return _lastRecognizedWords.isNotEmpty ? _lastRecognizedWords : null;
      },
    );
  }

  // Vocabulary Challenge
  Future<void> speakVocabularyChallenge(
    LanguageItem item, {
    bool isPortuguese = true,
  }) async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(_currentRate);

    if (isPortuguese) {
      // Ask: "What does [Portuguese Word] mean?"
      await speak("What does", waitForCompletion: false);

      await _tts.setLanguage("pt-PT");
      await _tts.setSpeechRate(_currentRate);
      await speak(item.portuguese, waitForCompletion: false);

      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(_currentRate);
      await speak(
        "mean?",
        waitForCompletion: true,
      ); // Wait only for the last one
    } else {
      // Ask: "How do you say [English Word] in Portuguese?"
      // Optimization: Merge EN string
      await speak(
        "How do you say ${item.english} in Portuguese?",
        waitForCompletion: true,
      );
    }
  }

  // Fuzzy match logic
  bool isCorrect(String spoken, String correctOption) {
    // Normalize
    final s = _normalize(spoken);
    final c = _normalize(correctOption);

    // 1. Direct match
    if (s == c) return true;

    // 2. Contains match (if one is a substring of the other)
    if (s.contains(c) || c.contains(s)) return true;

    // 3. Levenshtein Distance (for typos/accent misinterpretations)
    // Allow for ~30% difference
    final distance = _levenshtein(s, c);
    final maxLength = s.length > c.length ? s.length : c.length;
    if (maxLength == 0) return false;

    final similarity = 1.0 - (distance / maxLength);
    AppLogger.log(
      "Fuzzy Match: '$s' vs '$c' -> Sim: $similarity",
      name: 'VoiceService',
    );

    return similarity > 0.65; // Allow 35% error rate
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        int cost = (s.codeUnitAt(i) == t.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }

      for (int j = 0; j < v0.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }

  String _normalize(String input) {
    return input.toLowerCase().trim().replaceAll(RegExp(r'[^\w\s]'), '');
  }

  // Setup methods to stop/dispose
  void stop() {
    _tts.stop();
    _stt.stop();
  }

  // Feedback
  Future<void> speakFeedback(bool correct, {String locale = "en-US"}) async {
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(_currentRate); // Re-apply user rate
    if (locale == "pt-PT") {
      if (correct) {
        await speak("Correto!");
      } else {
        await speak("Incorreto.");
      }
    } else {
      if (correct) {
        await speak("Correct!");
      } else {
        await speak("Incorrect.");
      }
    }
  }
}
