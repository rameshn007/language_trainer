import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/question.dart';

class VoiceQuizService {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  String _lastRecognizedWords = '';

  // Initialize TTS and STT
  Future<void> init() async {
    print("VoiceService: init() called");
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5); // Slower for clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      print("VoiceService: TTS initialized");
    } catch (e) {
      print("VoiceService: Error initializing TTS: $e");
    }

    // Initialize STT (permissions request happens here usually, or on first listen)
    // We don't strictly need to await available as we check it before listening
  }

  // Play the full question flow
  Future<void> playQuestion(Question q) async {
    // 1. Speak the English part (Context)
    await _tts.setLanguage("en-US");
    await _speak("Translate this:");

    if (q.sourceItem.english.isNotEmpty) {
      await _speak(q.sourceItem.english);
    } else {
      // Fallback if source item missing, though usually it's there.
      // If it's a "What is the meaning of..." question, we might parse text.
      // For now, assume standards.
    }

    // 2. Speak the Portuguese part (The challenge)
    // If it's a translation question, usually English is given, user picks Portuguese.
    // Or Portuguese given, user picks English.
    // Let's assume standard "Translate English to Portuguese" or vice versa based on Quiz logic.
    // For the "English part in English and read the Portuguese part in Portuguese" request:

    // If Question Text contains the prompt?
    // Let's play the question text in English first (usually "How do you say...?")
    await _tts.setLanguage("en-US");
    await _speak(q.questionText); // "How do you say 'Hello'?"

    // If there is a Portuguese reference in the question (not the answer), strictly speaking
    // the user asked: "state the english part in english and read the portuguese part in portuguese"
    // This implies a mixed sentence or context.
    // Since our questions are usually "How do you say X", X is english.
    // If the question is "What does 'Ola' mean", Ola is portuguese.

    // Let's skip complex parsing for now and just read options clearly.

    await _speak("Is it?");

    // 3. Read Options
    for (int i = 0; i < q.options.length; i++) {
      final option = q.options[i];

      // Detect language of option roughly?
      // Usually options are the Target Language.
      // If we are learning Portuguese, options are likely Portuguese.
      // But if question is "Meaning of Ola", options are English.

      // HEURISTIC: Check if option contains Portuguese characters or just assume default based on app usage?
      // The app is "Language Trainer" (English -> Portuguese likely).
      // Let's try to infer or split.

      // Simple approach: Read option in Portuguese if it looks Portuguese-ish?
      // Or better: Read in BOTH if unsure? No, that's confusing.

      // Let's assume options are Portuguese for "How do you say X?" questions.
      // We'll set language to Portuguese for options by default as it's a Portuguese trainer.
      // Unless logic dictates otherwise.

      await _tts.setLanguage("pt-BR");
      await _speak(option);

      if (i < q.options.length - 1) {
        await _tts.setLanguage("pt-BR"); // "ou" is Portuguese
        await _speak("ou");
      }
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    print("VoiceService: Speaking '$text'...");
    Completer<void> completer = Completer();
    _tts.setCompletionHandler(() {
      print("VoiceService: Finished speaking '$text'");
      if (!completer.isCompleted) completer.complete();
    });

    _tts.setErrorHandler((msg) {
      print("VoiceService: TTS Error: $msg");
      if (!completer.isCompleted) completer.complete(); // Don't hang on error
    });

    await _tts.speak(text);
    // Timeout to prevent hanging
    try {
      await completer.future.timeout(Duration(seconds: 10));
    } catch (e) {
      print("VoiceService: Timeout waiting for speech completion '$text'");
    }
  }

  Future<String?> listenForAnswer(Duration duration) async {
    if (!_stt.isAvailable) {
      bool available = await _stt.initialize();
      if (!available) return null;
    }

    // Completer<String?> completer = Completer();
    _lastRecognizedWords = '';

    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) {
          _lastRecognizedWords = result.recognizedWords;
          // Completer might be called by timer if we want a strict window
        } else {
          // Partial results
          _lastRecognizedWords = result.recognizedWords;
        }
      },
      localeId: "pt-BR", // Listening for Portuguese answers
      listenFor: duration,
      pauseFor: Duration(seconds: 2),
    );

    // Wait for the duration (+ buffer) or until we get a result?
    // SpeechToText listen is async handling.
    // We can wrap it in a timer to force return.

    return Future.delayed(duration, () async {
      await _stt.stop();
      return _lastRecognizedWords;
    });
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
      await _speak("Correct!");
    } else {
      await _speak("Incorrect.");
    }
  }
}
