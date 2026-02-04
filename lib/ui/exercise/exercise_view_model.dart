import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/language_item.dart';
import '../../services/question_loader_service.dart';
import '../../main.dart'; // for storageServiceProvider
import '../quiz/quiz_view_model.dart'; // Reuse QuizState

class ExerciseViewModel extends Notifier<QuizState> {
  final QuestionLoaderService _loader = QuestionLoaderService();

  @override
  QuizState build() {
    return QuizState(questions: []);
  }

  Future<void> startExercise(String jsonPath) async {
    final storage = ref.read(storageServiceProvider);
    final items = storage.getAllItems();

    // Load JSON questions from specific Unit file
    var questions = await _loader.loadQuestions(jsonPath, items);

    // Randomize the order of questions
    questions.shuffle();

    // No shuffling or algo generation - preserve Unit order
    state = QuizState(questions: questions);
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
    if (state.currentIndex < state.questions.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    } else {
      state = state.copyWith(isFinished: true);
      // We don't save High Score for exercises, or maybe we should track Unit completion?
      // For now, just finish.
    }
  }

  void _updateMastery(LanguageItem item, bool correct) {
    // Only update if it's a real item (not a dummy one without valid ID)
    // But our JSONs have unique IDs, so we can track them.
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

final exerciseViewModelProvider =
    NotifierProvider<ExerciseViewModel, QuizState>(ExerciseViewModel.new);
