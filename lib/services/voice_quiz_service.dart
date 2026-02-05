import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/question.dart';
import '../utils/logger.dart';

class VoiceQuizService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  String _lastRecognizedWords = '';

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

    // Initialize STT (permissions request happens here usually, or on first listen)
    // We don't strictly need to await available as we check it before listening
  }

  // Play the full question flow
  Future<void> playQuestion(Question q) async {
    // 1. Speak the English part (Context)
    await _tts.setLanguage("en-US");
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

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    AppLogger.log("Speaking '$text'...", name: 'VoiceService');
    Completer<void> completer = Completer();
    _tts.setCompletionHandler(() {
      AppLogger.log("Finished speaking '$text'", name: 'VoiceService');
      if (!completer.isCompleted) completer.complete();
    });

    _tts.setErrorHandler((msg) {
      AppLogger.error("TTS Error: $msg", name: 'VoiceService');
      if (!completer.isCompleted) completer.complete(); // Don't hang on error
    });

    await _tts.speak(text);
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

  Future<String?> listenForAnswer(Duration duration) async {
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
        _lastRecognizedWords = result.recognizedWords;
        // If final result (due to pause timeout), complete
        if (result.finalResult) {
          complete(_lastRecognizedWords);
        }
      },
      localeId: "pt-PT", // Listening for Portuguese answers
      listenFor: duration,
      pauseFor: const Duration(seconds: 3),
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

  // Fuzzy match logic
  bool isCorrect(String spoken, String correctOption) {
    // Normalize
    final s = spoken.toLowerCase().trim();
    final c = correctOption.toLowerCase().trim();

    // Direct match
    if (s == c) return true;

    // Similarity (Levenshtein or just 'contains')
    if (s.contains(c) || c.contains(s)) return true;

    return false;
  }

  // Setup methods to stop/dispose
  void stop() {
    _tts.stop();
    _stt.stop();
  }

  // Feedback
  Future<void> speakFeedback(bool correct) async {
    await _tts.setLanguage("en-US");
    if (correct) {
      await speak("Correct!");
    } else {
      await speak("Incorrect.");
    }
  }
}
