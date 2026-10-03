import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/verb.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/verb_service.dart';
import 'package:language_trainer/utils/tts_text_sanitizer.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}
class _MockVerbService extends Mock implements VerbService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsTextSanitizer', () {
    test('sanitizes Portuguese text removing markdown escapes and grammar tags', () {
      expect(TtsTextSanitizer.sanitizePt(r'cá/lá'), equals('cá ou lá'));
      expect(TtsTextSanitizer.sanitizePt(r'livro (m.)'), equals('livro'));
      expect(TtsTextSanitizer.sanitizePt(r'comida (f.)'), equals('comida'));
      expect(TtsTextSanitizer.sanitizePt(r'palavras \[nome\]'), equals('palavras'));
      expect(TtsTextSanitizer.sanitizePt(r'há \- dois anos'), equals('há - dois anos'));
    });

    test('sanitizes English text removing parentheticals and markdown escapes', () {
      expect(
        TtsTextSanitizer.sanitizeEn(r'for \- indicates a period of time (total amount, month, week etc)'),
        equals('for, indicates a period of time'),
      );
      expect(
        TtsTextSanitizer.sanitizeEn(r'inheritors (receive inheritance)'),
        equals('inheritors'),
      );
      expect(
        TtsTextSanitizer.sanitizeEn(r'here/there'),
        equals('here or there'),
      );
    });
  });

  group('ListenRepeatModeExtension', () {
    test('provides distinct labels, badges, and descriptions for all modes', () {
      for (final mode in ListenRepeatMode.values) {
        expect(mode.label, isNotEmpty);
        expect(mode.badge, isNotEmpty);
        expect(mode.description, isNotEmpty);
      }
      expect(ListenRepeatMode.prepositions.badge, equals('Prepositions'));
      expect(ListenRepeatMode.topics.badge, equals('Topics'));
      expect(ListenRepeatMode.all.description, contains('Mix'));
      expect(ListenRepeatMode.topics.description, contains('House'));
      expect(ListenRepeatMode.verbs.description, contains('Conjugations'));
      expect(ListenRepeatMode.prepositions.description, contains('Prepositions'));
      expect(ListenRepeatMode.phrases.description, contains('Everyday phrases'));
      expect(ListenRepeatMode.vocabulary.description, contains('Essential words'));
    });
  });

  group('ListenRepeatContentService', () {
    late _MockStorageService storage;
    late _MockVerbService verbService;
    late ListenRepeatContentService contentService;

    setUp(() {
      storage = _MockStorageService();
      verbService = _MockVerbService();
      contentService = ListenRepeatContentService(storage, verbService);
    });

    test('generates verb conjugations in Present, Past, and Future tenses', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'vocab_1', portuguese: 'mesa', english: 'table'),
        LanguageItem(id: 'vocab_2', portuguese: 'cadeira', english: 'chair'),
      ]);

      when(() => verbService.loadVerbs()).thenAnswer((_) async => [
        Verb(
          infinitive: 'falar',
          translation: 'to speak',
          conjugations: {
            'eu': 'falo',
            'tu': 'falas',
            'você, ela, ele': 'fala',
            'nós': 'falamos',
            'vocês, elas, eles': 'falam',
          },
          pastConjugations: {
            'eu': 'falei',
            'tu': 'falaste',
            'você, ela, ele': 'falou',
            'nós': 'falámos',
            'vocês, elas, eles': 'falaram',
          },
        ),
      ]);

      final items = await contentService.loadContent(mode: ListenRepeatMode.verbs);

      expect(items, isNotEmpty);
      // Verify present conjugation
      final presEu = items.firstWhere((i) => i.id == 'conj_pres_falar_eu');
      expect(presEu.portuguese, equals('Eu falo'));
      expect(presEu.english, equals('I speak'));
      expect(presEu.notes, contains('Presente'));

      // Verify past conjugation
      final pastEu = items.firstWhere((i) => i.id == 'conj_past_falar_eu');
      expect(pastEu.portuguese, equals('Eu falei'));
      expect(pastEu.english, equals('I spoke'));
      expect(pastEu.notes, contains('Pretérito Perfeito'));

      // Verify future conjugation
      final futEu = items.firstWhere((i) => i.id == 'conj_fut_falar_eu');
      expect(futEu.portuguese, equals('Eu vou falar'));
      expect(futEu.english, equals('I am going to speak'));
      expect(futEu.notes, contains('Futuro'));
    });

    test('interleaves balanced content in ListenRepeatMode.all', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'sol', english: 'sun'),
        LanguageItem(id: 'v2', portuguese: 'lua', english: 'moon'),
        LanguageItem(id: 'v3', portuguese: 'mar', english: 'sea'),
      ]);

      when(() => verbService.loadVerbs()).thenAnswer((_) async => [
        Verb(
          infinitive: 'abrir',
          translation: 'to open',
          conjugations: {'eu': 'abro'},
        ),
      ]);

      final pool = await contentService.loadContent(mode: ListenRepeatMode.all);
      expect(pool, isNotEmpty);
      expect(pool.any((i) => i.id.startsWith('conj_')), isTrue);
      expect(pool.any((i) => i.id.startsWith('v')), isTrue);
    });

    test('filters core vocabulary only in ListenRepeatMode.vocabulary', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'casa', english: 'house'),
        LanguageItem(id: 'verb_comer', portuguese: 'comer', english: 'to eat'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => []);

      final pool = await contentService.loadContent(mode: ListenRepeatMode.vocabulary);
      expect(pool.length, equals(1));
      expect(pool.first.portuguese, equals('casa'));
    });

    test('provides authentic past conjugations for irregular verbs lacking explicit past data', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'ola', english: 'hello'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => [
        Verb(infinitive: 'dar', translation: 'to give', conjugations: {'eu': 'dou'}),
        Verb(infinitive: 'poder', translation: 'can / to be able', conjugations: {'eu': 'posso'}),
        Verb(infinitive: 'querer', translation: 'to want', conjugations: {'eu': 'quero'}),
        Verb(infinitive: 'saber', translation: 'to know', conjugations: {'eu': 'sei'}),
        Verb(infinitive: 'trazer', translation: 'to bring', conjugations: {'eu': 'trago'}),
        Verb(infinitive: 'vir', translation: 'to come', conjugations: {'eu': 'venho'}),
      ]);

      final items = await contentService.loadContent(mode: ListenRepeatMode.verbs);

      // Verify authentic irregular forms are used (not fabricated regular forms like "queri", "sabeu", "dou")
      final darEu = items.firstWhere((i) => i.id == 'conj_past_dar_eu');
      expect(darEu.portuguese, equals('Eu dei'));
      expect(darEu.english, equals('I gave'));

      final poderEla = items.firstWhere((i) => i.id == 'conj_past_poder_ele');
      expect(poderEla.portuguese, equals('Ela pôde'));
      expect(poderEla.english, equals('She could'));

      final quererEu = items.firstWhere((i) => i.id == 'conj_past_querer_eu');
      expect(quererEu.portuguese, equals('Eu quis'));
      expect(quererEu.english, equals('I wanted'));

      final saberEu = items.firstWhere((i) => i.id == 'conj_past_saber_eu');
      expect(saberEu.portuguese, equals('Eu soube'));
      expect(saberEu.english, equals('I knew'));

      final trazerEu = items.firstWhere((i) => i.id == 'conj_past_trazer_eu');
      expect(trazerEu.portuguese, equals('Eu trouxe'));
      expect(trazerEu.english, equals('I brought'));

      final virEla = items.firstWhere((i) => i.id == 'conj_past_vir_ele');
      expect(virEla.portuguese, equals('Ela veio'));
      expect(virEla.english, equals('She came'));
    });

    test('properly translates phrasal verbs and irregular English verbs in past and present', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'ola', english: 'hello'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => [
        Verb(
          infinitive: 'ligar',
          translation: 'to turn on (light) / to light',
          conjugations: {'eu': 'ligo', 'você, ela, ele': 'liga'},
          pastConjugations: {'eu': 'liguei', 'você, ela, ele': 'ligou'},
        ),
        Verb(
          infinitive: 'bater',
          translation: 'to hit / to beat',
          conjugations: {'eu': 'bato', 'você, ela, ele': 'bate'},
          pastConjugations: {'eu': 'bati', 'você, ela, ele': 'bateu'},
        ),
      ]);

      final items = await contentService.loadContent(mode: ListenRepeatMode.verbs);

      // Phrasal verb: "turn on (light) / to light" -> "turns on" / "turned on"
      final ligarPresEle = items.firstWhere((i) => i.id == 'conj_pres_ligar_ele');
      expect(ligarPresEle.english, equals('He turns on'));

      final ligarPastEu = items.firstWhere((i) => i.id == 'conj_past_ligar_eu');
      expect(ligarPastEu.english, equals('I turned on'));

      // Irregular English verb: "hit / beat" -> "hit" (not "hited")
      final baterPastEu = items.firstWhere((i) => i.id == 'conj_past_bater_eu');
      expect(baterPastEu.english, equals('I hit'));

      final baterPresEle = items.firstWhere((i) => i.id == 'conj_pres_bater_ele');
      expect(baterPresEle.english, equals('He hits'));
    });

    test('loads prepositions, contractions, and locatives in ListenRepeatMode.prepositions', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'ola', english: 'hello'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => []);

      final items = await contentService.loadContent(mode: ListenRepeatMode.prepositions);

      expect(items, isNotEmpty);
      expect(items.length, greaterThanOrEqualTo(100));

      // Preposition sentence from prepositions.json
      final prepSentence = items.firstWhere((i) => i.id.startsWith('prep_00'));
      expect(prepSentence.notes, contains('Preposição'));

      // Article contraction
      final naContraction = items.firstWhere((i) => i.portuguese == 'na');
      expect(naContraction.english, contains('in the / on the / at the'));
      expect(naContraction.notes, contains('em + a = na'));

      // Spatial locative
      final pertoDe = items.firstWhere((i) => i.portuguese == 'perto de');
      expect(pertoDe.english, contains('near'));
      expect(pertoDe.notes, contains('Espacial'));

      // Prepositional pronoun
      final connosco = items.firstWhere((i) => i.portuguese == 'connosco');
      expect(connosco.english, equals('with us'));
      expect(connosco.notes, contains('Pronome Preposicional'));
    });

    test('interleaves prepositions in ListenRepeatMode.all', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'sol', english: 'sun'),
        LanguageItem(id: 'v2', portuguese: 'lua', english: 'moon'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => [
        Verb(
          infinitive: 'abrir',
          translation: 'to open',
          conjugations: {'eu': 'abro'},
        ),
      ]);

      final pool = await contentService.loadContent(mode: ListenRepeatMode.all);
      expect(pool, isNotEmpty);
      // Contains preposition items
      expect(pool.any((i) => i.id.startsWith('prep_')), isTrue);
      // Contains verb conjugation
      expect(pool.any((i) => i.id.startsWith('conj_')), isTrue);
      // Contains core vocab
      expect(pool.any((i) => i.id == 'v1' || i.id == 'v2'), isTrue);
    });

    test('deduplicates phrases across pools in ListenRepeatMode.all', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'sol', english: 'sun'),
        LanguageItem(id: 'v2', portuguese: 'Bom dia!', english: 'Good morning!'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => []);

      final pool = await contentService.loadContent(mode: ListenRepeatMode.all);
      // 'v2' is filtered out from pureVocab so 'Bom dia!' only appears once from the phrase pool
      final bomDiaCount = pool.where((i) => i.portuguese.trim().toLowerCase() == 'bom dia!').length;
      expect(bomDiaCount, equals(1));
    });

    test('loads and filters topic items in ListenRepeatMode.topics', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(
          id: 'vocab_quarto',
          portuguese: 'quarto',
          english: 'bedroom',
          topicCategory: 'House & Rooms',
          notes: 'A Casa: Quarto',
        ),
        LanguageItem(
          id: 'vocab_telemovel',
          portuguese: 'telemóvel',
          english: 'mobile phone',
          topicCategory: 'Everyday Items',
          notes: 'Quotidiano: Telemóvel',
        ),
        LanguageItem(
          id: 'vocab_sol',
          portuguese: 'sol',
          english: 'sun',
          topicCategory: 'Nature',
        ),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => []);

      // 1. All topics
      final allTopicsPool = await contentService.loadContent(mode: ListenRepeatMode.topics);
      expect(allTopicsPool, isNotEmpty);
      expect(allTopicsPool.any((i) => i.id == 'vocab_sol'), isFalse);
      expect(allTopicsPool.any((i) => i.id == 'vocab_quarto'), isTrue);
      expect(allTopicsPool.any((i) => i.id == 'vocab_telemovel'), isTrue);

      // 2. Filtered by subCategory: House & Rooms
      final housePool = await contentService.loadContent(
        mode: ListenRepeatMode.topics,
        subCategory: 'House & Rooms',
      );
      expect(housePool, isNotEmpty);
      expect(housePool.any((i) => i.id == 'vocab_quarto'), isTrue);
      expect(housePool.any((i) => i.id == 'vocab_telemovel'), isFalse);
    });

    test('biases newly added topic phrases into early rotation in ListenRepeatMode.phrases', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'sol', english: 'sun'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => []);

      final pool = await contentService.loadContent(mode: ListenRepeatMode.phrases);
      expect(pool, isNotEmpty);

      // In the first 10 items, there must be priority topic phrases
      final firstTen = pool.take(10).toList();
      final topicItemsInFirstTen = firstTen.where(ListenRepeatContentService.isTopicItem).length;
      expect(topicItemsInFirstTen, greaterThanOrEqualTo(3),
          reason: 'Biased phrases pool must feature topic phrases prominently in the first 10 items');
    });

    test('loads all individual topic words and pairs them with phrases in each section', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'sol', english: 'sun'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => []);

      final sections = [
        ('House & Rooms', 25),
        ('Household Items', 32),
        ('Body & Health', 29),
        ('Everyday Items', 22),
      ];

      for (final (section, expectedWordCount) in sections) {
        final pool = await contentService.loadContent(
          mode: ListenRepeatMode.topics,
          subCategory: section,
        );

        final words = pool.where((i) => i.wordType == 'topic_word').toList();
        final phrases = pool.where((i) => i.wordType != 'topic_word').toList();

        expect(
          words.length,
          greaterThanOrEqualTo(expectedWordCount),
          reason: 'Section $section must contain at least $expectedWordCount individual words',
        );

        expect(
          phrases,
          isNotEmpty,
          reason: 'Section $section must contain reinforcing phrases',
        );

        // Verify that in the mixed deck, words are interleaved with phrases (words and phrases both present)
        expect(pool.length, greaterThan(words.length));

        // Check word-phrase pairing: each word must be followed immediately by its reinforcing phrase
        for (int i = 0; i < pool.length; i++) {
          final item = pool[i];
          if (item.wordType == 'topic_word') {
            expect(i + 1 < pool.length, isTrue,
                reason: 'Word ${item.portuguese} at index $i must be followed by its paired phrase');
            final nextItem = pool[i + 1];
            expect(nextItem.wordType, isNot(equals('topic_word')),
                reason: 'Item immediately after ${item.portuguese} must be a phrase');
            if (item.exampleSentencePt != null && item.exampleSentencePt!.isNotEmpty) {
              expect(
                nextItem.portuguese.trim().toLowerCase(),
                equals(item.exampleSentencePt!.trim().toLowerCase()),
                reason: 'Word ${item.portuguese} must be paired with its exact target phrase',
              );
            }
          }
        }

        // Verify no duplicate words exist in this section
        final wordPtList = words.map((w) => w.portuguese.trim().toLowerCase()).toList();
        expect(wordPtList.toSet().length, equals(wordPtList.length),
            reason: 'Section $section must contain no duplicate words');
      }
    });

    test('All Topics contains exactly 108 unique words across all four A2 everyday sections', () async {
      when(() => storage.getAllItems()).thenReturn([
        LanguageItem(id: 'v1', portuguese: 'sol', english: 'sun'),
      ]);
      when(() => verbService.loadVerbs()).thenAnswer((_) async => []);

      final pool = await contentService.loadContent(mode: ListenRepeatMode.topics);
      final words = pool.where((i) => i.wordType == 'topic_word').toList();

      expect(words.length, equals(108),
          reason: 'All Topics must parse to exactly 108 individual words');

      // Verify all items are well-formed
      for (final w in words) {
        expect(w.portuguese.trim(), isNotEmpty);
        expect(w.english.trim(), isNotEmpty);
        expect(w.topicCategory, isNotNull);
      }

      // Verify no duplicates across the entire 108-word dataset
      final allWordPtList = words.map((w) => w.portuguese.trim().toLowerCase()).toList();
      expect(allWordPtList.toSet().length, equals(108),
          reason: 'All Topics must contain no duplicate words');

      // Verify all 4 categories are represented in words
      final categories = words.map((w) => w.topicCategory).toSet();
      expect(categories, contains('House & Rooms'));
      expect(categories, contains('Household Items'));
      expect(categories, contains('Body & Health'));
      expect(categories, contains('Everyday Items'));
    });

    test('Word boundary matcher rejects substring collisions and matches whole words', () {
      expect(ListenRepeatContentService.matchesWordBoundaryForTesting('O carro fica na garagem.', 'garagem'), isTrue);
      expect(ListenRepeatContentService.matchesWordBoundaryForTesting('Tenho muita coragem.', 'cor'), isFalse);
      expect(ListenRepeatContentService.matchesWordBoundaryForTesting('A cor da casa é branca.', 'cor'), isTrue);
      expect(ListenRepeatContentService.matchesWordBoundaryForTesting('Dói-me a boca.', 'boca'), isTrue);
      expect(ListenRepeatContentService.matchesWordBoundaryForTesting('A sala de estar é ampla.', 'sala de estar'), isTrue);
    });

    test('_buildTopicMixedPool keyword fallback respects word boundaries and skips already-used phrases', () {
      final words = [
        LanguageItem(
          id: 'w1',
          portuguese: 'o garfo',
          english: 'fork',
          wordType: 'topic_word',
          topicCategory: 'Household Items',
        ),
        LanguageItem(
          id: 'w2',
          portuguese: 'a faca',
          english: 'knife',
          wordType: 'topic_word',
          topicCategory: 'Household Items',
        ),
      ];

      final candidatePhrases = [
        LanguageItem(
          id: 'p1',
          portuguese: 'Uso o garfo e a faca para comer.',
          english: 'I use the fork and knife to eat.',
          wordType: 'phrase',
          topicCategory: 'Household Items',
        ),
        LanguageItem(
          id: 'p2',
          portuguese: 'A faca está muito afiada.',
          english: 'The knife is very sharp.',
          wordType: 'phrase',
          topicCategory: 'Household Items',
        ),
      ];

      final pool = contentService.buildTopicMixedPoolForTesting(
        words: words,
        phrases: candidatePhrases,
        verbPhrases: [],
        subCategory: 'Household Items',
      );

      expect(pool.length, equals(4));
      // Word 1 pairs with p1 (which mentions garfo)
      // Word 2 cannot reuse p1 because p1 is already used, so it must pair with p2
      final w1Index = pool.indexWhere((i) => i.id == 'w1');
      final w2Index = pool.indexWhere((i) => i.id == 'w2');

      expect(pool[w1Index + 1].id, equals('p1'));
      expect(pool[w2Index + 1].id, equals('p2'));
    });

    test('_buildTopicMixedPool synthesizes fallback phrase when target phrase is missing from pool', () {
      final words = [
        LanguageItem(
          id: 'w_fallback',
          portuguese: 'o candeeiro',
          english: 'lamp',
          wordType: 'topic_word',
          topicCategory: 'Household Items',
          exampleSentencePt: 'O candeeiro novo ilumina o quarto todo.',
          exampleSentenceEn: 'The new lamp illuminates the whole room.',
        ),
      ];

      final pool = contentService.buildTopicMixedPoolForTesting(
        words: words,
        phrases: [],
        verbPhrases: [],
        subCategory: 'Household Items',
      );

      expect(pool.length, equals(2));
      expect(pool[0].id, equals('w_fallback'));
      expect(pool[1].id, equals('phrase_target_w_fallback'));
      expect(pool[1].portuguese, equals('O candeeiro novo ilumina o quarto todo.'));
      expect(pool[1].english, equals('The new lamp illuminates the whole room.'));
    });

    test('_resolveTopicWords preserves all curated words even if keywords collide (no last-wins drop)', () {
      final curatedWords = [
        LanguageItem(
          id: 'curated_1',
          portuguese: 'o copo',
          english: 'glass',
          wordType: 'topic_word',
          topicCategory: 'Household Items',
        ),
        LanguageItem(
          id: 'curated_2',
          portuguese: 'um copo',
          english: 'a glass',
          wordType: 'topic_word',
          topicCategory: 'Household Items',
        ),
      ];

      final storageItems = [
        LanguageItem(
          id: 'storage_1',
          portuguese: 'copo',
          english: 'glass',
          wordType: 'topic_word',
          topicCategory: 'Household Items',
          masteryLevel: 4,
        ),
      ];

      final resolved = contentService.resolveTopicWordsForTesting(
        vocabItems: storageItems,
        curatedTopicWords: curatedWords,
      );

      // Both curated items must be present (neither dropped by key collision)
      expect(resolved.length, equals(2));
      // First curated item merged with matching storage item to preserve id and mastery
      expect(resolved[0].id, equals('storage_1'));
      expect(resolved[0].masteryLevel, equals(4));
      // Second curated item retained as-is
      expect(resolved[1].id, equals('curated_2'));
      expect(resolved[1].portuguese, equals('um copo'));
    });
  });
}
