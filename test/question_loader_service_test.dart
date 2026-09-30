import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/services/question_loader_service.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/question.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late QuestionLoaderService loader;

  final sampleItems = [
    LanguageItem(id: '1', portuguese: 'Olá', english: 'Hello'),
    LanguageItem(id: '2', portuguese: 'Adeus', english: 'Goodbye'),
    LanguageItem(id: '3', portuguese: 'Sim', english: 'Yes'),
    LanguageItem(id: '4', portuguese: '**em**', english: '**in/on**'),
    LanguageItem(id: '5', portuguese: 'por / pelo / pela', english: 'by / through'),
  ];

  setUp(() {
    loader = QuestionLoaderService();
  });

  group('loadQuestions — Error Handling', () {
    test('returns empty list for non-existent file', () async {
      final result = await loader.loadQuestions(
        'assets/data/nonexistent.json',
        sampleItems,
      );
      expect(result, isEmpty);
    });

    test('handles empty source items list gracefully', () async {
      final result = await loader.loadQuestions(
        'assets/data/nonexistent.json',
        [],
      );
      expect(result, isEmpty);
    });
  });

  group('QuestionLoaderService — Integration', () {
    test('service instantiates without error', () {
      expect(loader, isNotNull);
    });

    test('returns list type for valid call', () async {
      final result = await loader.loadQuestions(
        'assets/data/nonexistent.json',
        sampleItems,
      );
      expect(result, isA<List<Question>>());
    });
  });

  group('QuestionLoaderService — parseQuestionsJson Matching', () {
    test('resolves exact match', () {
      const json = '''[
        {
          "id": "q1",
          "question": "What is Olá?",
          "answer": "Hello",
          "options": ["Hello", "Goodbye"],
          "sourceItem": "Olá"
        }
      ]''';
      final questions = loader.parseQuestionsJson(json, sampleItems);
      expect(questions, hasLength(1));
      expect(questions.first.sourceItem.id, '1');
      expect(questions.first.sourceItem.portuguese, 'Olá');
    });

    test('resolves markdown-wrapped items (e.g. **em** matches "em")', () {
      const json = '''[
        {
          "id": "q_em",
          "question": "What is em?",
          "answer": "in/on",
          "options": ["in/on", "by"],
          "sourceItem": "em"
        }
      ]''';
      final questions = loader.parseQuestionsJson(json, sampleItems);
      expect(questions, hasLength(1));
      expect(questions.first.sourceItem.id, '4');
      expect(questions.first.sourceItem.portuguese, '**em**');
    });

    test('resolves delimiter-separated multi-phrase items (e.g. "pelo" in "por / pelo / pela")', () {
      const json = '''[
        {
          "id": "q_pelo",
          "question": "What is pelo?",
          "answer": "by",
          "options": ["by", "with"],
          "sourceItem": "pelo"
        }
      ]''';
      final questions = loader.parseQuestionsJson(json, sampleItems);
      expect(questions, hasLength(1));
      expect(questions.first.sourceItem.id, '5');
    });

    test('falls back to legacy item rather than sourceItems.first on no match', () {
      const json = '''[
        {
          "id": "q_unknown",
          "question": "What is unknown?",
          "answer": "???",
          "options": ["a", "b"],
          "sourceItem": "desconhecido_total"
        }
      ]''';
      final questions = loader.parseQuestionsJson(json, sampleItems);
      expect(questions, hasLength(1));
      expect(questions.first.sourceItem.id, isNot('1')); // Must not fall back to sampleItems.first ('Olá')
      expect(questions.first.sourceItem.id, startsWith('legacy_'));
      expect(questions.first.sourceItem.portuguese, 'desconhecido_total');
    });

    test('supports embedded sourceItem maps directly', () {
      const json = '''[
        {
          "id": "q_embed",
          "question": "Test",
          "answer": "ans",
          "options": ["ans"],
          "sourceItem": {
            "id": "embed_123",
            "portuguese": "mesa",
            "english": "table",
            "notes": "furniture"
          }
        }
      ]''';
      final questions = loader.parseQuestionsJson(json, sampleItems);
      expect(questions, hasLength(1));
      expect(questions.first.sourceItem.id, 'embed_123');
      expect(questions.first.sourceItem.portuguese, 'mesa');
    });
  });
}
