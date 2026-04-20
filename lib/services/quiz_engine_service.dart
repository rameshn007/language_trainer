import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/language_item.dart';
import '../models/question.dart';

class QuizEngineService {
  final Random _random = Random();

  /// Generates an adaptive quiz based on user mastery levels
  List<Question> generateAdaptiveQuiz(
    List<LanguageItem> items, {
      int count = 20,
      Map<int, int>? masteryDistribution,
    }) {
    if (items.isEmpty) return [];
    
    // Calculate mastery distribution if not provided
    final distro = masteryDistribution ?? _calculateMasteryDistribution(items);
    
    // Group items by mastery level
    final Map<int, List<LanguageItem>> itemsByMastery = {};
    for (var item in items) {
      itemsByMastery.putIfAbsent(item.masteryLevel, () => []).add(item);
    }
    
    // Calculate target counts based on mastery distribution
    final targets = _calculateAdaptiveTargets(distro, count);
    
    // Select questions from each mastery level
    final List<Question> questions = [];
    for (var level in itemsByMastery.keys.toList()..sort()) {
      final targetCount = targets[level] ?? 0;
      if (targetCount <= 0) continue;
      
      final levelItems = itemsByMastery[level]!;
      final selected = levelItems.take(targetCount).toList();
      
      for (var item in selected) {
        bool ptToEn = _random.nextBool();
        questions.add(_createMultipleChoice(item, items, ptToEn));
      }
    }
    
    // Shuffle final result
    questions.shuffle(_random);
    return questions;
  }

  /// Calculates mastery distribution from language items
  Map<int, int> _calculateMasteryDistribution(List<LanguageItem> items) {
    final distro = <int, int>{};
    for (var item in items) {
      distro[item.masteryLevel] = (distro[item.masteryLevel] ?? 0) + 1;
    }
    return distro;
  }

  /// Calculates target question counts per mastery level for adaptive learning
  Map<int, int> _calculateAdaptiveTargets(Map<int, int> distro, int totalCount) {
    final targets = <int, int>{};
    
    // Calculate percentages based on mastery distribution
    int totalItems = distro.values.fold(0, (a, b) => a + b);
    if (totalItems == 0) return {0: totalCount};
    
    // Adaptive formula:
    // - Low mastery (0-1): Get extra focus for reinforcement
    // - Medium mastery (2-3): Standard practice
    // - High mastery (4-5): Some challenge questions
    
    final lowMasteryCount = (distro[0] ?? 0) + (distro[1] ?? 0);
    final mediumMasteryCount = (distro[2] ?? 0) + (distro[3] ?? 0);
    final highMasteryCount = (distro[4] ?? 0) + (distro[5] ?? 0);
    
    // Calculate weights based on distribution
    double lowWeight = lowMasteryCount / totalItems * 2.0; // Extra weight for reinforcement
    double mediumWeight = mediumMasteryCount / totalItems;
    double highWeight = highMasteryCount / totalItems * 0.5; // Less weight, focus on gaps
    
    // Normalize weights
    final sumWeights = lowWeight + mediumWeight + highWeight;
    if (sumWeights > 0) {
      lowWeight /= sumWeights;
      mediumWeight /= sumWeights;
      highWeight /= sumWeights;
    }
    
    // Calculate target counts
    targets[0] = (lowWeight * totalCount).floor();
    targets[1] = ((lowMasteryCount > 1 ? lowWeight : 0) * totalCount).floor();
    targets[2] = (mediumWeight * totalCount).floor();
    targets[3] = (mediumWeight * totalCount).floor();
    targets[4] = (highWeight * totalCount / 2).floor();
    targets[5] = (highWeight * totalCount / 2).floor();
    
    // Ensure we have at least some questions from each relevant level
    if (distro.containsKey(0) && targets[0] == 0 && lowMasteryCount > 0) {
      targets[0] = 1;
    }
    if (distro.containsKey(2) && targets[2] == 0 && mediumMasteryCount > 0) {
      targets[2] = 1;
    }
    
    // Adjust to meet total count
    int currentTotal = targets.values.fold(0, (a, b) => a + b);
    while (currentTotal < totalCount) {
      if (targets[0]! < lowMasteryCount) {
        targets[0] = (targets[0]! + 1);
      } else if (targets[2]! < mediumMasteryCount) {
        targets[2] = (targets[2]! + 1);
      } else if (targets[4]! < highMasteryCount) {
        targets[4] = (targets[4]! + 1);
      }
      currentTotal++;
    }

    return targets;
  }

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

  /// Generates an adaptive vocabulary quiz based on mastery levels
  List<Question> generateAdaptiveVocabularyQuiz(
    List<LanguageItem> items, {
      required Map<int, int> masteryDistribution,
      int count = 20,
      List<String>? seenIds,
    }) {
    if (items.isEmpty) return [];

    // Calculate mastery statistics
    final lowMasteryCount = (masteryDistribution[0] ?? 0) + (masteryDistribution[1] ?? 0);
    final highMasteryCount = (masteryDistribution[4] ?? 0) + (masteryDistribution[5] ?? 0);
    final totalItems = masteryDistribution.values.fold(0, (a, b) => a + b);
    
    // Adjust selection strategy based on user mastery
    double lowMasteryPercentage = totalItems > 0 ? lowMasteryCount / totalItems : 0.5;
    
    // Partition into Words and Phrases as before
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
    
    // For adaptive learning, adjust the balance based on mastery
    int targetWordsCount;
    if (lowMasteryPercentage > 0.6) {
      // Focus more on words for beginners
      targetWordsCount = (count * 0.7).floor();
    } else if (highMasteryCount / totalItems > 0.5) {
      // More phrases for advanced users
      targetWordsCount = (count * 0.3).floor();
    } else {
      // Standard balance
      targetWordsCount = (count / 2).floor();
    }
    
    // Helper to select from a pool while prioritizing unseen items
    List<LanguageItem> getPrioritized(List<LanguageItem> pool, int limit) {
      if (pool.isEmpty) return [];
      
      final unseen = <LanguageItem>[];
      final seen = <LanguageItem>[];
      
      for (var item in pool) {
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
    
    final selectedWords = getPrioritized(words, targetWordsCount);
    final int remainingCount = count - selectedWords.length;
    final selectedPhrases = getPrioritized(phrases, remainingCount);
    
    // Final recombination and shuffle
    final selection = [...selectedWords, ...selectedPhrases]..shuffle(_random);
    
    final List<Question> questions = [];
    for (var item in selection) {
      questions.add(_createVocabularyMatch(item, items));
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

  /// Creates a multiple choice question with difficulty based on mastery level
  Question _createMultipleChoice(
    LanguageItem target,
    List<LanguageItem> pool,
    bool ptToEn,
  ) {
    String questionText = ptToEn ? target.portuguese : target.english;
    String correctAnswer = ptToEn ? target.english : target.portuguese;
    
    // For high mastery items, use more challenging question formats
    if (target.masteryLevel >= 4) {
      // Use reverse direction more often for advanced users
      if (_random.nextDouble() < 0.7) {
        ptToEn = !ptToEn;
        questionText = ptToEn ? target.portuguese : target.english;
        correctAnswer = ptToEn ? target.english : target.portuguese;
      }
    }

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

  /// Generates an adaptive interrogative quiz based on mastery
  Future<List<Question>> generateAdaptiveInterrogativeQuiz({
    required Map<int, int> masteryDistribution,
    int count = 20,
    String? category,
    List<String>? seenIds,
  }) async {
    // Load data
    final String content = await rootBundle.loadString(
      'assets/data/interrogatives.json',
    );
    final List<dynamic> jsonList = jsonDecode(content);
    
    final List<Map<String, String>> allEntries = jsonList.map((e) {
      return {
        'interrogative': (e['interrogative'] ?? '') as String,
        'portuguese': (e['portuguese'] ?? '') as String,
        'english': (e['english'] ?? '') as String,
        'category': (e['category'] ?? '') as String,
      };
    }).toList();
    
    // Filter by category
    final filtered = category != null
        ? allEntries.where((e) => e['category'] == category).toList()
        : List<Map<String, String>>.from(allEntries);
    
    if (filtered.isEmpty) return [];
    
    // For adaptive learning, prioritize interrogatives based on user mastery
    // We'll use a simple approach: if user has low overall mastery, focus on basic interrogatives
    final lowMasteryCount = (masteryDistribution[0] ?? 0) + (masteryDistribution[1] ?? 0);
    final totalItems = masteryDistribution.values.fold(0, (a, b) => a + b);
    final lowMasteryPercentage = totalItems > 0 ? lowMasteryCount / totalItems : 0.5;
    
    // Group interrogatives by difficulty (basic vs advanced)
    final basicInterrogatives = <Map<String, String>>[];
    final advancedInterrogatives = <Map<String, String>>[];
    
    for (var entry in filtered) {
      final portuguese = entry['portuguese']!;
      // Simple heuristic: longer questions are more advanced
      if (portuguese.length < 30) {
        basicInterrogatives.add(entry);
      } else {
        advancedInterrogatives.add(entry);
      }
    }
    
    // Select based on user mastery level
    List<Map<String, String>> selectionPool;
    if (lowMasteryPercentage > 0.6) {
      // Focus on basic interrogatives for beginners
      selectionPool = [...basicInterrogatives, ...advancedInterrogatives];
    } else {
      // Balanced approach for intermediate/advanced users
      selectionPool = [...filtered]..shuffle(_random);
    }
    
    // Prioritize unseen questions
    final unseen = <Map<String, String>>[];
    final seen = <Map<String, String>>[];
    
    for (var entry in selectionPool) {
      final qId = 'interrog_${entry['portuguese']!.hashCode}';
      if (seenIds != null && seenIds.contains(qId)) {
        seen.add(entry);
      } else {
        unseen.add(entry);
      }
    }
    
    unseen.shuffle(_random);
    seen.shuffle(_random);
    
    final selection = [...unseen, ...seen].take(count).toList();
    
    // Build questions
    final List<Question> questions = [];
    for (var entry in selection) {
      final correctAnswer = entry['english']!;
      final entryCategory = entry['category']!;
      final qId = 'interrog_${entry['portuguese']!.hashCode}';
      
      // Build distractors
      final differentCategory = allEntries
          .where((e) => e['category'] != entryCategory && e['english'] != correctAnswer)
          .toList();
      final sameCategory = allEntries
          .where((e) => e['category'] == entryCategory && e['english'] != correctAnswer)
          .toList();
      
      differentCategory.shuffle(_random);
      sameCategory.shuffle(_random);
      
      final List<String> options = [correctAnswer];
      final Set<String> used = {correctAnswer.toLowerCase().trim()};
      
      // Take from different categories first
      for (var d in differentCategory) {
        if (options.length >= 4) break;
        final eng = d['english']!;
        if (!used.contains(eng.toLowerCase().trim())) {
          options.add(eng);
          used.add(eng.toLowerCase().trim());
        }
      }
      
      // Fill remaining from same category
      for (var d in sameCategory) {
        if (options.length >= 4) break;
        final eng = d['english']!;
        if (!used.contains(eng.toLowerCase().trim())) {
          options.add(eng);
          used.add(eng.toLowerCase().trim());
        }
      }
      
      options.shuffle(_random);
      
      questions.add(Question(
        id: qId,
        questionText: entry['portuguese']!,
        options: options,
        correctAnswer: correctAnswer,
        type: QuestionType.interrogativeMatch,
        sourceItem: LanguageItem(
          id: qId,
          portuguese: entry['portuguese']!,
          english: entry['english']!,
          notes: 'Interrogative: ${entry['interrogative']}',
        ),
        category: entryCategory,
      ));
    }
    
    return questions;
  }

  /// Generates a quiz from Portuguese interrogative phrases.
  /// Questions show a Portuguese question; options are English translations.
  Future<List<Question>> generateInterrogativeQuiz({
    int count = 20,
    String? category,
    List<String>? seenIds,
  }) async {
    // 1. Load data
    final String content = await rootBundle.loadString(
      'assets/data/interrogatives.json',
    );
    final List<dynamic> jsonList = jsonDecode(content);

    // 2. Parse all entries
    final List<Map<String, String>> allEntries = jsonList.map((e) {
      return {
        'interrogative': (e['interrogative'] ?? '') as String,
        'portuguese': (e['portuguese'] ?? '') as String,
        'english': (e['english'] ?? '') as String,
        'category': (e['category'] ?? '') as String,
      };
    }).toList();

    // 3. Filter by category if specified
    final filtered = category != null
        ? allEntries.where((e) => e['category'] == category).toList()
        : List<Map<String, String>>.from(allEntries);

    if (filtered.isEmpty) return [];

    // 4. Prioritize unseen
    final unseen = <Map<String, String>>[];
    final seen = <Map<String, String>>[];

    for (var entry in filtered) {
      final qId = 'interrog_${entry['portuguese']!.hashCode}';
      if (seenIds != null && seenIds.contains(qId)) {
        seen.add(entry);
      } else {
        unseen.add(entry);
      }
    }

    unseen.shuffle(_random);
    seen.shuffle(_random);

    final selection = [...unseen, ...seen].take(count).toList();

    // 5. Build questions
    final List<Question> questions = [];
    for (var entry in selection) {
      final correctAnswer = entry['english']!;
      final entryCategory = entry['category']!;
      final qId = 'interrog_${entry['portuguese']!.hashCode}';

      // Build distractors: prefer entries from DIFFERENT categories
      final differentCategory = allEntries
          .where((e) => e['category'] != entryCategory && e['english'] != correctAnswer)
          .toList();
      final sameCategory = allEntries
          .where((e) => e['category'] == entryCategory && e['english'] != correctAnswer)
          .toList();

      differentCategory.shuffle(_random);
      sameCategory.shuffle(_random);

      final List<String> options = [correctAnswer];
      final Set<String> used = {correctAnswer.toLowerCase().trim()};

      // Take from different categories first
      for (var d in differentCategory) {
        if (options.length >= 4) break;
        final eng = d['english']!;
        if (!used.contains(eng.toLowerCase().trim())) {
          options.add(eng);
          used.add(eng.toLowerCase().trim());
        }
      }

      // Fill remaining from same category if needed
      for (var d in sameCategory) {
        if (options.length >= 4) break;
        final eng = d['english']!;
        if (!used.contains(eng.toLowerCase().trim())) {
          options.add(eng);
          used.add(eng.toLowerCase().trim());
        }
      }

      options.shuffle(_random);

      questions.add(Question(
        id: qId,
        questionText: entry['portuguese']!,
        options: options,
        correctAnswer: correctAnswer,
        type: QuestionType.interrogativeMatch,
        sourceItem: LanguageItem(
          id: qId,
          portuguese: entry['portuguese']!,
          english: entry['english']!,
          notes: 'Interrogative: ${entry['interrogative']}',
        ),
        category: entryCategory,
      ));
    }

    return questions;
  }
}
