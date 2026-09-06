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
  });
}
