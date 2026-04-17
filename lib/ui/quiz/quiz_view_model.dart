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
    final storage = ref.read(storageServiceProvider);
    final seenIds = storage.getSeenQuestionIds();
    final questions = await _engine.generateInterrogativeQuiz(
      count: count,
      category: category,
      seenIds: seenIds.toList(),
    );
    state = QuizState(questions: questions);
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
