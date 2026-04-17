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

  List<Question> generateVocabularyQuiz(
    List<LanguageItem> items, {
    int count = 20,
    List<String>? seenIds,
  }) {
    if (items.isEmpty) return [];

    // 1. Partition into Words (1-2 tokens) and Phrases (3+ tokens)
    final List<LanguageItem> words = [];
    final List<LanguageItem> phrases = [];

    for (var item in items) {
      final tokenCount = item.portuguese.trim().split(RegExp(r'\s+')).length;
      if (tokenCount <= 2) {
        words.add(item);
      } else {
        phrases.add(item);
      }
    }

    // 2. Prioritize unseen items within each pool
    List<LanguageItem> getPrioritized(List<LanguageItem> pool, int limit) {
      if (pool.isEmpty) return [];
      
      final unseen = <LanguageItem>[];
      final seen = <LanguageItem>[];

      for (var item in pool) {
        // ID format for vocab quiz is 'vocab_${item.id}_pt_en'
        final qId = 'vocab_${item.id}_pt_en';
        if (seenIds != null && seenIds.contains(qId)) {
          seen.add(item);
        } else {
          unseen.add(item);
        }
      }

      unseen.shuffle(_random);
      seen.shuffle(_random);

      return [...unseen, ...seen].take(limit).toList();
    }

    // 3. Select balanced mix (aim for 50/50)
    final int targetWordsCount = (count / 2).floor();

    final selectedWords = getPrioritized(words, targetWordsCount);
    
    // If we didn't get enough words, take more phrases
    final int remainingCount = count - selectedWords.length;
    final selectedPhrases = getPrioritized(phrases, remainingCount);

    // Final recombination and final shuffle of the quiz order
    final selection = [...selectedWords, ...selectedPhrases]..shuffle(_random);

    final List<Question> questions = [];
    for (var item in selection) {
      questions.add(_createVocabularyMatch(item, items));
    }

    return questions;
  }

  Question _createVocabularyMatch(
    LanguageItem target,
    List<LanguageItem> pool,
  ) {
    String questionText = target.portuguese;
    String correctAnswer = target.english;

    // Generate distractors
    final List<String> options = [correctAnswer];
    final Set<String> used = {correctAnswer.toLowerCase().trim()};

    // Try to find distractors from the pool
    // Ensure at least 4 choices total
    int attempts = 0;
    while (options.length < 4 && attempts < 100) {
      final randomItem = pool[_random.nextInt(pool.length)];
      String distractor = randomItem.english;

      if (!used.contains(distractor.toLowerCase().trim()) && distractor.isNotEmpty) {
        options.add(distractor);
        used.add(distractor.toLowerCase().trim());
      }
      attempts++;
    }

    // Shuffle options
    options.shuffle(_random);

    final qId = 'vocab_${target.id}_pt_en';

    return Question(
      id: qId,
      questionText: questionText,
      options: options,
      correctAnswer: correctAnswer,
      type: QuestionType.vocabularyMatch,
      sourceItem: target,
    );
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
