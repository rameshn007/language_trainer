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
  });
}
