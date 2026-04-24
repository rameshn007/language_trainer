import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/question.dart';
import '../../models/progress_data.dart';
import '../../services/quiz_engine_service.dart';
import '../../services/progress_service.dart';

import '../../services/question_loader_service.dart';
import '../../main.dart'; // for storageServiceProvider

class QuizState {
  final List<Question> questions;
  final int currentIndex;
  final int score;
  final bool isFinished;
  final int sessionXP;
  final int sessionBonusXP; // Completion + daily goal bonus
  final bool dailyGoalJustMet;
  final Map<String, bool> firstAttemptTracker; // questionId -> was first attempt correct
  final bool isCurrentQuestionCorrect;
  final bool hasAttemptedCurrent;
  final Set<String> currentWrongAnswers;

  QuizState({
    required this.questions,
    this.currentIndex = 0,
    this.score = 0,
    this.isFinished = false,
    this.sessionXP = 0,
    this.sessionBonusXP = 0,
    this.dailyGoalJustMet = false,
    this.firstAttemptTracker = const {},
    this.isCurrentQuestionCorrect = false,
    this.hasAttemptedCurrent = false,
    this.currentWrongAnswers = const {},
  });

  Question? get currentQuestion =>
      (questions.isNotEmpty && currentIndex < questions.length)
      ? questions[currentIndex]
      : null;

  int get totalXPEarned => sessionXP + sessionBonusXP;

  QuizState copyWith({
    List<Question>? questions,
    int? currentIndex,
    int? score,
    bool? isFinished,
    int? sessionXP,
    int? sessionBonusXP,
    bool? dailyGoalJustMet,
    Map<String, bool>? firstAttemptTracker,
    bool? isCurrentQuestionCorrect,
    bool? hasAttemptedCurrent,
    Set<String>? currentWrongAnswers,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      score: score ?? this.score,
      isFinished: isFinished ?? this.isFinished,
      sessionXP: sessionXP ?? this.sessionXP,
      sessionBonusXP: sessionBonusXP ?? this.sessionBonusXP,
      dailyGoalJustMet: dailyGoalJustMet ?? this.dailyGoalJustMet,
      firstAttemptTracker: firstAttemptTracker ?? this.firstAttemptTracker,
      isCurrentQuestionCorrect: isCurrentQuestionCorrect ?? this.isCurrentQuestionCorrect,
      hasAttemptedCurrent: hasAttemptedCurrent ?? this.hasAttemptedCurrent,
      currentWrongAnswers: currentWrongAnswers ?? this.currentWrongAnswers,
    );
  }
}

class QuizViewModel extends Notifier<QuizState> {
  final QuizEngineService _engine = QuizEngineService();
  final QuestionLoaderService _loader = QuestionLoaderService();
  DateTime? _sessionStartTime;

  @override
  QuizState build() {
    return QuizState(questions: []);
  }

  Future<void> startQuiz({int count = 20, String? category}) async {
    _sessionStartTime = DateTime.now();
    final storage = ref.read(storageServiceProvider);
    final items = storage.getAllItems();
    if (items.isEmpty) return;

    // Load JSON questions
    var jsonQuestions = await _loader.loadQuestions(
      'assets/data/questions.json',
      items,
    );

    // Filter by category if specified
    if (category != null) {
      jsonQuestions = jsonQuestions
          .where((q) => q.category == category)
          .toList();
    }

    final algoQuestions = (category == null)
        ? _engine.generateQuiz(items, count: count)
        : <Question>[];

    // Combine all potential questions
    final allPotentialQuestions = [...jsonQuestions, ...algoQuestions];

    // Filter by seen status
    final seenIds = storage.getSeenQuestionIds();
    final unseenQuestions = <Question>[];
    final seenQuestions = <Question>[];

    for (var q in allPotentialQuestions) {
      if (seenIds.contains(q.id)) {
        seenQuestions.add(q);
      } else {
        unseenQuestions.add(q);
      }
    }

    final List<Question> finalSelection = [];

    // 4. Fill result with prioritize unseen

    // Helper to select from a pool while avoiding duplicates by sourceItem or questionText
    void selectFromPool(List<Question> pool) {
      if (finalSelection.length >= count || pool.isEmpty) return;

      // Group variants to ensure we don't pick two variants of same concept in one quiz
      final Map<String, List<Question>> grouped = {};
      for (var q in pool) {
        final key = !q.sourceItem.isEmpty ? q.sourceItem.id : q.questionText;
        grouped.putIfAbsent(key, () => []).add(q);
      }

      final keys = grouped.keys.toList()..shuffle();

      for (var key in keys) {
        if (finalSelection.length >= count) return;

        // Skip if this concept is already in our final selection (e.g. from previous pool)
        bool alreadyPicked = finalSelection.any(
          (q) =>
              (!q.sourceItem.isEmpty && q.sourceItem.id == key) ||
              (q.questionText == key),
        );
        if (alreadyPicked) continue;

        final variants = grouped[key]!..shuffle();
        finalSelection.add(variants.first);
      }
    }

    // A. First try to fill with unseen concepts
    unseenQuestions.shuffle();
    selectFromPool(unseenQuestions);

    // B. If still under count, fill with seen concepts
    if (finalSelection.length < count) {
      seenQuestions.shuffle();
      selectFromPool(seenQuestions);
    }

    state = QuizState(questions: finalSelection);
  }

  Future<void> startVocabularyQuiz({int count = 20}) async {
    _sessionStartTime = DateTime.now();
    final storage = ref.read(storageServiceProvider);
    final items = storage.getAllItems();
    if (items.isEmpty) return;

    final seenIds = storage.getSeenQuestionIds();
    final vocabularyQuestions = _engine.generateVocabularyQuiz(
      items,
      count: count,
      seenIds: seenIds.toList(),
    );
    
    state = QuizState(questions: vocabularyQuestions);
  }

  Future<void> startInterrogativeQuiz({int count = 20, String? category}) async {
    _sessionStartTime = DateTime.now();
    final storage = ref.read(storageServiceProvider);
    final seenIds = storage.getSeenQuestionIds();
    final questions = await _engine.generateInterrogativeQuiz(
      count: count,
      category: category,
      seenIds: seenIds.toList(),
    );
    state = QuizState(questions: questions);
  }

  Future<void> startPrepositionQuiz({int count = 20, String? category}) async {
    _sessionStartTime = DateTime.now();
    final storage = ref.read(storageServiceProvider);
    final seenIds = storage.getSeenQuestionIds();
    final questions = await _engine.generatePrepositionQuiz(
      count: count,
      category: category,
      seenIds: seenIds.toList(),
    );
    state = QuizState(questions: questions);
  }

  /// Answers the current question and records XP via ProgressService.
  /// Returns the XP awarded for this answer.
  Future<int> answerQuestion(String answer) async {
    if (state.isFinished || state.currentQuestion == null) return 0;
    if (state.isCurrentQuestionCorrect) return 0; // Already correct

    final isCorrect = answer == state.currentQuestion!.correctAnswer;
    final questionId = state.currentQuestion!.id;

    int xpAwarded = 0;
    final tracker = Map<String, bool>.from(state.firstAttemptTracker);
    final isFirstAttempt = !state.hasAttemptedCurrent;

    if (isFirstAttempt) {
      tracker[questionId] = isCorrect;

      // Mark as seen immediately
      final storage = ref.read(storageServiceProvider);
      storage.markQuestionAsSeen(questionId);

      // Record via progress service for XP + mastery
      final progressService = ref.read(progressServiceProvider.notifier);
      xpAwarded = await progressService.recordQuizAnswer(
        storage: storage,
        itemId: state.currentQuestion!.sourceItem.id,
        correct: isCorrect,
        firstAttempt: isCorrect,
      );
    }

    final newScore = (isFirstAttempt && isCorrect) ? state.score + 1 : state.score;
    
    final newWrongAnswers = Set<String>.from(state.currentWrongAnswers);
    if (!isCorrect) {
      newWrongAnswers.add(answer);
    }

    state = state.copyWith(
      score: newScore,
      sessionXP: state.sessionXP + xpAwarded,
      firstAttemptTracker: tracker,
      isCurrentQuestionCorrect: isCorrect,
      hasAttemptedCurrent: true,
      currentWrongAnswers: newWrongAnswers,
    );

    return xpAwarded;
  }

  Future<void> nextQuestion() async {
    if (state.currentIndex < state.questions.length - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        isCurrentQuestionCorrect: false,
        hasAttemptedCurrent: false,
        currentWrongAnswers: {},
      );
    } else {
      // Quiz complete — record session
      final storage = ref.read(storageServiceProvider);
      final progressService = ref.read(progressServiceProvider.notifier);

      // Determine activity type
      ActivityType activityType = ActivityType.quiz;
      if (state.questions.isNotEmpty) {
        final firstType = state.questions.first.type;
        if (firstType == QuestionType.vocabularyMatch) {
          activityType = ActivityType.vocabularyQuiz;
        } else if (firstType == QuestionType.interrogativeMatch) {
          activityType = ActivityType.interrogativeQuiz;
        } else if (firstType == QuestionType.prepositionFill) {
          activityType = ActivityType.prepositionQuiz;
        }
      }

      final durationSec = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inSeconds
          : 0;

      // Check if daily goal was met before this session
      final wasGoalMet = storage.getTodayXP() >= storage.getDailyXPGoal();

      final bonusXP = await progressService.recordSessionComplete(
        storage: storage,
        activityType: activityType,
        score: state.score,
        total: state.questions.length,
        durationSeconds: durationSec,
        sessionXP: state.sessionXP,
      );

      final isGoalNowMet = storage.getTodayXP() >= storage.getDailyXPGoal();

      state = state.copyWith(
        isFinished: true,
        sessionBonusXP: bonusXP,
        dailyGoalJustMet: !wasGoalMet && isGoalNowMet,
      );

      // Also save legacy high score for backward compat
      storage.saveHighScore(state.score);
    }
  }
}

final quizViewModelProvider = NotifierProvider<QuizViewModel, QuizState>(
  QuizViewModel.new,
);
