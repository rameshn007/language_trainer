import '../../models/language_item.dart';
import '../../services/storage_service.dart';
import '../../services/tts_service.dart';
import '../../services/quiz_engine_service.dart';
import 'carplay_drill_provider.dart';

class VocabularyFlashcardDrillProvider implements CarPlayDrillProvider {
  @override
  String get displayName => "Vocabulary Flashcards";

  @override
  String get description => "Listen to a word and repeat it.";

  late final StorageService _storage;
  late final TtsService _tts;

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
  }

  @override
  Future<DrillChallenge?> startSession() async {
    final allItems = _storage.getAllItems();
    if (allItems.isEmpty) {
      _isFinished = true;
      return null;
    }

    final shuffled = List<LanguageItem>.from(allItems)..shuffle();
    _sessionItems = shuffled.take(5).toList();

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
      promptText: item.portuguese,
      detailText: item.english,
      isVoiceOnly: false,
    );

    return _currentChallenge;
  }

  @override
  Future<bool> processAnswer(String answer) async {
    if (_currentChallenge == null) return false;

    final currentItem = _sessionItems[_currentIndex];
    final normalizedAnswer = answer.toLowerCase().trim();
    final normalizedTarget = currentItem.portuguese.toLowerCase().trim();

    bool isCorrect = normalizedAnswer == normalizedTarget || 
                     normalizedAnswer.contains(normalizedTarget) ||
                     normalizedTarget.contains(normalizedAnswer);

    if (isCorrect) {
      _score++;
      await _tts.speak("Correct");
    } else {
      await _tts.speak("Incorrect. It was $normalizedTarget");
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
