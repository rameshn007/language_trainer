import 'dart:math';
import '../models/language_item.dart';
import '../models/question.dart';

class QuizEngineService {
  final Random _random = Random();

  List<Question> generateQuiz(List<LanguageItem> items, {int count = 20}) {
    if (items.isEmpty) return [];

    final List<Question> questions = [];
    // Shuffle items to get random selection
    final List<LanguageItem> shuffled = List.from(items)..shuffle(_random);
    final selection = shuffled.take(count).toList();

    for (var item in selection) {
      // For now, randomly choose direction: PT->EN or EN->PT
      bool ptToEn = _random.nextBool();
      questions.add(_createMultipleChoice(item, items, ptToEn));
    }

    return questions;
  }

  Question _createMultipleChoice(
    LanguageItem target,
    List<LanguageItem> pool,
    bool ptToEn,
  ) {
    String questionText = ptToEn ? target.portuguese : target.english;
    String correctAnswer = ptToEn ? target.english : target.portuguese;

    // Generate distractors
    final List<String> options = [correctAnswer];
    final Set<String> used = {correctAnswer};

    // Try to find distractors from the pool
    // In a real app, we'd filter by category or similarity
    int attempts = 0;
    while (options.length < 4 && attempts < 50) {
      final randomItem = pool[_random.nextInt(pool.length)];
      String distractor = ptToEn ? randomItem.english : randomItem.portuguese;

      if (!used.contains(distractor) && distractor.isNotEmpty) {
        options.add(distractor);
        used.add(distractor);
      }
      attempts++;
    }

    // Shuffle options
    options.shuffle(_random);

    // Deterministic ID so we can track if this specific question variant was seen
    final variantSuffix = ptToEn ? 'pt_en' : 'en_pt';
    final qId = '${target.id}_$variantSuffix';

    return Question(
      id: qId,
      questionText: questionText,
      options: options,
      correctAnswer: correctAnswer,
      type: QuestionType.multipleChoice,
      sourceItem: target,
    );
  }
}
