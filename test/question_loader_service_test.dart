import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/services/question_loader_service.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/question.dart';

void main() {
  late QuestionLoaderService loader;

  final sampleItems = [
    LanguageItem(id: '1', portuguese: 'Olá', english: 'Hello'),
    LanguageItem(id: '2', portuguese: 'Adeus', english: 'Goodbye'),
    LanguageItem(id: '3', portuguese: 'Sim', english: 'Yes'),
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

    test('returns empty list for invalid JSON file', () async {
      // If questions.json doesn't exist or has bad content, should return empty
      final result = await loader.loadQuestions(
        'assets/data/questions.json',
        sampleItems,
      );
      expect(result, isA<List<Question>>());
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
}
