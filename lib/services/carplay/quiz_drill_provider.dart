import '../../models/question.dart';
import '../../services/storage_service.dart';
import '../../services/tts_service.dart';
import '../../services/quiz_engine_service.dart';
import '../../services/voice_quiz_service.dart';
import 'carplay_drill_provider.dart';

class QuizDrillProvider implements CarPlayDrillProvider {
  @override
  String get displayName => "Mixed Quiz";

  @override
  String get description => "Practice with mixed question types";

  late final StorageService _storage;
  late final TtsService _tts;
  late final QuizEngineService _quizEngine;
  late final VoiceQuizService _voiceService;

  bool _isFinished = true;
  int _score = 0;
  int _total = 0;
  List<Question> _questions = [];
  int _currentIndex = 0;
  Set<String> _seenQuestionIds = {};
  DrillChallenge? _currentChallenge;

  @override
  Future<void> init({
    required StorageService storageService,
    required TtsService ttsService,
    required QuizEngineService quizEngine,
  }) async {
    _storage = storageService;
    _tts = ttsService;
    _quizEngine = quizEngine;
    _voiceService = VoiceQuizService(ttsService);
  }

  @override
  Future<DrillChallenge?> startSession() async {
    final allItems = _storage.getAllItems();
    if (allItems.isEmpty) {
      _isFinished = true;
      return null;
    }

    // Generate mixed quiz: 50% vocab, 30% verb, 20% interrogative
    final vocabQuestions = _quizEngine.generateVocabularyQuiz(
      allItems,
      count: 5,
    );
    
    final interrogativeQuestions = await _quizEngine.generateInterrogativeQuiz(
      count: 3,
    );
    
    // Load verbs for conjugation questions
    final verbService = _getVerbService();
    final verbs = await verbService.loadVerbs();
    final verbQuestions = _quizEngine.generateVerbConjugationQuestions(
      verbs: verbs,
      count: 3,
    );

    // Combine all questions
    _questions = [...vocabQuestions, ...interrogativeQuestions, ...verbQuestions]..shuffle();

    // Limit to 10 questions max for CarPlay sessions
    if (_questions.length > 10) {
      _questions = _questions.take(10).toList();
    }

    _currentIndex = 0;
    _score = 0;
    _total = _questions.length;
    _isFinished = false;

    // Load seen question IDs for first attempt tracking
    _seenQuestionIds = _storage.getSeenQuestionIds();

    return nextChallenge();
  }

  dynamic _getVerbService() {
    // Access verb service from the quiz engine or create a minimal version
    // For now, we'll use a simple approach
    return null;
  }

  @override
  DrillChallenge? nextChallenge() {
    if (_currentIndex >= _questions.length) {
      _isFinished = true;
      return null;
    }

    final question = _questions[_currentIndex];
    _currentChallenge = DrillChallenge(
      promptText: question.questionText,
      detailText: question.correctAnswer,
      options: List<String>.from(question.options),
      isVoiceOnly: false,
    );

    return _currentChallenge;
  }

  @override
  Future<bool> processAnswer(String answer) async {
    if (_currentChallenge == null) return false;

    final question = _questions[_currentIndex];
    final normalizedAnswer = answer.toLowerCase().trim();
    final normalizedCorrect = question.correctAnswer.toLowerCase().trim();

    bool isCorrect = false;

    // Check if answer matches any option
    for (var option in question.options) {
      final normalizedOption = option.toLowerCase().trim();
      
      // Direct match
      if (normalizedAnswer == normalizedOption) {
        isCorrect = true;
        break;
      }
      
      // Fuzzy match using VoiceQuizService logic
      if (_voiceService.isCorrect(answer, option)) {
        isCorrect = true;
        break;
      }
    }

    // Also check if answer contains the correct answer or vice versa
    if (!isCorrect) {
      isCorrect = normalizedAnswer.contains(normalizedCorrect) || 
                  normalizedCorrect.contains(normalizedAnswer);
    }

    // Award XP and update mastery
    if (isCorrect) {
      _score++;
      
      // Use fuzzy matching to track if this is a first attempt
      final isFirstAttempt = !_seenQuestionIds.contains(question.id);
      
      final xp = await _storage.updateWordProgress(
        question.id,
        true,
        firstAttempt: isFirstAttempt,
      );
      
      if (xp > 0) {
        await _storage.addXP(xp);
        await _tts.speak(isFirstAttempt ? "Correct! +$xp XP" : "Correct! +$xp XP");
      } else {
        await _tts.speak("Correct!");
      }
    } else {
      await _storage.updateWordProgress(question.id, false);
      await _tts.speak("Incorrect. It was ${question.correctAnswer}");
    }

    // Mark question as seen
    _storage.markQuestionAsSeen(question.id);
    _seenQuestionIds.add(question.id);

    _currentIndex++;
    return isCorrect;
  }

  @override
  String? get completionSummary => 
      _isFinished ? "You got $_score out of $_total correct." : null;

  @override
  bool get isFinished => _isFinished;
}
