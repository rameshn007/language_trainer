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

    // Group questions by their sourceItem ID (or text if ID missing)
    // to ensure we don't ask multiple questions about the same word in one session.
    final Map<String, List<Question>> groupedBySource = {};
    for (var q in allPotentialQuestions) {
      // Use sourceItem.id if valid, otherwise fallback to portuguese text or question text
      // We want to group by the underlying CONCEPT/WORD.
      final key = !q.sourceItem.isEmpty
          ? q.sourceItem.id
          : q.questionText; // Fallback, though ideally sourceItem is always present

      groupedBySource.putIfAbsent(key, () => []).add(q);
    }

    final List<Question> finalSelection = [];
    final List<String> sourceKeys = groupedBySource.keys.toList();

    // Shuffle the keys (concepts) so we pick random words
    sourceKeys.shuffle();

    // 1. First pass: Pick ONE random question for each concept
    for (var key in sourceKeys) {
      if (finalSelection.length >= count) break;

      final questionsForConcept = groupedBySource[key]!;
      // Pick a random question variant for this concept (e.g. PT->EN vs EN->PT vs Cloze)
      questionsForConcept.shuffle();
      finalSelection.add(questionsForConcept.first);
    }

    // 2. Second pass: If we still need more questions (rare, if count > available concepts),
    // go through again and pick a SECOND variant if available.
    if (finalSelection.length < count) {
      for (var key in sourceKeys) {
        if (finalSelection.length >= count) break;

        final questionsForConcept = groupedBySource[key]!;
        if (questionsForConcept.length > 1) {
          finalSelection.add(questionsForConcept[1]);
        }
      }
    }

    // Final shuffle of the selected questions so they aren't ordered by concept grouping process
    finalSelection.shuffle();

    state = QuizState(questions: finalSelection);
  }

  void answerQuestion(String answer) {
    if (state.isFinished || state.currentQuestion == null) return;

    final isCorrect = answer == state.currentQuestion!.correctAnswer;

    final newScore = isCorrect ? state.score + 1 : state.score;

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
