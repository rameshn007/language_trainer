import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/models/flashcard_item.dart';

void main() {
  group('FlashcardItem Tests', () {
    test('Constructs from vocabulary json correctly', () {
      final json = {
        'id': 1,
        'portuguese': 'ser',
        'english': 'to be (permanent)',
        'pronunciation': 'SAIR',
        'word_type': 'verb',
        'cefr_level': 'A1',
        'topic_category': 'Grammar - To Be',
        'present_tense': {
          'eu': 'sou',
          'tu': 'és',
          'ele_ela_voce': 'é',
          'nos': 'somos',
          'voces_eles': 'são',
        },
      };

      final item = FlashcardItem.fromVocabJson(json);

      expect(item.id, '1');
      expect(item.cardNumber, '#1');
      expect(item.portuguese, 'ser');
      expect(item.english, 'to be (permanent)');
      expect(item.category, 'VERBS');
      expect(item.categoryColor, const Color(0xFF0288D1));
      expect(item.formattedPronunciation, '[SAIR]');
      expect(item.isGrammarCard, false);
      expect(item.presentTense?['eu'], 'sou');
      expect(item.presentTense?['nos'], 'somos');
      expect(item.languageItemId, 'vocab_1');
    });

    test('Constructs from vocabulary json with null id without vocab_0 collisions', () {
      final json = {
        'portuguese': 'olá',
        'english': 'hello',
      };
      final item = FlashcardItem.fromVocabJson(json);
      expect(item.languageItemId, isNull);
      expect(item.cardNumber, '#');
    });

    test('Constructs from grammar json correctly and prevents orphan Hive rows', () {
      final json = {
        'id': 'G1',
        'card_number': '#G1',
        'category': 'EXPLANATION',
        'portuguese': 'Verbos Reflexivos (-se)',
        'english': 'Reflexive Verbs',
        'pronunciation': 'vehr-boosh reh-flehk-SEE-voosh',
        'cefr_level': 'A1',
        'explanation': 'Used when subject and object are the same.',
      };

      final item = FlashcardItem.fromGrammarJson(json);

      expect(item.id, 'G1');
      expect(item.cardNumber, '#G1');
      expect(item.category, 'EXPLANATION');
      expect(item.categoryColor, const Color(0xFF1E3A5F));
      expect(item.isGrammarCard, true);
      expect(item.languageItemId, isNull);
      expect(item.grammarExplanation, contains('Used when subject and object are the same.'));
    });

    test('Correctly maps category colors for PDF themes', () {
      final foodItem = FlashcardItem.fromVocabJson({
        'id': 42,
        'portuguese': 'a água',
        'english': 'water',
        'topic_category': 'Food & Drink',
      });
      expect(foodItem.category, 'FOOD');
      expect(foodItem.categoryColor, const Color(0xFFEF6C00));

      final homeItem = FlashcardItem.fromVocabJson({
        'id': 12,
        'portuguese': 'a sala',
        'english': 'the room',
        'topic_category': 'house and home',
      });
      expect(homeItem.category, 'HOME');
      expect(homeItem.categoryColor, const Color(0xFF2E7D32));

      final numberItem = FlashcardItem.fromVocabJson({
        'id': 73,
        'portuguese': 'zero',
        'english': 'zero',
        'word_type': 'number',
        'topic_category': 'Numbers',
      });
      expect(numberItem.category, 'NUMBERS');
      expect(numberItem.categoryColor, const Color(0xFFE65100));
    });

    test('typeDetailsString formats word type and gender', () {
      final item = FlashcardItem(
        id: '6',
        cardNumber: '#6',
        portuguese: 'o estudante',
        english: 'the student',
        category: 'GENERAL',
        wordType: 'noun',
        gender: 'masculine',
      );

      expect(item.typeDetailsString, 'Type: noun | Masculine');
    });
  });
}
