import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/question.dart';
import '../../models/language_item.dart';
import '../../services/quiz_engine_service.dart';

import '../../services/question_loader_service.dart';
import '../../main.dart'; // for storageServiceProvider

class QuizState {
  final List<Question> questions;
  final int currentIndex;
  final int score;
  final bool isFinished;

  QuizState({
    required this.questions,
    this.currentIndex = 0,
    this.score = 0,
    this.isFinished = false,
  });

  Question? get currentQuestion =>
      (questions.isNotEmpty && currentIndex < questions.length)
      ? questions[currentIndex]
      : null;

  QuizState copyWith({
    List<Question>? questions,
    int? currentIndex,
    int? score,
    bool? isFinished,
  }) {
    return QuizState(
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      score: score ?? this.score,
      isFinished: isFinished ?? this.isFinished,
    );
  }
}

class QuizViewModel extends Notifier<QuizState> {
  final QuizEngineService _engine = QuizEngineService();
  final QuestionLoaderService _loader = QuestionLoaderService();

  @override
  QuizState build() {
    return QuizState(questions: []);
  }

  Future<void> startQuiz({int count = 20, String? category}) async {
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

    // Group questions by their sourceItem ID (or text if ID missing)
    // We want to prioritize UNSEEN questions first.

    // Helper to select from a pool
    void selectFromPool(List<Question> pool, int remainingCount) {
      if (remainingCount <= 0 || pool.isEmpty) return;

      final Map<String, List<Question>> grouped = {};
      for (var q in pool) {
        final key = !q.sourceItem.isEmpty ? q.sourceItem.id : q.questionText;
        grouped.putIfAbsent(key, () => []).add(q);
      }

      final keys = grouped.keys.toList()..shuffle();

      // 1. Pick one per concept
      for (var key in keys) {
        if (finalSelection.length >= count) return;
        final variants = grouped[key]!..shuffle();

        // Helper: check if we already picked a question for this concept in this session
        // (to avoid duplicates from mixed pools)
        bool alreadyPicked = finalSelection.any(
          (q) =>
              (!q.sourceItem.isEmpty && q.sourceItem.id == key) ||
              (q.questionText ==
                  variants.first.questionText), // heuristic fallback
        );

        if (!alreadyPicked) {
          finalSelection.add(variants.first);
        }
      }

      // 2. If still need more, pick seconds
      if (finalSelection.length < count) {
        // Simply use the shuffle method below to pick from remainder if needed
        // The complex logic isn't strictly necessary for the fallback
      }
    }

    // A. Fill with unseen
    selectFromPool(unseenQuestions, count);

    // B. Fill remainder with seen if needed
    if (finalSelection.length < count) {
      // Only candidates that strictly haven't been picked yet (by ID)
      // But selectFromPool logic above creates a new selection list.
      // We need a more robust way to combine.

      // SIMPLIFIED APPROACH:
      // 1. Shuffle both lists
      unseenQuestions.shuffle();
      seenQuestions.shuffle();

      // 2. Take all unseen
      finalSelection.addAll(unseenQuestions);

      // 3. Take seen until count reached
      for (var q in seenQuestions) {
        if (finalSelection.length >= count) break;
        finalSelection.add(q);
      }
    }

    // Cap at count (in case unseen was > count)
    var resultQuestions = finalSelection.take(count).toList();

    // Final shuffle
    resultQuestions.shuffle();

    state = QuizState(questions: resultQuestions);
  }

  void answerQuestion(String answer) {
    if (state.isFinished || state.currentQuestion == null) return;

    final isCorrect = answer == state.currentQuestion!.correctAnswer;

    final newScore = isCorrect ? state.score + 1 : state.score;

    // Mark as seen immediately
    final storage = ref.read(storageServiceProvider);
    storage.markQuestionAsSeen(state.currentQuestion!.id);

    if (isCorrect) {
      _updateMastery(state.currentQuestion!.sourceItem, true);
    } else {
      _updateMastery(state.currentQuestion!.sourceItem, false);
    }

    state = state.copyWith(score: newScore);
  }

  void nextQuestion() {
    final storage = ref.read(storageServiceProvider);
    if (state.currentIndex < state.questions.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    } else {
      state = state.copyWith(isFinished: true);
      storage.saveHighScore(state.score);
    }
  }

  void _updateMastery(LanguageItem item, bool correct) {
    final storage = ref.read(storageServiceProvider);
    if (correct) {
      item.masteryLevel = (item.masteryLevel + 1).clamp(0, 5);
      item.lastReviewed = DateTime.now();
    } else {
      item.masteryLevel = (item.masteryLevel - 1).clamp(0, 5);
    }
    storage.updateItem(item);
  }
}

final quizViewModelProvider = NotifierProvider<QuizViewModel, QuizState>(
  QuizViewModel.new,
);
