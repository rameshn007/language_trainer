import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import '../models/verb.dart';
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
    // Randomly choose direction: PT->EN or EN->PT
    bool ptToEn = _random.nextBool();
    String questionText = ptToEn ? target.portuguese : target.english;
    String correctAnswer = ptToEn ? target.english : target.portuguese;

    // Generate distractors
    final List<String> options = [correctAnswer];
    final Set<String> used = {correctAnswer.toLowerCase().trim()};

    // Try to find distractors from the pool
    // Ensure at least 4 choices total
    int attempts = 0;
    while (options.length < 4 && attempts < 100) {
      final randomItem = pool[_random.nextInt(pool.length)];
      String distractor = ptToEn ? randomItem.english : randomItem.portuguese;

      if (!used.contains(distractor.toLowerCase().trim()) && distractor.isNotEmpty) {
        options.add(distractor);
        used.add(distractor.toLowerCase().trim());
      }
      attempts++;
    }

    // Shuffle options
    options.shuffle(_random);

    final variantSuffix = ptToEn ? 'pt_en' : 'en_pt';
    final qId = 'vocab_${target.id}_$variantSuffix';

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

  /// Generates a quiz for prepositions.
  /// Questions show a Portuguese sentence with a blank; options are prepositions.
  Future<List<Question>> generatePrepositionQuiz({
    int count = 20,
    String? category,
    List<String>? seenIds,
  }) async {
    // 1. Load data
    final String content = await rootBundle.loadString(
      'assets/data/prepositions.json',
    );
    final List<dynamic> jsonList = jsonDecode(content);

    // 2. Parse all entries
    final List<Map<String, String>> allEntries = jsonList.map((e) {
      return {
        'id': (e['id'] ?? '') as String,
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
      final qId = 'prep_${entry['id']}';
      if (seenIds != null && seenIds.contains(qId)) {
        seen.add(entry);
      } else {
        unseen.add(entry);
      }
    }

    unseen.shuffle(_random);
    seen.shuffle(_random);

    final selection = [...unseen, ...seen].take(count).toList();

    // Common prepositions for options
    const allPreps = [
      'ao', 'à', 'aos', 'às',
      'do', 'da', 'dos', 'das',
      'no', 'na', 'nos', 'nas',
      'de', 'a', 'em', 'para'
    ];

    // 5. Build questions
    final List<Question> questions = [];
    for (var entry in selection) {
      final fullText = entry['portuguese']!;
      final english = entry['english']!;
      final qId = 'prep_${entry['id']}';

      // Find which preposition is used in the sentence
      String? foundPrep;
      for (var p in allPreps) {
        // Look for the preposition as a whole word, case insensitive
        // But we need to be careful with "a" and "de" and "em" which are parts of other words
        final regex = RegExp('\\b$p\\b', caseSensitive: false);
        if (regex.hasMatch(fullText)) {
          // If we found a longer preposition (like "ao"), don't let "a" match it
          if (foundPrep == null || p.length > foundPrep.length) {
            foundPrep = p;
          }
        }
      }

      // If we can't find the prep (shouldn't happen with good data), skip
      if (foundPrep == null) continue;

      // Replace the found preposition with a blank
      // Use the exact case of the preposition in the text for the correctAnswer
      final match = RegExp('\\b$foundPrep\\b', caseSensitive: false).firstMatch(fullText);
      final actualPrep = match!.group(0)!;
      final questionText = fullText.replaceRange(match.start, match.end, '____');

      // Options: the correct one + 3 others from the list
      final List<String> options = [actualPrep];
      final Set<String> used = {actualPrep.toLowerCase()};
      final bool isCapitalized = actualPrep.isNotEmpty && actualPrep[0] == actualPrep[0].toUpperCase() && actualPrep[0] != actualPrep[0].toLowerCase();

      final otherPreps = allPreps
          .where((p) => p.toLowerCase() != actualPrep.toLowerCase())
          .toList()
        ..shuffle(_random);

      for (var p in otherPreps) {
        if (options.length >= 4) break;
        if (!used.contains(p.toLowerCase())) {
          String distractor = p;
          if (isCapitalized && distractor.isNotEmpty) {
            distractor = distractor[0].toUpperCase() + distractor.substring(1);
          }
          options.add(distractor);
          used.add(p.toLowerCase());
        }
      }

      options.shuffle(_random);

      questions.add(Question(
        id: qId,
        questionText: questionText,
        options: options,
        correctAnswer: actualPrep,
        type: QuestionType.prepositionFill,
        sourceItem: LanguageItem(
          id: qId,
          portuguese: fullText, // Store full text here so TTS can read it
          english: english,
        ),
        category: entry['category'],
      ));
    }

    return questions;
  }

  /// Generates a set of multiple-choice verb conjugation questions.
  List<Question> generateVerbConjugationQuestions({
    required List<Verb> verbs,
    int count = 10,
    List<String>? seenIds,
  }) {
    if (verbs.isEmpty) return [];

    final List<Question> questions = [];
    
    // 1. Partition into unseen and seen
    final unseenVerbs = <Verb>[];
    final seenVerbs = <Verb>[];

    for (var verb in verbs) {
      // Use a sample pronoun to check if this verb has been practiced
      // In the future, we could check ALL pronouns, but this is a good heuristic
      final qId = 'verb_conj_${verb.infinitive}_${'eu'.hashCode}';
      if (seenIds != null && seenIds.contains(qId)) {
        seenVerbs.add(verb);
      } else {
        unseenVerbs.add(verb);
      }
    }

    unseenVerbs.shuffle(_random);
    seenVerbs.shuffle(_random);

    final selection = [...unseenVerbs, ...seenVerbs].take(count).toList();
    final pronouns = ['eu', 'tu', 'você, ela, ele', 'nós', 'vocês, elas, eles'];

    for (var verb in selection) {
      final pronoun = pronouns[_random.nextInt(pronouns.length)];
      final correctAnswer = verb.conjugations[pronoun];
      if (correctAnswer == null || correctAnswer.isEmpty) continue;

      final qId = 'verb_conj_${verb.infinitive}_${pronoun.hashCode}';

      // Distractors: other conjugations of the SAME verb + some from other verbs
      final List<String> options = [correctAnswer];
      final Set<String> used = {correctAnswer.toLowerCase().trim()};

      // Add other conjugations of same verb as distractors
      final otherConjs = verb.conjugations.values
          .where((c) => c != correctAnswer && c.isNotEmpty)
          .toList();
      otherConjs.shuffle(_random);
      for (var c in otherConjs) {
        if (options.length >= 4) break;
        if (!used.contains(c.toLowerCase().trim())) {
          options.add(c);
          used.add(c.toLowerCase().trim());
        }
      }

      // If still need more, take from other random verbs
      int attempts = 0;
      while (options.length < 4 && attempts < 50) {
        final randomVerb = verbs[_random.nextInt(verbs.length)];
        final randomConj = randomVerb.conjugations.values.elementAt(_random.nextInt(randomVerb.conjugations.length));
        if (!used.contains(randomConj.toLowerCase().trim()) && randomConj.isNotEmpty) {
          options.add(randomConj);
          used.add(randomConj.toLowerCase().trim());
        }
        attempts++;
      }

      options.shuffle(_random);

      questions.add(Question(
        id: qId,
        questionText: "Conjugate '${verb.infinitive}' for '$pronoun'",
        options: options,
        correctAnswer: correctAnswer,
        type: QuestionType.multipleChoice,
        sourceItem: LanguageItem(
          id: 'verb_${verb.infinitive}',
          portuguese: '$pronoun $correctAnswer',
          english: "${verb.translation} ($pronoun)",
        ),
      ));
    }

    return questions;
  }

  /// Generates a set of cloze (fill-in-the-blank) questions from example sentences.
  List<Question> generateClozeQuestionsFromExamples(
    List<LanguageItem> items, {
    int count = 10,
    List<String>? seenIds,
  }) {
    if (items.isEmpty) return [];

    final validItems = items.where((item) => 
      item.exampleSentencePt != null && 
      item.exampleSentencePt!.isNotEmpty &&
      item.portuguese.isNotEmpty &&
      // Check if the portuguese word is actually in the sentence (case insensitive)
      item.exampleSentencePt!.toLowerCase().contains(item.portuguese.toLowerCase())
    ).toList();

    if (validItems.isEmpty) return [];

    final unseenItems = <LanguageItem>[];
    final seenItems = <LanguageItem>[];

    for (var item in validItems) {
      final qId = 'cloze_${item.id}';
      if (seenIds != null && seenIds.contains(qId)) {
        seenItems.add(item);
      } else {
        unseenItems.add(item);
      }
    }

    unseenItems.shuffle(_random);
    seenItems.shuffle(_random);

    final selection = [...unseenItems, ...seenItems].take(count).toList();
    final List<Question> questions = [];

    for (var item in selection) {
      final String ptWord = item.portuguese;
      final String sentence = item.exampleSentencePt!;
      
      // Find the word in the sentence to preserve the original casing in the correct answer
      final regex = RegExp(RegExp.escape(ptWord), caseSensitive: false);
      final match = regex.firstMatch(sentence);
      
      if (match == null) continue;
      
      final actualWord = sentence.substring(match.start, match.end);
      final questionText = sentence.replaceRange(match.start, match.end, '____');
      final qId = 'cloze_${item.id}';

      // Generate distractors
      final List<String> options = [actualWord];
      final Set<String> used = {actualWord.toLowerCase()};
      
      // Try to find distractors from the same word_type or just random items
      final pool = validItems.where((i) => i.wordType == item.wordType && i.id != item.id).toList();
      if (pool.isEmpty) pool.addAll(validItems);
      
      pool.shuffle(_random);

      for (var distractorItem in pool) {
        if (options.length >= 4) break;
        final String distractor = distractorItem.portuguese.toLowerCase();
        
        if (!used.contains(distractor)) {
          // Try to match casing if the actual word is capitalized
          bool isCapitalized = actualWord.isNotEmpty && actualWord[0] == actualWord[0].toUpperCase() && actualWord[0] != actualWord[0].toLowerCase();
          String finalDistractor = distractor;
          if (isCapitalized && distractor.isNotEmpty) {
            finalDistractor = distractor[0].toUpperCase() + distractor.substring(1);
          }
          
          options.add(finalDistractor);
          used.add(distractor);
        }
      }

      // If we couldn't find enough distractors, fill with something else
      if (options.length < 4) {
        final List<String> backups = ['o', 'a', 'um', 'uma', 'é', 'não', 'sim'];
        for (var b in backups) {
          if (options.length >= 4) break;
          if (!used.contains(b)) {
            options.add(b);
            used.add(b);
          }
        }
      }

      options.shuffle(_random);

      questions.add(Question(
        id: qId,
        questionText: questionText,
        options: options,
        correctAnswer: actualWord,
        type: QuestionType.cloze,
        sourceItem: LanguageItem(
          id: item.id,
          portuguese: item.exampleSentencePt!,
          english: item.exampleSentenceEn!,
          notes: item.notes,
        ),
      ));
    }

    return questions;
  }
}
