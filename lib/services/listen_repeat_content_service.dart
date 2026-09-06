import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../models/language_item.dart';
import '../utils/logger.dart';
import 'storage_service.dart';
import 'verb_service.dart';

enum ListenRepeatMode {
  all,
  verbs,
  phrases,
  vocabulary,
}

extension ListenRepeatModeExtension on ListenRepeatMode {
  String get label {
    switch (this) {
      case ListenRepeatMode.all:
        return 'Balanced Mix';
      case ListenRepeatMode.verbs:
        return 'Verbs & Tenses';
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
      case ListenRepeatMode.verbs:
        return 'Verbs';
      case ListenRepeatMode.phrases:
        return 'Phrases';
      case ListenRepeatMode.vocabulary:
        return 'Vocab';
    }
  }
}

final listenRepeatContentServiceProvider = Provider<ListenRepeatContentService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final verbService = ref.watch(verbServiceProvider);
  return ListenRepeatContentService(storage, verbService);
});

class ListenRepeatContentService {
  final StorageService _storageService;
  final VerbService _verbService;

  List<LanguageItem>? _cachedPhrases;
  List<LanguageItem>? _cachedVerbPhrases;
  List<LanguageItem>? _cachedExampleSentences;
  List<LanguageItem>? _cachedConjugations;

  ListenRepeatContentService(this._storageService, this._verbService);

  Future<List<LanguageItem>> loadContent({ListenRepeatMode mode = ListenRepeatMode.all}) async {
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

    AppLogger.log(
      'Loaded auxiliary pools: ${phrases.length} phrases, ${verbPhrases.length} verb phrases, '
      '${exampleSentences.length} examples, ${conjugations.length} conjugations, ${vocabItems.length} vocab',
      name: 'ListenRepeatContent',
    );

    switch (mode) {
      case ListenRepeatMode.verbs:
        final list = <LanguageItem>[];
        list.addAll(conjugations);
        list.addAll(verbPhrases);
        // Include verb infinitives from vocab
        list.addAll(vocabItems.where((i) => i.id.startsWith('verb_') || i.wordType == 'verb'));
        list.shuffle();
        return list;

      case ListenRepeatMode.phrases:
        final list = <LanguageItem>[];
        list.addAll(phrases);
        list.addAll(verbPhrases);
        list.addAll(exampleSentences);
        list.shuffle();
        return list;

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
  }) {
    final allPhrases = [...phrases, ...verbPhrases, ...exampleSentences]..shuffle();
    final allConjugations = [...conjugations]..shuffle();
    final pureVocab = vocabItems.where((i) => !i.id.startsWith('verb_')).toList()..shuffle();

    final result = <LanguageItem>[];
    int vocabIndex = 0;
    int phraseIndex = 0;
    int conjIndex = 0;

    final totalTarget = pureVocab.length + allPhrases.length + allConjugations.length;
    if (totalTarget == 0) return [];

    // Interleave pattern: 2 Vocab -> 1 Conjugation (Pres/Past/Fut) -> 1 Phrase/Sentence
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

      // 3. Add 1 conversational phrase or contextual sentence
      if (phraseIndex < allPhrases.length) {
        result.add(allPhrases[phraseIndex++]);
        addedAny = true;
      }

      if (!addedAny) break;
    }

    return result;
  }

  Future<void> _ensureAuxiliaryDataLoaded() async {
    _cachedPhrases ??= await _loadPhrases();
    _cachedVerbPhrases ??= await _loadVerbPhrases();
    _cachedExampleSentences ??= await _loadExampleSentences();
    _cachedConjugations ??= await _generateConjugationItems();
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
        if (pt.isNotEmpty && en.isNotEmpty) {
          list.add(
            LanguageItem(
              id: 'phrase_$i',
              portuguese: pt,
              english: en,
              wordType: 'phrase',
              topicCategory: 'Conversational Phrases',
              notes: 'Frase Útil',
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
        if (pt.isNotEmpty && en.isNotEmpty) {
          list.add(
            LanguageItem(
              id: 'verb_phrase_${verb}_$i',
              portuguese: pt,
              english: en,
              wordType: 'verb_phrase',
              topicCategory: 'Verbs in Context',
              notes: verb.isNotEmpty ? 'Verbo em Contexto: $verb' : 'Verbo em Contexto',
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
        final past = verb.pastConjugations ?? _deriveRegularPast(inf);
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
        final cleanTrans = trans.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '');
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

  /// Derives regular European Portuguese Pretérito Perfeito conjugations
  /// for regular -ar, -er, and -ir verbs when explicit past is not in DB.
  Map<String, String>? _deriveRegularPast(String infinitive) {
    if (infinitive.length < 3) return null;
    final stem = infinitive.substring(0, infinitive.length - 2);
    final ending = infinitive.substring(infinitive.length - 2).toLowerCase();

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

  String _translatePresent(String fullTranslation, String subject) {
    String verb = fullTranslation.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '').trim();
    // Keep first definition if multiple (e.g. "think / find" -> "think")
    if (verb.contains('/')) {
      verb = verb.split('/').first.trim();
    }
    if (subject.toLowerCase() == 'he' || subject.toLowerCase() == 'she') {
      if (verb.endsWith('ch') || verb.endsWith('sh') || verb.endsWith('ss') || verb.endsWith('x') || verb.endsWith('o')) {
        return '${verb}es';
      } else if (verb.endsWith('y') && !RegExp(r'[aeiou]y$').hasMatch(verb)) {
        return '${verb.substring(0, verb.length - 1)}ies';
      } else if (verb == 'have') {
        return 'has';
      } else {
        return '${verb}s';
      }
    }
    return verb;
  }

  String _translatePast(String fullTranslation) {
    String verb = fullTranslation.replaceFirst(RegExp(r'^to\s+', caseSensitive: false), '').trim();
    if (verb.contains('/')) {
      verb = verb.split('/').first.trim();
    }
    // Handle irregular English past tenses for common verbs
    const irregulars = {
      'be': 'was/were',
      'have': 'had',
      'do': 'did',
      'say': 'said',
      'go': 'went',
      'get': 'got',
      'make': 'made',
      'know': 'knew',
      'think': 'thought',
      'take': 'took',
      'see': 'saw',
      'come': 'came',
      'find': 'found',
      'give': 'gave',
      'tell': 'told',
      'feel': 'felt',
      'become': 'became',
      'leave': 'left',
      'put': 'put',
      'mean': 'meant',
      'keep': 'kept',
      'let': 'let',
      'begin': 'began',
      'seem': 'seemed',
      'help': 'helped',
      'talk': 'talked',
      'turn': 'turned',
      'start': 'started',
      'show': 'showed',
      'hear': 'heard',
      'play': 'played',
      'run': 'ran',
      'move': 'moved',
      'like': 'liked',
      'live': 'lived',
      'believe': 'believed',
      'hold': 'held',
      'bring': 'brought',
      'happen': 'happened',
      'write': 'wrote',
      'provide': 'provided',
      'sit': 'sat',
      'stand': 'stood',
      'lose': 'lost',
      'pay': 'paid',
      'meet': 'met',
      'include': 'included',
      'continue': 'continued',
      'set': 'set',
      'learn': 'learned',
      'change': 'changed',
      'lead': 'led',
      'understand': 'understood',
      'watch': 'watched',
      'follow': 'followed',
      'stop': 'stopped',
      'create': 'created',
      'speak': 'spoke',
      'read': 'read',
      'spend': 'spent',
      'grow': 'grew',
      'open': 'opened',
      'walk': 'walked',
      'win': 'won',
      'teach': 'taught',
      'buy': 'bought',
      'wait': 'waited',
      'serve': 'served',
      'die': 'died',
      'send': 'sent',
      'expect': 'expected',
      'build': 'built',
      'stay': 'stayed',
      'fall': 'fell',
      'cut': 'cut',
      'reach': 'reached',
      'kill': 'killed',
      'remain': 'remained',
      'eat': 'ate',
      'drink': 'drank',
      'sleep': 'slept',
    };

    if (irregulars.containsKey(verb.toLowerCase())) {
      return irregulars[verb.toLowerCase()]!;
    }

    if (verb.endsWith('e')) {
      return '${verb}d';
    } else if (verb.endsWith('y') && !RegExp(r'[aeiou]y$').hasMatch(verb)) {
      return '${verb.substring(0, verb.length - 1)}ied';
    } else {
      return '${verb}ed';
    }
  }
}
