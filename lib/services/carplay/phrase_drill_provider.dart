import '../../models/language_item.dart';
import '../../services/storage_service.dart';
import '../../services/tts_service.dart';
import '../../services/quiz_engine_service.dart';
import '../../services/voice_quiz_service.dart';
import 'carplay_drill_provider.dart';

class PhraseTrainerDrillProvider implements CarPlayDrillProvider {
  @override
  String get displayName => "Phrase Trainer";

  @override
  String get description => "Practice Portuguese phrases";

  late final StorageService _storage;
  late final TtsService _tts;
  late final VoiceQuizService _voiceService;

  bool _isFinished = true;
  int _score = 0;
  int _total = 0;
  List<LanguageItem> _sessionItems = [];
  int _currentIndex = 0;
  DrillChallenge? _currentChallenge;

  @override
  Future<void> init({
    required StorageService storageService,
    required TtsService ttsService,
    required QuizEngineService quizEngine,
  }) async {
    _storage = storageService;
    _tts = ttsService;
    _voiceService = VoiceQuizService(ttsService);
  }

  @override
  Future<DrillChallenge?> startSession() async {
    final allItems = _storage.getAllItems();
    if (allItems.isEmpty) {
      _isFinished = true;
      return null;
    }

    // Filter for phrases (3+ tokens)
    final phrases = allItems.where((item) {
      final tokenCount = item.portuguese.trim().split(RegExp(r'\s+')).length;
      return tokenCount >= 3;
    }).toList();

    if (phrases.isEmpty) {
      // Fallback to all items if no phrases found
      _sessionItems = List<LanguageItem>.from(allItems)..shuffle();
      _sessionItems = _sessionItems.take(10).toList();
    } else {
      _sessionItems = List<LanguageItem>.from(phrases)..shuffle();
      _sessionItems = _sessionItems.take(10).toList();
    }

    _currentIndex = 0;
    _score = 0;
    _total = _sessionItems.length;
    _isFinished = false;

    return nextChallenge();
  }

  @override
  DrillChallenge? nextChallenge() {
    if (_currentIndex >= _sessionItems.length) {
      _isFinished = true;
      return null;
    }

    final item = _sessionItems[_currentIndex];
    _currentChallenge = DrillChallenge(
      promptText: "What does '${item.portuguese}' mean in English?",
      detailText: item.portuguese,
      options: [item.english],
      isVoiceOnly: false,
    );

    return _currentChallenge;
  }

  @override
  Future<bool> processAnswer(String answer) async {
    if (_currentChallenge == null) return false;

    final currentItem = _sessionItems[_currentIndex];
    final normalizedAnswer = answer.toLowerCase().trim();
    final normalizedTarget = currentItem.english.toLowerCase().trim();

    bool isCorrect = false;

    // Direct match
    if (normalizedAnswer == normalizedTarget) {
      isCorrect = true;
    }
    // Fuzzy match using VoiceQuizService logic
    else if (_voiceService.isCorrect(answer, currentItem.english)) {
      isCorrect = true;
    }
    // Contains match
    else if (normalizedAnswer.contains(normalizedTarget) || 
             normalizedTarget.contains(normalizedAnswer)) {
      isCorrect = true;
    }

    // Award XP and update mastery
    if (isCorrect) {
      _score++;
      
      final xp = await _storage.updateWordProgress(
        currentItem.id,
        true,
        firstAttempt: true, // Phrases are always new in this context
      );
      
      if (xp > 0) {
        await _storage.addXP(xp);
        await _tts.speak("Correct! +$xp XP");
      } else {
        await _tts.speak("Correct!");
      }
    } else {
      await _storage.updateWordProgress(currentItem.id, false);
      await _tts.speak("Incorrect. It was '${currentItem.english}'");
    }

    _currentIndex++;
    return isCorrect;
  }

  @override
  String? get completionSummary => 
      _isFinished ? "You got $_score out of $_total correct." : null;

  @override
  bool get isFinished => _isFinished;
}
