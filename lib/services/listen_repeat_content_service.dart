import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/language_item.dart';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'verb_service.dart';

enum ListenRepeatMode {
  all,
  topics,
  verbs,
  prepositions,
  phrases,
  vocabulary,
}

extension ListenRepeatModeExtension on ListenRepeatMode {
  String get label {
    switch (this) {
      case ListenRepeatMode.all:
        return 'Balanced Mix';
      case ListenRepeatMode.topics:
        return 'A2 Everyday Topics';
      case ListenRepeatMode.verbs:
        return 'Verbs & Tenses';
      case ListenRepeatMode.prepositions:
        return 'Prepositions';
      case ListenRepeatMode.phrases:
        return 'Phrases & Sentences';
      case ListenRepeatMode.vocabulary:
        return 'Core Vocabulary';
    }
  }

  String get badge {
    switch (this) {
      case ListenRepeatMode.all:
        return 'Mix';
      case ListenRepeatMode.topics:
        return 'Topics';
      case ListenRepeatMode.verbs:
        return 'Verbs';
      case ListenRepeatMode.prepositions:
        return 'Prepositions';
      case ListenRepeatMode.phrases:
        return 'Phrases';
      case ListenRepeatMode.vocabulary:
        return 'Vocab';
    }
  }

  String get description {
    switch (this) {
      case ListenRepeatMode.all:
        return 'Mix of verbs, phrases, and vocabulary';
      case ListenRepeatMode.topics:
        return 'House, health, household & everyday items';
      case ListenRepeatMode.verbs:
        return 'Conjugations & verb phrases';
      case ListenRepeatMode.prepositions:
        return 'Prepositions, contractions, and locatives';
      case ListenRepeatMode.phrases:
        return 'Everyday phrases & sentences';
      case ListenRepeatMode.vocabulary:
        return 'Essential words & vocabulary';
    }
  }
}

final listenRepeatContentServiceProvider = Provider<ListenRepeatContentService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final verbService = ref.watch(verbServiceProvider);
  return ListenRepeatContentService(storage, verbService);
});

final listenRepeatModeCountsProvider = FutureProvider<Map<ListenRepeatMode, int>>((ref) async {
  final contentService = ref.watch(listenRepeatContentServiceProvider);
  return contentService.getModeCounts();
});

class ListenRepeatContentService {
  final StorageService _storageService;
  final VerbService _verbService;

  Map<ListenRepeatMode, int>? _cachedModeCounts;

  List<LanguageItem>? _cachedPhrases;
  List<LanguageItem>? _cachedVerbPhrases;
  List<LanguageItem>? _cachedExampleSentences;
  List<LanguageItem>? _cachedConjugations;
  List<LanguageItem>? _cachedPrepositions;
  List<LanguageItem>? _cachedTopicWords;

  ListenRepeatContentService(this._storageService, this._verbService);

  static const Set<String> _targetTopicCategories = {
    'House & Rooms',
    'Household Items',
    'Body & Health',
    'Everyday Items',
  };

  static const Set<String> _targetTopicVerbs = {
    'cozinhar', 'dormir', 'descansar', 'guardar', 'arrumar', 'aquecer',
    'assar', 'ferver', 'varrer', 'escovar', 'lavar', 'doer', 'torcer',
    'carregar', 'esquecer', 'validar', 'proteger', 'levar',
    'engomar', 'aspirar', 'estender',
  };

  /// Returns true if the item belongs to the newly added A2 topic sets:
  /// House & Rooms, Household Items & Appliances, Body & Health, or Everyday Items.
  static bool isTopicItem(LanguageItem item) {
    if (_targetTopicCategories.contains(item.topicCategory)) return true;
    if (item.wordType == 'topic_word') return true;
    final note = item.notes.toLowerCase();
    if (note.contains('a casa') ||
        note.contains('rooms in the house') ||
        note.contains('house parts') ||
        note.contains('house spaces') ||
        note.contains('housing') ||
        note.contains('house fixtures') ||
        note.contains('house heating') ||
        note.contains('furniture & rooms') ||
        note.contains('objetos') ||
        note.contains('saúde') ||
        note.contains('saude') ||
        note.contains('quotidiano') ||
        note.contains('house & rooms') ||
        note.contains('household items') ||
        note.contains('body & health') ||
        note.contains('everyday items') ||
        note.contains('palavra •')) {
      return true;
    }
    if (item.wordType == 'verb_phrase') {
      final parts = item.id.split('_');
      // id format: verb_phrase_${verb}_$i
      if (parts.length >= 3 && _targetTopicVerbs.contains(parts[2])) {
        return true;
      }
    }
    return false;
  }

  static const Map<String, Set<String>> _topicVerbsByCategory = {
    'House & Rooms': {'cozinhar', 'dormir', 'descansar', 'guardar', 'arrumar'},
    'Household Items': {'aquecer', 'assar', 'ferver', 'varrer', 'engomar', 'aspirar', 'estender'},
    'Body & Health': {'escovar', 'lavar', 'doer', 'torcer'},
    'Everyday Items': {'carregar', 'esquecer', 'validar', 'proteger', 'levar'},
  };

  /// Matches an item against a sub-topic category filter.
  static bool matchesSubCategory(LanguageItem item, String subCategory) {
    if (subCategory == 'All Topics' || subCategory.isEmpty) return true;
    if (item.topicCategory == subCategory) return true;
    final note = item.notes.toLowerCase();
    switch (subCategory) {
      case 'House & Rooms':
        if (note.contains('a casa') ||
            note.contains('rooms in the house') ||
            note.contains('house parts') ||
            note.contains('house spaces') ||
            note.contains('housing') ||
            note.contains('furniture & rooms') ||
            note.contains('house fixtures') ||
            note.contains('house heating') ||
            note.contains('casa de banho') ||
            note.contains('house & rooms') ||
            note.contains('divis')) {
          return true;
        }
        break;
      case 'Household Items':
        if (note.contains('objetos') ||
            note.contains('household items') ||
            note.contains('household') ||
            note.contains('eletrodomésticos') ||
            note.contains('eletrodomesticos') ||
            note.contains('kitchen appliances') ||
            note.contains('bedding') ||
            note.contains('cleaning items') ||
            note.contains('cookware') ||
            note.contains('tableware') ||
            note.contains('cutlery')) {
          return true;
        }
        break;
      case 'Body & Health':
        if (note.contains('saúde') ||
            note.contains('saude') ||
            note.contains('body & health') ||
            note.contains('body parts') ||
            note.contains('corpo')) {
          return true;
        }
        break;
      case 'Everyday Items':
        if (note.contains('quotidiano') ||
            note.contains('everyday items') ||
            note.contains('stationery') ||
            note.contains('personal belongings') ||
            note.contains('everyday electronics') ||
            note.contains('daily essentials') ||
            note.contains('accessories')) {
          return true;
        }
        break;
    }
    if (item.wordType == 'verb_phrase') {
      final parts = item.id.split('_');
      if (parts.length >= 3) {
        final verb = parts[2];
        if (_topicVerbsByCategory[subCategory]?.contains(verb) == true) {
          return true;
        }
      }
    }
    return false;
  }

  /// Builds a phrase deck where newly added A2 topic phrases are heavily biased
  /// to appear early and frequently (1 priority topic phrase for every 2 general phrases)
  /// rather than being diluted to <4% by 870+ example sentences.
  List<LanguageItem> _buildBiasedPhrasesPool(List<LanguageItem> candidatePhrases) {
    final priority = candidatePhrases.where(isTopicItem).toList()..shuffle();
    final general = candidatePhrases.where((i) => !isTopicItem(i)).toList()..shuffle();

    if (priority.isEmpty) {
      return [...general];
    }

    final biased = <LanguageItem>[];
    int pIdx = 0;
    int gIdx = 0;

    // Interleave pattern: 1 Priority Topic Phrase -> 2 General Phrases
    while (pIdx < priority.length || gIdx < general.length) {
      if (pIdx < priority.length) {
        biased.add(priority[pIdx++]);
      }
      for (int i = 0; i < 2 && gIdx < general.length; i++) {
        biased.add(general[gIdx++]);
      }
    }

    return biased;
  }

  Future<Map<ListenRepeatMode, int>> getModeCounts() async {
    if (_cachedModeCounts != null) return _cachedModeCounts!;
    final vocabItems = _storageService.getAllItems();
    if (vocabItems.isEmpty) {
      return {for (final m in ListenRepeatMode.values) m: 0};
    }
    await _ensureAuxiliaryDataLoaded();

    final phrases = _cachedPhrases ?? [];
    final verbPhrases = _cachedVerbPhrases ?? [];
    final exampleSentences = _cachedExampleSentences ?? [];
    final conjugations = _cachedConjugations ?? [];
    final prepositions = _cachedPrepositions ?? [];

    final verbsCount = conjugations.length + verbPhrases.length + vocabItems.where((i) => i.id.startsWith('verb_') || i.wordType == 'verb').length;
    final prepCount = prepositions.length;
    final phrasesCount = phrases.length + verbPhrases.length + exampleSentences.length;
    final phrasePtSet = {
      for (final p in phrases) p.portuguese.trim().toLowerCase(),
      for (final p in verbPhrases) p.portuguese.trim().toLowerCase(),
      for (final p in exampleSentences) p.portuguese.trim().toLowerCase(),
    };
    final vocabCount = vocabItems
        .where((i) => !i.id.startsWith('verb_') && !phrasePtSet.contains(i.portuguese.trim().toLowerCase()))
        .length;
    final allCount = vocabCount + phrasesCount + conjugations.length + prepCount;

    final allTopicWords = _resolveTopicWords(vocabItems);

    final topicCandidates = [
      ...phrases.where(isTopicItem),
      ...verbPhrases.where(isTopicItem),
      ...allTopicWords,
    ];
    final topicsCount = topicCandidates.length;

    _cachedModeCounts = {
      ListenRepeatMode.all: allCount,
      ListenRepeatMode.topics: topicsCount,
      ListenRepeatMode.verbs: verbsCount,
      ListenRepeatMode.prepositions: prepCount,
      ListenRepeatMode.phrases: phrasesCount,
      ListenRepeatMode.vocabulary: vocabCount,
    };
    return _cachedModeCounts!;
  }

  /// Resolves the unified topic words list, merging storage items (preserving user IDs
  /// and mastery progress) with curated A2 topic words (preserving authentic orthography,
  /// articles, and paired target phrases).
  ///
  /// Iterates curated items directly so keyword collisions between two curated entries
  /// can never overwrite or drop a word from the pool.
  List<LanguageItem> _resolveTopicWords(List<LanguageItem> vocabItems) {
    final allTopicWords = <LanguageItem>[];
    final claimedVocabIds = <String>{};

    for (final curated in _cachedTopicWords ?? <LanguageItem>[]) {
      final curatedKw = _extractKeyword(curated.portuguese);

      // Look for a matching unclaimed item in storage
      LanguageItem? matchingStorageItem;
      if (curatedKw.isNotEmpty) {
        for (final v in vocabItems) {
          if (claimedVocabIds.contains(v.id)) continue;
          if (isTopicItem(v) &&
              v.wordType != 'phrase' &&
              v.wordType != 'verb_phrase' &&
              v.wordType != 'example_sentence') {
            if (_extractKeyword(v.portuguese) == curatedKw) {
              matchingStorageItem = v;
              break;
            }
          }
        }
      }

      if (matchingStorageItem != null) {
        claimedVocabIds.add(matchingStorageItem.id);
        allTopicWords.add(
          LanguageItem(
            id: matchingStorageItem.id,
            portuguese: curated.portuguese,
            english: curated.english,
            wordType: 'topic_word',
            topicCategory: curated.topicCategory ?? matchingStorageItem.topicCategory,
            notes: curated.notes,
            exampleSentencePt: curated.exampleSentencePt,
            exampleSentenceEn: curated.exampleSentenceEn,
            masteryLevel: matchingStorageItem.masteryLevel,
            lastReviewed: matchingStorageItem.lastReviewed,
          ),
        );
      } else {
        // Retain curated word as-is
        allTopicWords.add(curated);
      }
    }

    // Include any additional topic words found in storage that were not in curated list
    final existingKeywords = {
      for (final w in allTopicWords) _extractKeyword(w.portuguese),
    };
    for (final v in vocabItems) {
      if (claimedVocabIds.contains(v.id)) continue;
      if (isTopicItem(v) &&
          v.wordType != 'phrase' &&
          v.wordType != 'verb_phrase' &&
          v.wordType != 'example_sentence') {
        final kw = _extractKeyword(v.portuguese);
        if (kw.isNotEmpty && !existingKeywords.contains(kw)) {
          allTopicWords.add(v);
          existingKeywords.add(kw);
        }
      }
    }

    return allTopicWords;
  }

  Future<List<LanguageItem>> loadContent({
    ListenRepeatMode mode = ListenRepeatMode.all,
    String? subCategory,
  }) async {
    final vocabItems = _storageService.getAllItems();
    if (vocabItems.isEmpty) {
      return [];
    }

    // Ensure our auxiliary pools are loaded
    await _ensureAuxiliaryDataLoaded();

    final phrases = _cachedPhrases ?? [];
    final verbPhrases = _cachedVerbPhrases ?? [];
    final exampleSentences = _cachedExampleSentences ?? [];
    final conjugations = _cachedConjugations ?? [];
    final prepositions = _cachedPrepositions ?? [];

    AppLogger.log(
      'Loaded auxiliary pools: ${phrases.length} phrases, ${verbPhrases.length} verb phrases, '
      '${exampleSentences.length} examples, ${conjugations.length} conjugations, '
      '${prepositions.length} prepositions, ${vocabItems.length} vocab',
      name: 'ListenRepeatContent',
    );

    switch (mode) {
      case ListenRepeatMode.topics:
        final allTopicWords = _resolveTopicWords(vocabItems);
        final topicPhrases = phrases.where(isTopicItem).toList();
        final topicVerbPhrases = verbPhrases.where(isTopicItem).toList();

        return _buildTopicMixedPool(
          words: allTopicWords,
          phrases: topicPhrases,
          verbPhrases: topicVerbPhrases,
          subCategory: subCategory,
        );

      case ListenRepeatMode.verbs:
        final list = <LanguageItem>[];
        list.addAll(conjugations);
        list.addAll(verbPhrases);
        // Include verb infinitives from vocab
        list.addAll(vocabItems.where((i) => i.id.startsWith('verb_') || i.wordType == 'verb'));
        list.shuffle();
        return list;

      case ListenRepeatMode.prepositions:
        final list = <LanguageItem>[];
        list.addAll(prepositions);
        list.shuffle();
        return list;

      case ListenRepeatMode.phrases:
        final allCandidates = <LanguageItem>[];
        allCandidates.addAll(phrases);
        allCandidates.addAll(verbPhrases);
        allCandidates.addAll(exampleSentences);
        return _buildBiasedPhrasesPool(allCandidates);

      case ListenRepeatMode.vocabulary:
        final list = vocabItems.where((i) => !i.id.startsWith('verb_')).toList();
        list.shuffle();
        return list;

      case ListenRepeatMode.all:
        return _buildBalancedPool(
          vocabItems: vocabItems,
          phrases: phrases,
          verbPhrases: verbPhrases,
          exampleSentences: exampleSentences,
          conjugations: conjugations,
          prepositions: prepositions,
        );
    }
  }

  /// Builds an interleaved pool so the learner experiences a steady, diverse
  /// rotation of words, conversational phrases, verb conjugations, and full sentences.
  List<LanguageItem> _buildBalancedPool({
    required List<LanguageItem> vocabItems,
    required List<LanguageItem> phrases,
    required List<LanguageItem> verbPhrases,
    required List<LanguageItem> exampleSentences,
    required List<LanguageItem> conjugations,
    required List<LanguageItem> prepositions,
  }) {
    final candidatePhrases = [...phrases, ...verbPhrases, ...exampleSentences];
    final allPhrases = _buildBiasedPhrasesPool(candidatePhrases);
    final allConjugations = [...conjugations]..shuffle();
    final allPrepositions = [...prepositions]..shuffle();
    final phrasePtSet = {
      for (final p in allPhrases) p.portuguese.trim().toLowerCase(),
    };
    final pureVocab = vocabItems
        .where((i) => !i.id.startsWith('verb_') && !phrasePtSet.contains(i.portuguese.trim().toLowerCase()))
        .toList()
      ..shuffle();

    final result = <LanguageItem>[];
    int vocabIndex = 0;
    int phraseIndex = 0;
    int conjIndex = 0;
    int prepIndex = 0;

    final totalTarget = pureVocab.length + allPhrases.length + allConjugations.length + allPrepositions.length;
    if (totalTarget == 0) return [];

    // Interleave pattern: 2 Vocab -> 1 Conjugation (Pres/Past/Fut) -> 1 Preposition -> 1 Phrase/Sentence
    while (result.length < totalTarget) {
      bool addedAny = false;

      // 1. Add up to 2 vocab items
      for (int i = 0; i < 2; i++) {
        if (vocabIndex < pureVocab.length) {
          result.add(pureVocab[vocabIndex++]);
          addedAny = true;
        }
      }

      // 2. Add 1 verb conjugation (e.g. Present, Past, or Future)
      if (conjIndex < allConjugations.length) {
        result.add(allConjugations[conjIndex++]);
        addedAny = true;
      }

      // 3. Add 1 preposition item (sentence, contraction, locative, or pronoun)
      if (prepIndex < allPrepositions.length) {
        result.add(allPrepositions[prepIndex++]);
        addedAny = true;
      }

      // 4. Add 1 conversational phrase or contextual sentence
      if (phraseIndex < allPhrases.length) {
        result.add(allPhrases[phraseIndex++]);
        addedAny = true;
      }

      if (!addedAny) break;
    }

    return result;
  }

  static String _extractKeyword(String portuguese) {
    String clean = portuguese.trim().toLowerCase();
    clean = clean.replaceFirst(RegExp(r'^(a|o|as|os|um|uma|uns|umas)\s+', caseSensitive: false), '').trim();
    if (clean.contains('/')) {
      clean = clean.split('/').first.trim();
    }
    return clean;
  }

  static bool _matchesWordBoundary(String text, String kw) {
    if (text.isEmpty || kw.isEmpty) return false;
    final lowerText = text.toLowerCase();
    final lowerKw = kw.toLowerCase();

    if (lowerKw.contains(' ')) {
      return lowerText.contains(lowerKw);
    }

    final regex = RegExp(r'(?:^|[^\p{L}\p{N}])' + RegExp.escape(lowerKw) + r'(?:[^\p{L}\p{N}]|$)', unicode: true);
    return regex.hasMatch(lowerText);
  }

  /// Builds a mixed deck for A2 Everyday Topics where individual words are learned
  /// and directly reinforced by phrases that use those words.
  List<LanguageItem> _buildTopicMixedPool({
    required List<LanguageItem> words,
    required List<LanguageItem> phrases,
    required List<LanguageItem> verbPhrases,
    String? subCategory,
  }) {
    final activeWords = (subCategory != null && subCategory.isNotEmpty && subCategory != 'All Topics')
        ? words.where((w) => matchesSubCategory(w, subCategory)).toList()
        : List<LanguageItem>.from(words);

    final activePhrases = (subCategory != null && subCategory.isNotEmpty && subCategory != 'All Topics')
        ? phrases.where((p) => matchesSubCategory(p, subCategory)).toList()
        : List<LanguageItem>.from(phrases);

    final activeVerbPhrases = (subCategory != null && subCategory.isNotEmpty && subCategory != 'All Topics')
        ? verbPhrases.where((vp) => matchesSubCategory(vp, subCategory)).toList()
        : List<LanguageItem>.from(verbPhrases);

    if (activeWords.isEmpty) {
      final fallback = [...activePhrases, ...activeVerbPhrases]..shuffle();
      return fallback;
    }

    final candidatePhrases = [...activePhrases, ...activeVerbPhrases];
    final usedPhraseIds = <String>{};

    // Build word-phrase pairs
    final pairs = <List<LanguageItem>>[];

    for (final word in activeWords) {
      final pair = <LanguageItem>[word];

      // 1. Try matching target phrase directly from exampleSentencePt
      LanguageItem? matchingPhrase;
      if (word.exampleSentencePt != null && word.exampleSentencePt!.isNotEmpty) {
        final targetPt = word.exampleSentencePt!.trim().toLowerCase();
        for (final p in candidatePhrases) {
          if (!usedPhraseIds.contains(p.id) && p.portuguese.trim().toLowerCase() == targetPt) {
            matchingPhrase = p;
            break;
          }
        }
      }

      // 2. If not found, try matching by base keyword with word boundary match
      if (matchingPhrase == null) {
        final kw = _extractKeyword(word.portuguese);
        if (kw.isNotEmpty) {
          for (final p in candidatePhrases) {
            if (usedPhraseIds.contains(p.id)) continue;
            if (_matchesWordBoundary(p.portuguese, kw) || _matchesWordBoundary(p.notes, kw)) {
              matchingPhrase = p;
              break;
            }
          }
        }
      }

      // 3. Fallback: if exampleSentencePt exists on word, create phrase item
      if (matchingPhrase == null && word.exampleSentencePt != null && word.exampleSentencePt!.isNotEmpty) {
        matchingPhrase = LanguageItem(
          id: 'phrase_target_${word.id}',
          portuguese: word.exampleSentencePt!,
          english: word.exampleSentenceEn ?? '',
          wordType: 'phrase',
          topicCategory: word.topicCategory ?? 'Topic Phrase',
          notes: '${word.topicCategory ?? "Tópico"}: ${word.portuguese}',
        );
      }

      if (matchingPhrase != null) {
        pair.add(matchingPhrase);
        usedPhraseIds.add(matchingPhrase.id);
      }

      pairs.add(pair);
    }

    // Shuffle the word groups so playthrough order is fresh
    pairs.shuffle();

    // Remaining phrases that weren't the primary phrase for any word
    final unusedPhrases = candidatePhrases.where((p) => !usedPhraseIds.contains(p.id)).toList()..shuffle();

    // Flatten: each word is immediately followed by its phrase, with unused phrases smoothly dispersed
    final result = <LanguageItem>[];
    int unusedIdx = 0;

    for (int i = 0; i < pairs.length; i++) {
      result.addAll(pairs[i]);

      // Every 3 word-pairs, insert an extra contextual/verb phrase if available
      if ((i + 1) % 3 == 0 && unusedIdx < unusedPhrases.length) {
        result.add(unusedPhrases[unusedIdx++]);
      }
    }

    while (unusedIdx < unusedPhrases.length) {
      result.add(unusedPhrases[unusedIdx++]);
    }

    return result;
  }

  @visibleForTesting
  List<LanguageItem> buildTopicMixedPoolForTesting({
    required List<LanguageItem> words,
    required List<LanguageItem> phrases,
    required List<LanguageItem> verbPhrases,
    String? subCategory,
  }) =>
      _buildTopicMixedPool(
        words: words,
        phrases: phrases,
        verbPhrases: verbPhrases,
        subCategory: subCategory,
      );

  @visibleForTesting
  static bool matchesWordBoundaryForTesting(String text, String kw) =>
      _matchesWordBoundary(text, kw);

  @visibleForTesting
  List<LanguageItem> resolveTopicWordsForTesting({
    required List<LanguageItem> vocabItems,
    List<LanguageItem>? curatedTopicWords,
  }) {
    final oldCached = _cachedTopicWords;
    if (curatedTopicWords != null) {
      _cachedTopicWords = curatedTopicWords;
    }
    final result = _resolveTopicWords(vocabItems);
    _cachedTopicWords = oldCached;
    return result;
  }

  Future<void> _ensureAuxiliaryDataLoaded() async {
    _cachedPhrases ??= await _loadPhrases();
    _cachedVerbPhrases ??= await _loadVerbPhrases();
    _cachedExampleSentences ??= await _loadExampleSentences();
    _cachedConjugations ??= await _generateConjugationItems();
    _cachedPrepositions ??= await _loadPrepositions();
    final loadedTopicWords = await _loadTopicWords();
    if (loadedTopicWords.isNotEmpty) {
      _cachedTopicWords = loadedTopicWords;
    }
  }

  /// Loads curated A2 individual topic words from assets/data/a2_topic_words.json
  Future<List<LanguageItem>> _loadTopicWords() async {
    final list = <LanguageItem>[];
    try {
      final jsonStr = await rootBundle.loadString('assets/data/a2_topic_words.json');
      final List<dynamic> data = jsonDecode(jsonStr);
      for (final item in data) {
        try {
          if (item is! Map<String, dynamic>) continue;
          final id = (item['id'] ?? '').toString();
          final pt = (item['portuguese'] ?? '').toString().trim();
          final en = (item['english'] ?? '').toString().trim();
          final cat = (item['category'] ?? '').toString().trim();
          final notes = (item['notes'] ?? 'Palavra').toString().trim();
          final targetPt = (item['targetPhrasePt'] ?? '').toString().trim();
          final targetEn = (item['targetPhraseEn'] ?? '').toString().trim();
          if (pt.isNotEmpty && en.isNotEmpty) {
            list.add(
              LanguageItem(
                id: id,
                portuguese: pt,
                english: en,
                wordType: 'topic_word',
                topicCategory: cat,
                notes: notes,
                exampleSentencePt: targetPt.isNotEmpty ? targetPt : null,
                exampleSentenceEn: targetEn.isNotEmpty ? targetEn : null,
              ),
            );
          }
        } catch (e) {
          AppLogger.error('Error parsing topic word entry: $item', name: 'ListenRepeatContent', error: e);
        }
      }
    } catch (e) {
      AppLogger.error('Error loading a2_topic_words.json', name: 'ListenRepeatContent', error: e);
    }
    return list;
  }

  /// Loads general conversational phrases from assets/data/phrases.json
  Future<List<LanguageItem>> _loadPhrases() async {
    final list = <LanguageItem>[];
    try {
      final jsonStr = await rootBundle.loadString('assets/data/phrases.json');
      final List<dynamic> data = jsonDecode(jsonStr);
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        final pt = (item['portuguese'] ?? '').toString().trim();
        final en = (item['english'] ?? '').toString().trim();
        final category = (item['category'] ?? item['topicCategory'] ?? 'Conversational Phrases').toString();
        final notes = (item['notes'] ?? 'Frase Útil').toString();
        if (pt.isNotEmpty && en.isNotEmpty) {
          list.add(
            LanguageItem(
              id: 'phrase_$i',
              portuguese: pt,
              english: en,
              wordType: 'phrase',
              topicCategory: category,
              notes: notes,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error loading phrases.json', name: 'ListenRepeatContent', error: e);
    }
    return list;
  }

  /// Loads contextual verb phrases from assets/data/verb_phrases.json
  Future<List<LanguageItem>> _loadVerbPhrases() async {
    final list = <LanguageItem>[];
    try {
      final jsonStr = await rootBundle.loadString('assets/data/verb_phrases.json');
      final List<dynamic> data = jsonDecode(jsonStr);
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        final pt = (item['portuguese'] ?? '').toString().trim();
        final en = (item['english'] ?? '').toString().trim();
        final verb = (item['verb'] ?? '').toString().trim();
        final category = (item['category'] ?? item['topicCategory'] ?? 'Verbs in Context').toString();
        final defaultNote = verb.isNotEmpty ? 'Verbo em Contexto: $verb' : 'Verbo em Contexto';
        final notes = (item['notes'] ?? defaultNote).toString();
        if (pt.isNotEmpty && en.isNotEmpty) {
          list.add(
            LanguageItem(
              id: 'verb_phrase_${verb}_$i',
              portuguese: pt,
              english: en,
              wordType: 'verb_phrase',
              topicCategory: category,
              notes: notes,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error loading verb_phrases.json', name: 'ListenRepeatContent', error: e);
    }
    return list;
  }

  /// Extracts contextual example sentences from assets/vocabulary.json
  Future<List<LanguageItem>> _loadExampleSentences() async {
    final list = <LanguageItem>[];
    try {
      final jsonStr = await rootBundle.loadString('assets/vocabulary.json');
      final List<dynamic> data = jsonDecode(jsonStr);
      for (var item in data) {
        final ptExample = (item['example_sentence_pt'] ?? '').toString().trim();
        final enExample = (item['example_sentence_en'] ?? '').toString().trim();
        final wordPt = (item['portuguese'] ?? '').toString().trim();
        final id = item['id']?.toString() ?? ptExample.hashCode.toString();

        if (ptExample.isNotEmpty && enExample.isNotEmpty) {
          list.add(
            LanguageItem(
              id: 'example_$id',
              portuguese: ptExample,
              english: enExample,
              wordType: 'example_sentence',
              topicCategory: item['topic_category']?.toString() ?? 'Example Sentences',
              notes: wordPt.isNotEmpty ? 'Exemplo: $wordPt' : 'Frase de Exemplo',
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error loading example sentences from vocabulary.json', name: 'ListenRepeatContent', error: e);
    }
    return list;
  }

  /// Loads curated preposition sentences, essential article/demonstrative contractions,
  /// spatial/temporal locatives, and prepositional pronouns.
  Future<List<LanguageItem>> _loadPrepositions() async {
    final list = <LanguageItem>[];
    try {
      final jsonStr = await rootBundle.loadString('assets/data/prepositions.json');
      final List<dynamic> data = jsonDecode(jsonStr);
      for (final item in data) {
        final id = (item['id'] ?? 'prep_${list.length}').toString();
        final pt = (item['portuguese'] ?? '').toString().trim();
        final en = (item['english'] ?? '').toString().trim();
        final cat = (item['category'] ?? 'preposition').toString();
        final usage = (item['usage'] ?? '').toString();

        String badge = 'Preposição';
        if (cat == 'preposition_transport') {
          badge = 'Preposição • Transporte';
        } else if (usage.contains('hours')) {
          badge = 'Preposição • Horas';
        } else if (usage.contains('routines')) {
          badge = 'Preposição • Rotinas (à)';
        } else if (usage.contains('specific actions')) {
          badge = 'Preposição • Data Específica (no/na)';
        } else if (usage.contains('parts of day')) {
          badge = 'Preposição • Parte do Dia';
        } else if (usage.contains('seasons')) {
          badge = 'Preposição • Estações';
        } else if (cat.contains('para')) {
          badge = 'Preposição • Para';
        } else if (cat.contains('de')) {
          badge = 'Preposição • De';
        } else if (cat.contains('em')) {
          badge = 'Preposição • Em';
        } else if (cat.contains('a')) {
          badge = 'Preposição • A';
        }

        if (pt.isNotEmpty && en.isNotEmpty) {
          list.add(LanguageItem(
            id: id,
            portuguese: pt,
            english: en,
            wordType: 'preposition_sentence',
            topicCategory: 'Preposições',
            notes: badge,
          ));
        }
      }
    } catch (e) {
      AppLogger.error('Error loading prepositions.json', name: 'ListenRepeatContent', error: e);
    }

    // --- 1. Essential Article & Demonstrative Contractions ---
    final contractions = [
      ('do', 'of the / from the (masc.)', 'Contração • de + o = do'),
      ('da', 'of the / from the (fem.)', 'Contração • de + a = da'),
      ('dos', 'of the / from the (masc. pl.)', 'Contração • de + os = dos'),
      ('das', 'of the / from the (fem. pl.)', 'Contração • de + as = das'),
      ('no', 'in the / on the / at the (masc.)', 'Contração • em + o = no'),
      ('na', 'in the / on the / at the (fem.)', 'Contração • em + a = na'),
      ('nos', 'in the / on the / at the (masc. pl.)', 'Contração • em + os = nos'),
      ('nas', 'in the / on the / at the (fem. pl.)', 'Contração • em + as = nas'),
      ('ao', 'to the / at the (masc.)', 'Contração • a + o = ao'),
      ('à', 'to the / at the (fem.)', 'Contração • a + a = à'),
      ('aos', 'to the / at the (masc. pl.)', 'Contração • a + os = aos'),
      ('às', 'to the / at the (fem. pl.)', 'Contração • a + as = às'),
      ('pelo', 'by the / through the (masc.)', 'Contração • por + o = pelo'),
      ('pela', 'by the / through the (fem.)', 'Contração • por + a = pela'),
      ('pelos', 'by the / through the (masc. pl.)', 'Contração • por + os = pelos'),
      ('pelas', 'by the / through the (fem. pl.)', 'Contração • por + as = pelas'),
      ('neste', 'in this (masc.)', 'Contração • em + este = neste'),
      ('nesta', 'in this (fem.)', 'Contração • em + esta = nesta'),
      ('nesse', 'in that (masc.)', 'Contração • em + esse = nesse'),
      ('nessa', 'in that (fem.)', 'Contração • em + essa = nessa'),
      ('naquele', 'in that over there (masc.)', 'Contração • em + aquele = naquele'),
      ('naquela', 'in that over there (fem.)', 'Contração • em + aquela = naquela'),
      ('deste', 'of this / from this (masc.)', 'Contração • de + este = deste'),
      ('desta', 'of this / from this (fem.)', 'Contração • de + esta = desta'),
      ('desse', 'of that / from that (masc.)', 'Contração • de + esse = desse'),
      ('dessa', 'of that / from that (fem.)', 'Contração • de + essa = dessa'),
      ('daquele', 'of that over there (masc.)', 'Contração • de + aquele = daquele'),
      ('daquela', 'of that over there (fem.)', 'Contração • de + aquela = daquela'),
    ];

    for (int i = 0; i < contractions.length; i++) {
      final c = contractions[i];
      list.add(LanguageItem(
        id: 'prep_contraction_$i',
        portuguese: c.$1,
        english: c.$2,
        wordType: 'preposition_contraction',
        topicCategory: 'Contrações',
        notes: c.$3,
      ));
    }

    // --- 2. Spatial Prepositions & Locatives ---
    final locatives = [
      ('perto de', 'near / close to', 'Preposição Espacial • proximidade'),
      ('longe de', 'far from', 'Preposição Espacial • distância'),
      ('ao lado de', 'next to / beside', 'Preposição Espacial • adjacente'),
      ('em cima de', 'on top of / above', 'Preposição Espacial • superior'),
      ('debaixo de', 'under / underneath', 'Preposição Espacial • inferior'),
      ('à frente de', 'in front of', 'Preposição Espacial • anterior'),
      ('atrás de', 'behind', 'Preposição Espacial • posterior'),
      ('dentro de', 'inside / in', 'Preposição Espacial • interior'),
      ('fora de', 'outside', 'Preposição Espacial • exterior'),
      ('entre', 'between / among', 'Preposição Espacial • intermédio'),
      ('antes de', 'before', 'Preposição Temporal • anterior'),
      ('depois de', 'after', 'Preposição Temporal • posterior'),
    ];

    for (int i = 0; i < locatives.length; i++) {
      final loc = locatives[i];
      list.add(LanguageItem(
        id: 'prep_locative_$i',
        portuguese: loc.$1,
        english: loc.$2,
        wordType: 'preposition_spatial',
        topicCategory: 'Locativas',
        notes: loc.$3,
      ));
    }

    // --- 3. Prepositional Pronouns ---
    final prepPronouns = [
      ('comigo', 'with me', 'Pronome Preposicional • eu'),
      ('contigo', 'with you (informal)', 'Pronome Preposicional • tu'),
      ('consigo', 'with you (formal) / with himself', 'Pronome Preposicional • você'),
      ('connosco', 'with us', 'Pronome Preposicional • nós'),
      ('dele', 'of him / his', 'Pronome Preposicional • de + ele'),
      ('dela', 'of her / hers', 'Pronome Preposicional • de + ela'),
      ('deles', 'of them (masc.) / their', 'Pronome Preposicional • de + eles'),
      ('delas', 'of them (fem.) / their', 'Pronome Preposicional • de + elas'),
      ('nele', 'in him / in it (masc.)', 'Pronome Preposicional • em + ele'),
      ('nela', 'in her / in it (fem.)', 'Pronome Preposicional • em + ela'),
      ('neles', 'in them (masc.)', 'Pronome Preposicional • em + eles'),
      ('nelas', 'in them (fem.)', 'Pronome Preposicional • em + elas'),
    ];

    for (int i = 0; i < prepPronouns.length; i++) {
      final p = prepPronouns[i];
      list.add(LanguageItem(
        id: 'prep_pronoun_$i',
        portuguese: p.$1,
        english: p.$2,
        wordType: 'preposition_pronoun',
        topicCategory: 'Pronomes Preposicionais',
        notes: p.$3,
      ));
    }

    return list;
  }

  /// Generates verb conjugations in:
  /// 1. Present Tense (Presente do Indicativo)
  /// 2. Past Tense (Pretérito Perfeito)
  /// 3. Future Tense (Periphrastic: ir + infinitivo)
  Future<List<LanguageItem>> _generateConjugationItems() async {
    final list = <LanguageItem>[];
    try {
      final verbs = await _verbService.loadVerbs();

      for (final verb in verbs) {
        final inf = verb.infinitive.trim();
        final trans = verb.translation.trim();
        if (inf.isEmpty) continue;

        // --- 1. Present Tense (Presente) ---
        final pres = verb.conjugations;
        if (pres.isNotEmpty) {
          if (pres['eu']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_pres_${inf}_eu',
              portuguese: 'Eu ${pres['eu']!}',
              english: 'I ${_translatePresent(trans, 'I')}',
              wordType: 'conjugation_present',
              topicCategory: 'Presente: $inf',
              notes: 'Presente • eu',
            ));
          }
          if (pres['tu']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_pres_${inf}_tu',
              portuguese: 'Tu ${pres['tu']!}',
              english: 'You ${_translatePresent(trans, 'you')}',
              wordType: 'conjugation_present',
              topicCategory: 'Presente: $inf',
              notes: 'Presente • tu',
            ));
          }
          if (pres['você, ela, ele']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_pres_${inf}_ele',
              portuguese: 'Ele ${pres['você, ela, ele']!}',
              english: 'He ${_translatePresent(trans, 'he')}',
              wordType: 'conjugation_present',
              topicCategory: 'Presente: $inf',
              notes: 'Presente • ele/ela',
            ));
          }
          if (pres['nós']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_pres_${inf}_nos',
              portuguese: 'Nós ${pres['nós']!}',
              english: 'We ${_translatePresent(trans, 'we')}',
              wordType: 'conjugation_present',
              topicCategory: 'Presente: $inf',
              notes: 'Presente • nós',
            ));
          }
          if (pres['vocês, elas, eles']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_pres_${inf}_eles',
              portuguese: 'Eles ${pres['vocês, elas, eles']!}',
              english: 'They ${_translatePresent(trans, 'they')}',
              wordType: 'conjugation_present',
              topicCategory: 'Presente: $inf',
              notes: 'Presente • eles/elas',
            ));
          }
        }

        // --- 2. Past Tense (Pretérito Perfeito) ---
        final past = verb.pastConjugations ??
            _irregularPastConjugations[inf.toLowerCase()] ??
            _deriveRegularPast(inf);
        if (past != null && past.isNotEmpty) {
          if (past['eu']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_past_${inf}_eu',
              portuguese: 'Eu ${past['eu']!}',
              english: 'I ${_translatePast(trans)}',
              wordType: 'conjugation_past',
              topicCategory: 'Passado: $inf',
              notes: 'Pretérito Perfeito • eu',
            ));
          }
          if (past['você, ela, ele']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_past_${inf}_ele',
              portuguese: 'Ela ${past['você, ela, ele']!}',
              english: 'She ${_translatePast(trans)}',
              wordType: 'conjugation_past',
              topicCategory: 'Passado: $inf',
              notes: 'Pretérito Perfeito • ele/ela',
            ));
          }
          if (past['nós']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_past_${inf}_nos',
              portuguese: 'Nós ${past['nós']!}',
              english: 'We ${_translatePast(trans)}',
              wordType: 'conjugation_past',
              topicCategory: 'Passado: $inf',
              notes: 'Pretérito Perfeito • nós',
            ));
          }
          if (past['vocês, elas, eles']?.isNotEmpty == true) {
            list.add(LanguageItem(
              id: 'conj_past_${inf}_eles',
              portuguese: 'Eles ${past['vocês, elas, eles']!}',
              english: 'They ${_translatePast(trans)}',
              wordType: 'conjugation_past',
              topicCategory: 'Passado: $inf',
              notes: 'Pretérito Perfeito • eles/elas',
            ));
          }
        }

        // --- 3. Future Tense (Periphrastic: ir + infinitivo) ---
        // Most common future tense in spoken European Portuguese
        final cleanTrans = _cleanEnglishVerb(trans);
        list.add(LanguageItem(
          id: 'conj_fut_${inf}_eu',
          portuguese: 'Eu vou $inf',
          english: 'I am going to $cleanTrans',
          wordType: 'conjugation_future',
          topicCategory: 'Futuro: $inf',
          notes: 'Futuro (vou) • eu',
        ));
        list.add(LanguageItem(
          id: 'conj_fut_${inf}_ele',
          portuguese: 'Ele vai $inf',
          english: 'He is going to $cleanTrans',
          wordType: 'conjugation_future',
          topicCategory: 'Futuro: $inf',
          notes: 'Futuro (vai) • ele/ela',
        ));
        list.add(LanguageItem(
          id: 'conj_fut_${inf}_nos',
          portuguese: 'Nós vamos $inf',
          english: 'We are going to $cleanTrans',
          wordType: 'conjugation_future',
          topicCategory: 'Futuro: $inf',
          notes: 'Futuro (vamos) • nós',
        ));
      }
    } catch (e) {
      AppLogger.error('Error generating conjugation items', name: 'ListenRepeatContent', error: e);
    }

    return list;
  }

  /// Authentic European Portuguese Pretérito Perfeito for irregular verbs.
  static const Map<String, Map<String, String>> _irregularPastConjugations = {
    'dar': {
      'eu': 'dei',
      'tu': 'deste',
      'você, ela, ele': 'deu',
      'nós': 'demos',
      'vocês, elas, eles': 'deram',
    },
    'dizer': {
      'eu': 'disse',
      'tu': 'disseste',
      'você, ela, ele': 'disse',
      'nós': 'dissemos',
      'vocês, elas, eles': 'disseram',
    },
    'estar': {
      'eu': 'estive',
      'tu': 'estiveste',
      'você, ela, ele': 'esteve',
      'nós': 'estivemos',
      'vocês, elas, eles': 'estiveram',
    },
    'fazer': {
      'eu': 'fiz',
      'tu': 'fizeste',
      'você, ela, ele': 'fez',
      'nós': 'fizemos',
      'vocês, elas, eles': 'fizeram',
    },
    'haver': {
      'eu': 'houve',
      'tu': 'houveste',
      'você, ela, ele': 'houve',
      'nós': 'houvemos',
      'vocês, elas, eles': 'houveram',
    },
    'ir': {
      'eu': 'fui',
      'tu': 'foste',
      'você, ela, ele': 'foi',
      'nós': 'fomos',
      'vocês, elas, eles': 'foram',
    },
    'poder': {
      'eu': 'pude',
      'tu': 'pudeste',
      'você, ela, ele': 'pôde',
      'nós': 'pudemos',
      'vocês, elas, eles': 'puderam',
    },
    'pôr': {
      'eu': 'pus',
      'tu': 'puseste',
      'você, ela, ele': 'pôs',
      'nós': 'pusemos',
      'vocês, elas, eles': 'puseram',
    },
    'querer': {
      'eu': 'quis',
      'tu': 'quiseste',
      'você, ela, ele': 'quis',
      'nós': 'quisemos',
      'vocês, elas, eles': 'quiseram',
    },
    'saber': {
      'eu': 'soube',
      'tu': 'soubeste',
      'você, ela, ele': 'soube',
      'nós': 'soubemos',
      'vocês, elas, eles': 'souberam',
    },
    'ser': {
      'eu': 'fui',
      'tu': 'foste',
      'você, ela, ele': 'foi',
      'nós': 'fomos',
      'vocês, elas, eles': 'foram',
    },
    'ter': {
      'eu': 'tive',
      'tu': 'tiveste',
      'você, ela, ele': 'teve',
      'nós': 'tivemos',
      'vocês, elas, eles': 'tiveram',
    },
    'trazer': {
      'eu': 'trouxe',
      'tu': 'trouxeste',
      'você, ela, ele': 'trouxe',
      'nós': 'trouxemos',
      'vocês, elas, eles': 'trouxeram',
    },
    'ver': {
      'eu': 'vi',
      'tu': 'viste',
      'você, ela, ele': 'viu',
      'nós': 'vimos',
      'vocês, elas, eles': 'viram',
    },
    'vir': {
      'eu': 'vim',
      'tu': 'vieste',
      'você, ela, ele': 'veio',
      'nós': 'viemos',
      'vocês, elas, eles': 'vieram',
    },
    'cair': {
      'eu': 'caí',
      'tu': 'caíste',
      'você, ela, ele': 'caiu',
      'nós': 'caímos',
      'vocês, elas, eles': 'caíram',
    },
    'sair': {
      'eu': 'saí',
      'tu': 'saíste',
      'você, ela, ele': 'saiu',
      'nós': 'saímos',
      'vocês, elas, eles': 'saíram',
    },
  };

  /// Known irregular verbs that MUST NOT receive regular past endings.
  static const Set<String> _knownIrregularVerbs = {
    'dar', 'dizer', 'estar', 'fazer', 'haver', 'ir', 'poder', 'pôr',
    'querer', 'saber', 'ser', 'ter', 'trazer', 'ver', 'vir', 'cair', 'sair',
  };

  /// Derives regular European Portuguese Pretérito Perfeito conjugations
  /// for regular -ar, -er, and -ir verbs when explicit past is not in DB.
  /// Irregular verbs are blocked to prevent fabricating incorrect forms.
  Map<String, String>? _deriveRegularPast(String infinitive) {
    final lower = infinitive.toLowerCase().trim();
    if (_knownIrregularVerbs.contains(lower)) return null;
    if (lower.length < 3) return null;
    final stem = lower.substring(0, lower.length - 2);
    final ending = lower.substring(lower.length - 2);

    if (ending == 'ar') {
      return {
        'eu': '${stem}ei',
        'tu': '${stem}aste',
        'você, ela, ele': '${stem}ou',
        'nós': '$stem' 'ámos',
        'vocês, elas, eles': '${stem}aram',
      };
    } else if (ending == 'er') {
      return {
        'eu': '${stem}i',
        'tu': '${stem}este',
        'você, ela, ele': '${stem}eu',
        'nós': '${stem}emos',
        'vocês, elas, eles': '${stem}eram',
      };
    } else if (ending == 'ir') {
      return {
        'eu': '${stem}i',
        'tu': '${stem}iste',
        'você, ela, ele': '${stem}iu',
        'nós': '${stem}imos',
        'vocês, elas, eles': '${stem}iram',
      };
    }
    return null;
  }

  /// Cleans English translation definitions: extracts the primary meaning
  /// before slashes, strips parentheticals, and removes leading 'to '.
  String _cleanEnglishVerb(String fullTranslation) {
    String cleaned = fullTranslation.replaceAll(RegExp(r'\([^)]*\)'), '').trim();
    if (cleaned.contains('/')) {
      cleaned = cleaned.split('/').first.trim();
    }
    cleaned = cleaned.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '').trim();
    return cleaned.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _translatePresent(String fullTranslation, String subject) {
    final cleaned = _cleanEnglishVerb(fullTranslation);
    final parts = cleaned.split(' ');
    String head = parts.first;
    final tail = parts.length > 1 ? ' ${parts.sublist(1).join(' ')}' : '';

    if (subject.toLowerCase() == 'he' || subject.toLowerCase() == 'she') {
      if (head.endsWith('ch') || head.endsWith('sh') || head.endsWith('ss') || head.endsWith('x') || head.endsWith('o')) {
        head = '${head}es';
      } else if (head.endsWith('y') && !RegExp(r'[aeiou]y$').hasMatch(head)) {
        head = '${head.substring(0, head.length - 1)}ies';
      } else if (head == 'have') {
        head = 'has';
      } else {
        head = '${head}s';
      }
    }
    return '$head$tail';
  }

  String _translatePast(String fullTranslation) {
    final cleaned = _cleanEnglishVerb(fullTranslation);
    final parts = cleaned.split(' ');
    final head = parts.first.toLowerCase();
    final tail = parts.length > 1 ? ' ${parts.sublist(1).join(' ')}' : '';

    String pastHead;
    if (_irregularEnglishPast.containsKey(head)) {
      pastHead = _irregularEnglishPast[head]!;
    } else if (head.endsWith('e')) {
      pastHead = '${head}d';
    } else if (head.endsWith('y') && !RegExp(r'[aeiou]y$').hasMatch(head)) {
      pastHead = '${head.substring(0, head.length - 1)}ied';
    } else {
      pastHead = '${head}ed';
    }
    return '$pastHead$tail';
  }

  static const Map<String, String> _irregularEnglishPast = {
    'be': 'was/were',
    'beat': 'beat',
    'become': 'became',
    'begin': 'began',
    'believe': 'believed',
    'bring': 'brought',
    'build': 'built',
    'buy': 'bought',
    'can': 'could',
    'catch': 'caught',
    'choose': 'chose',
    'come': 'came',
    'cost': 'cost',
    'cut': 'cut',
    'do': 'did',
    'draw': 'drew',
    'drink': 'drank',
    'drive': 'drove',
    'eat': 'ate',
    'fall': 'fell',
    'feel': 'felt',
    'fight': 'fought',
    'find': 'found',
    'fly': 'flew',
    'forget': 'forgot',
    'get': 'got',
    'give': 'gave',
    'go': 'went',
    'grow': 'grew',
    'hang': 'hung',
    'have': 'had',
    'hear': 'heard',
    'hide': 'hid',
    'hit': 'hit',
    'hold': 'held',
    'hurt': 'hurt',
    'keep': 'kept',
    'know': 'knew',
    'lay': 'laid',
    'lead': 'led',
    'leave': 'left',
    'lend': 'lent',
    'let': 'let',
    'lie': 'lied',
    'lose': 'lost',
    'make': 'made',
    'mean': 'meant',
    'meet': 'met',
    'must': 'had to',
    'pay': 'paid',
    'put': 'put',
    'read': 'read',
    'ride': 'rode',
    'ring': 'rang',
    'rise': 'rose',
    'run': 'ran',
    'say': 'said',
    'see': 'saw',
    'sell': 'sold',
    'send': 'sent',
    'set': 'set',
    'shake': 'shook',
    'shine': 'shone',
    'shoot': 'shot',
    'show': 'showed',
    'shut': 'shut',
    'sing': 'sang',
    'sink': 'sank',
    'sit': 'sat',
    'sleep': 'slept',
    'slide': 'slid',
    'speak': 'spoke',
    'spend': 'spent',
    'stand': 'stood',
    'steal': 'stole',
    'stick': 'stuck',
    'strike': 'struck',
    'swear': 'swore',
    'sweep': 'swept',
    'swim': 'swam',
    'swing': 'swung',
    'take': 'took',
    'teach': 'taught',
    'tear': 'tore',
    'tell': 'told',
    'think': 'thought',
    'throw': 'threw',
    'understand': 'understood',
    'wake': 'woke',
    'wear': 'wore',
    'win': 'won',
    'write': 'wrote',
  };
}
