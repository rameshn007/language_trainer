import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/question.dart';
import '../models/language_item.dart';
import '../utils/logger.dart';
import 'tts_service.dart';

class VoiceQuizService {
  final TtsService _ttsService;
  final SpeechToText _stt = SpeechToText();

  VoiceQuizService(this._ttsService);

  String _lastRecognizedWords = '';
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();

  Stream<double> get soundLevelStream => _soundLevelController.stream;

  Future<void> init() async {
    AppLogger.log("init() called", name: 'VoiceService');
    // TtsService is assumed to be already initialized by the main app,
    // but we can ensure rate/volume if we wanted. Relying on TtsService defaults.
    AppLogger.log("TTS ready via TtsService", name: 'VoiceService');
  }

  double _currentRate = 0.5;

  Future<void> setSpeechRate(double rate) async {
    _currentRate = rate;
    await _ttsService.setRate(rate);
  }

  // Play the full question flow
  Future<void> playQuestion(Question q) async {
    // 1. Speak the English part (Context)
    await _ttsService.setRate(_currentRate);
    await speak("Translate this:", language: "en-US");

    // REMOVED: await speak(q.sourceItem.english);
    // Reason: Spoilers if question is PT->EN, and redundancy if EN->PT.
    // We only read the questionText now.

    // If Question Text contains the prompt?
    // Let's play the question text.
    // Determine language:
    bool isPortuguese = (q.questionText == q.sourceItem.portuguese);

    await speak(q.questionText, language: isPortuguese ? "pt-PT" : "en-US");

    // Let's skip complex parsing for now and just read options clearly.

    await speak("Is it?", language: "en-US");

    // 3. Read Options
    for (int i = 0; i < q.options.length; i++) {
      final option = q.options[i];

      await speak(option, language: "pt-PT");

      if (i < q.options.length - 1) {
        await speak("ou", language: "pt-PT");
      }
    }
  }

  Future<void> speak(
    String text, {
    bool waitForCompletion = true,
    String? language,
  }) async {
    if (text.isEmpty) return;
    AppLogger.log(
      "Speaking '$text' (wait: $waitForCompletion)...",
      name: 'VoiceService',
    );

    // TtsService.speak inherently awaits speech completion due to flutter_tts behavior on iOS/Android
    // if awaitSpeakCompletion is true. We'll simply await it.
    await _ttsService.speak(text, language: language);

    // Extra buffer if wait is explicitly requested to ensure clear pauses
    if (waitForCompletion) {
      await Future.delayed(const Duration(milliseconds: 300));
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
    await _ttsService.setRate(_currentRate);

    if (isPortuguese) {
      // Ask: "What does [Portuguese Word] mean?"
      await speak("What does", waitForCompletion: false, language: "en-US");

      await _ttsService.setRate(_currentRate);
      await speak(item.portuguese, waitForCompletion: false, language: "pt-PT");

      await _ttsService.setRate(_currentRate);
      await speak(
        "mean?",
        waitForCompletion: true,
        language: "en-US",
      ); // Wait only for the last one
    } else {
      // Ask: "How do you say [English Word] in Portuguese?"
      // Optimization: Merge EN string
      await speak(
        "How do you say ${item.english} in Portuguese?",
        waitForCompletion: true,
        language: "en-US",
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
    _ttsService.stop();
    _stt.stop();
  }

  // Feedback
  Future<void> speakFeedback(bool correct, {String locale = "en-US"}) async {
    await _ttsService.setRate(_currentRate); // Re-apply user rate
    if (locale == "pt-PT") {
      if (correct) {
        await speak("Correto!", language: locale);
      } else {
        await speak("Incorreto.", language: locale);
      }
    } else {
      if (correct) {
        await speak("Correct!", language: locale);
      } else {
        await speak("Incorrect.", language: locale);
      }
    }
  }
}
