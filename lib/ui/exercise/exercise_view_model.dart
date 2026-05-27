import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/question.dart';
import '../../models/progress_data.dart';
import '../../services/question_loader_service.dart';
import '../../services/progress_service.dart';
import '../../main.dart'; // for storageServiceProvider
import '../quiz/quiz_view_model.dart'; // Reuse QuizState

class ExerciseViewModel extends Notifier<QuizState> {
  final QuestionLoaderService _loader = QuestionLoaderService();
  DateTime? _sessionStartTime;

  @override
  QuizState build() {
    return QuizState(questions: []);
  }

  Future<void> startExercise(String jsonPath) async {
    _sessionStartTime = DateTime.now();
    final storage = ref.read(storageServiceProvider);
    final items = storage.getAllItems();

    // Load JSON questions from specific Unit file
    var questions = await _loader.loadQuestions(jsonPath, items);

    // Initial shuffle needed before filtering heuristic?
    // Actually the user wants randomization.
    questions.shuffle();

    final seenIds = storage.getSeenQuestionIds();
    final unseenQuestions = questions
        .where((q) => !seenIds.contains(q.id))
        .toList();

    List<Question> finalQuestions;

    if (unseenQuestions.isEmpty) {
      // If all questions are seen, we reset/reuse the full list
      // This allows the user to re-practice the unit immediately without reset
      finalQuestions = questions;
    } else {
      // Otherwise, only show what's left
      finalQuestions = unseenQuestions;
    }

    state = QuizState(questions: finalQuestions);
  }

  Future<int> answerQuestion(String answer) async {
    if (state.isFinished || state.currentQuestion == null) return 0;

    final isCorrect = answer == state.currentQuestion!.correctAnswer;
    final newScore = isCorrect ? state.score + 1 : state.score;
    final questionId = state.currentQuestion!.id;

    // Track first attempt
    final tracker = Map<String, bool>.from(state.firstAttemptTracker);
    final isFirstAttempt = !tracker.containsKey(questionId);
    if (isFirstAttempt) {
      tracker[questionId] = isCorrect;
    }

    // Mark as seen immediately
    final storage = ref.read(storageServiceProvider);
    storage.markQuestionAsSeen(questionId);

    // Record via progress service for XP + mastery
    final progressService = ref.read(progressServiceProvider.notifier);
    final xpAwarded = await progressService.recordQuizAnswer(
      storage: storage,
      itemId: state.currentQuestion!.sourceItem.id,
      correct: isCorrect,
      firstAttempt: isFirstAttempt && isCorrect,
    );

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
      // Exercise complete — record session
      final storage = ref.read(storageServiceProvider);
      final progressService = ref.read(progressServiceProvider.notifier);

      // Determine activity type
      ActivityType activityType = ActivityType.quiz; // fallback
      if (state.questions.isNotEmpty) {
        final firstType = state.questions.first.type;
        if (firstType == QuestionType.reorderAndConjugate || 
            firstType == QuestionType.jumble ||
            firstType == QuestionType.cloze) {
          activityType = ActivityType.sentenceBuilder;
        } else if (firstType == QuestionType.vocabularyMatch) {
          activityType = ActivityType.vocabularyQuiz;
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
    }
  }

  void reset() {
    state = QuizState(questions: []);
    _sessionStartTime = null;
  }


}

final exerciseViewModelProvider =
    NotifierProvider<ExerciseViewModel, QuizState>(ExerciseViewModel.new);
