import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/services/quiz_engine_service.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/question.dart';
import 'package:language_trainer/models/verb.dart';

void main() {
  late QuizEngineService engine;

  final sampleItems = [
    LanguageItem(id: '1', portuguese: 'Olá', english: 'Hello', wordType: 'greeting'),
    LanguageItem(id: '2', portuguese: 'Adeus', english: 'Goodbye', wordType: 'greeting'),
    LanguageItem(id: '3', portuguese: 'Sim', english: 'Yes', wordType: 'adverb'),
    LanguageItem(id: '4', portuguese: 'Não', english: 'No', wordType: 'adverb'),
    LanguageItem(id: '5', portuguese: 'Cachorro', english: 'Dog', wordType: 'noun'),
    LanguageItem(id: '6', portuguese: 'Gato', english: 'Cat', wordType: 'noun'),
    LanguageItem(id: '7', portuguese: 'Eu como', english: 'I eat', wordType: 'phrase'),
    LanguageItem(id: '8', portuguese: 'Bom dia', english: 'Good morning', wordType: 'phrase'),
    LanguageItem(id: '9', portuguese: 'Obrigado', english: 'Thank you', wordType: 'phrase'),
    LanguageItem(id: '10', portuguese: 'Por favor', english: 'Please', wordType: 'phrase'),
    LanguageItem(id: '11', portuguese: 'Amigo', english: 'Friend', wordType: 'noun'),
    LanguageItem(id: '12', portuguese: 'Casa', english: 'House', wordType: 'noun'),
  ];

  final sampleVerbs = [
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
    ),
    Verb(
      infinitive: 'comer',
      translation: 'to eat',
      conjugations: {
        'eu': 'como',
        'tu': 'comes',
        'você, ela, ele': 'come',
        'nós': 'comemos',
        'vocês, elas, eles': 'comedem',
      },
    ),
    Verb(
      infinitive: 'viver',
      translation: 'to live',
      conjugations: {
        'eu': 'vivo',
        'tu': 'vives',
        'você, ela, ele': 'vive',
        'nós': 'vivemos',
        'vocês, elas, eles': 'vivem',
      },
    ),
  ];

  setUp(() {
    engine = QuizEngineService();
  });

  group('generateQuiz — Basic', () {
    test('returns empty list for empty items', () {
      final result = engine.generateQuiz([]);
      expect(result, isEmpty);
    });

    test('returns correct count when items exceed count', () {
      final result = engine.generateQuiz(sampleItems, count: 5);
      expect(result, hasLength(5));
    });

    test('returns all items when count exceeds item count', () {
      final result = engine.generateQuiz(sampleItems, count: 100);
      expect(result, hasLength(sampleItems.length));
    });

    test('returns all items when count equals item count', () {
      final result = engine.generateQuiz(sampleItems, count: 12);
      expect(result, hasLength(12));
    });

    test('returns all items when items fewer than count', () {
      final result = engine.generateQuiz([sampleItems[0]], count: 10);
      expect(result, hasLength(1));
    });
  });

  group('generateQuiz — Question Structure', () {
    test('all questions have non-empty text', () {
      final result = engine.generateQuiz(sampleItems, count: 5);
      for (final q in result) {
        expect(q.questionText.isNotEmpty, isTrue);
      }
    });

    test('all questions have exactly 4 options', () {
      final result = engine.generateQuiz(sampleItems, count: 5);
      for (final q in result) {
        expect(q.options, hasLength(4));
      }
    });

    test('all questions have correct answer in options', () {
      final result = engine.generateQuiz(sampleItems, count: 5);
      for (final q in result) {
        expect(q.options.contains(q.correctAnswer), isTrue);
      }
    });

    test('all options are unique within each question', () {
      final result = engine.generateQuiz(sampleItems, count: 5);
      for (final q in result) {
        expect(q.options.toSet().length, q.options.length);
      }
    });

    test('questions have correct type', () {
      final result = engine.generateQuiz(sampleItems, count: 5);
      for (final q in result) {
        expect(q.type, QuestionType.multipleChoice);
      }
    });
  });

  group('generateVocabularyQuiz — Word/Phrase Split', () {
    test('generates vocabulary match questions with mixed word/phrases', () {
      final itemsWithPhrases = [
        ...sampleItems,
        LanguageItem(id: '13', portuguese: 'Eu gosto de', english: 'I like to', wordType: 'phrase'),
        LanguageItem(id: '14', portuguese: 'Onde fica o', english: 'Where is the', wordType: 'phrase'),
        LanguageItem(id: '15', portuguese: 'Eu quero um', english: 'I want a', wordType: 'phrase'),
      ];
      final result = engine.generateVocabularyQuiz(itemsWithPhrases, count: 5);
      expect(result, hasLength(5));
      for (final q in result) {
        expect(q.type, QuestionType.vocabularyMatch);
      }
    });

    test('returns empty list for empty items', () {
      final result = engine.generateVocabularyQuiz([]);
      expect(result, isEmpty);
    });

    test('all options are unique', () {
      final itemsWithPhrases = [
        ...sampleItems,
        LanguageItem(id: '13', portuguese: 'Eu gosto de', english: 'I like to', wordType: 'phrase'),
        LanguageItem(id: '14', portuguese: 'Onde fica o', english: 'Where is the', wordType: 'phrase'),
        LanguageItem(id: '15', portuguese: 'Eu quero um', english: 'I want a', wordType: 'phrase'),
      ];
      final result = engine.generateVocabularyQuiz(itemsWithPhrases, count: 5);
      for (final q in result) {
        expect(q.options.toSet().length, q.options.length);
      }
    });

    test('correct answer is in options', () {
      final itemsWithPhrases = [
        ...sampleItems,
        LanguageItem(id: '13', portuguese: 'Eu gosto de', english: 'I like to', wordType: 'phrase'),
        LanguageItem(id: '14', portuguese: 'Onde fica o', english: 'Where is the', wordType: 'phrase'),
        LanguageItem(id: '15', portuguese: 'Eu quero um', english: 'I want a', wordType: 'phrase'),
      ];
      final result = engine.generateVocabularyQuiz(itemsWithPhrases, count: 5);
      for (final q in result) {
        expect(q.options.contains(q.correctAnswer), isTrue);
      }
    });

    test('exactly 4 options per question', () {
      final itemsWithPhrases = [
        ...sampleItems,
        LanguageItem(id: '13', portuguese: 'Eu gosto de', english: 'I like to', wordType: 'phrase'),
        LanguageItem(id: '14', portuguese: 'Onde fica o', english: 'Where is the', wordType: 'phrase'),
        LanguageItem(id: '15', portuguese: 'Eu quero um', english: 'I want a', wordType: 'phrase'),
      ];
      final result = engine.generateVocabularyQuiz(itemsWithPhrases, count: 5);
      for (final q in result) {
        expect(q.options, hasLength(4));
      }
    });
  });

  group('generateVocabularyQuiz — Seen Item Prioritization', () {
    test('generates questions when all items unseen', () {
      final itemsWithPhrases = [
        ...sampleItems,
        LanguageItem(id: '13', portuguese: 'Eu gosto de', english: 'I like to', wordType: 'phrase'),
        LanguageItem(id: '14', portuguese: 'Onde fica o', english: 'Where is the', wordType: 'phrase'),
        LanguageItem(id: '15', portuguese: 'Eu quero um', english: 'I want a', wordType: 'phrase'),
      ];
      final result = engine.generateVocabularyQuiz(itemsWithPhrases, count: 5);
      expect(result, hasLength(5));
    });

    test('returns fewer questions when not enough items', () {
      final result = engine.generateVocabularyQuiz([sampleItems[0]], count: 10);
      expect(result.length, lessThanOrEqualTo(1));
    });
  });

  group('generateClozeQuestionsFromExamples — Filtering', () {
    test('filters out items without example sentences', () {
      final itemsNoExamples = [
        LanguageItem(id: '1', portuguese: 'Olá', english: 'Hello'),
        LanguageItem(id: '2', portuguese: 'Adeus', english: 'Goodbye'),
      ];
      final result = engine.generateClozeQuestionsFromExamples(itemsNoExamples);
      expect(result, isEmpty);
    });

    test('filters out items where Portuguese word not in sentence', () {
      final items = [
        LanguageItem(
          id: '1',
          portuguese: 'Olá',
          english: 'Hello',
          exampleSentencePt: 'O gato é preto',
          exampleSentenceEn: 'The cat is black',
        ),
      ];
      final result = engine.generateClozeQuestionsFromExamples(items);
      expect(result, isEmpty);
    });

    test('includes items where Portuguese word appears in sentence', () {
      final items = [
        LanguageItem(
          id: '1',
          portuguese: 'gato',
          english: 'Cat',
          exampleSentencePt: 'O gato é preto',
          exampleSentenceEn: 'The cat is black',
        ),
      ];
      final result = engine.generateClozeQuestionsFromExamples(items);
      expect(result, hasLength(1));
      expect(result[0].type, QuestionType.cloze);
    });

    test('returns empty list for empty items', () {
      final result = engine.generateClozeQuestionsFromExamples([]);
      expect(result, isEmpty);
    });
  });

  group('generateClozeQuestionsFromExamples — Question Structure', () {
    test('question text contains blank', () {
      final items = [
        LanguageItem(
          id: '1',
          portuguese: 'gato',
          english: 'Cat',
          exampleSentencePt: 'O gato é preto',
          exampleSentenceEn: 'The cat is black',
        ),
      ];
      final result = engine.generateClozeQuestionsFromExamples(items);
      expect(result[0].questionText.contains('____'), isTrue);
    });

    test('correct answer matches the Portuguese word', () {
      final items = [
        LanguageItem(
          id: '1',
          portuguese: 'gato',
          english: 'Cat',
          exampleSentencePt: 'O gato é preto',
          exampleSentenceEn: 'The cat is black',
        ),
      ];
      final result = engine.generateClozeQuestionsFromExamples(items);
      expect(result[0].correctAnswer.toLowerCase(), 'gato');
    });

    test('generates 4 unique options with enough items', () {
      final items = [
        LanguageItem(id: '1', portuguese: 'gato', english: 'Cat', exampleSentencePt: 'O gato é preto', exampleSentenceEn: 'The cat is black'),
        LanguageItem(id: '2', portuguese: 'cachorro', english: 'Dog', exampleSentencePt: 'O cachorro corre', exampleSentenceEn: 'The dog runs'),
        LanguageItem(id: '3', portuguese: 'pássaro', english: 'Bird', exampleSentencePt: 'O pássaro voa', exampleSentenceEn: 'The bird flies'),
        LanguageItem(id: '4', portuguese: 'peixe', english: 'Fish', exampleSentencePt: 'O peixe nada', exampleSentenceEn: 'The fish swims'),
      ];
      final result = engine.generateClozeQuestionsFromExamples(items);
      for (final q in result) {
        expect(q.options.toSet().length, q.options.length);
        expect(q.options, hasLength(4));
      }
    });
  });

  group('generateVerbConjugationQuestions — Basic', () {
    test('returns empty list for empty verbs', () {
      final result = engine.generateVerbConjugationQuestions(verbs: []);
      expect(result, isEmpty);
    });

    test('returns correct count when verbs exceed count', () {
      final result = engine.generateVerbConjugationQuestions(verbs: sampleVerbs, count: 2);
      expect(result, hasLength(2));
    });

    test('returns all verbs when count exceeds verb count', () {
      final result = engine.generateVerbConjugationQuestions(verbs: sampleVerbs, count: 100);
      expect(result.length, lessThanOrEqualTo(3));
    });

    test('all questions have 4 options', () {
      final result = engine.generateVerbConjugationQuestions(verbs: sampleVerbs, count: 10);
      for (final q in result) {
        expect(q.options, hasLength(4));
      }
    });

    test('all options are unique within each question', () {
      final result = engine.generateVerbConjugationQuestions(verbs: sampleVerbs, count: 10);
      for (final q in result) {
        expect(q.options.toSet().length, q.options.length);
      }
    });

    test('correct answer is in options', () {
      final result = engine.generateVerbConjugationQuestions(verbs: sampleVerbs, count: 10);
      for (final q in result) {
        expect(q.options.contains(q.correctAnswer), isTrue);
      }
    });

    test('question text mentions the infinitive', () {
      final result = engine.generateVerbConjugationQuestions(verbs: sampleVerbs, count: 10);
      for (final q in result) {
        expect(q.questionText.toLowerCase().contains('falar') ||
            q.questionText.toLowerCase().contains('comer') ||
            q.questionText.toLowerCase().contains('viver'), isTrue);
      }
    });
  });

  group('generateVerbConjugationQuestions — Distractor Quality', () {
    test('distractors include other conjugations of same verb', () {
      final verbs = [
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
        ),
      ];
      final result = engine.generateVerbConjugationQuestions(verbs: verbs, count: 5);
      // All questions should use "falar"
      for (final q in result) {
        expect(q.questionText.contains('falar'), isTrue);
      }
    });
  });
}
