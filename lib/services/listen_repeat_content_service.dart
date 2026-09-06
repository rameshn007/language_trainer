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
