import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/ui/exercise/exercise_list_screen.dart';

void main() {
  group('New Words & Exercises Validation', () {
    test('unit_conjunctions.json contains valid questions and correct answers in options', () {
      final file = File('assets/data/exercises/unit_conjunctions.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      expect(jsonList.length, equals(14));
      for (final item in jsonList) {
        expect(item['id'], isNotEmpty);
        expect(item['questionText'], isNotEmpty);
        expect(item['type'], equals('cloze'));
        final options = List<String>.from(item['options']);
        final correctAnswer = item['correctAnswer'];
        expect(options.contains(correctAnswer), isTrue,
            reason: 'Question ${item['id']} correctAnswer "$correctAnswer" must be in options');
      }
    });

    test('unit_sentence_transformations.json contains valid questions and correct answers in options', () {
      final file = File('assets/data/exercises/unit_sentence_transformations.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      expect(jsonList.length, equals(10));
      for (final item in jsonList) {
        expect(item['id'], isNotEmpty);
        expect(item['questionText'], isNotEmpty);
        expect(item['type'], equals('cloze'));
        final options = List<String>.from(item['options']);
        final correctAnswer = item['correctAnswer'];
        expect(options.contains(correctAnswer), isTrue,
            reason: 'Question ${item['id']} correctAnswer "$correctAnswer" must be in options');
      }
    });

    test('indirect_object_pronouns.json includes new questions for formal/informal and expansions', () {
      final file = File('assets/data/exercises/indirect_object_pronouns.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      expect(jsonList.length, greaterThanOrEqualTo(9));
      final ids = jsonList.map((e) => e['id']).toSet();
      expect(ids.contains('indir_pron_carlos_senha'), isTrue);
      expect(ids.contains('indir_pron_carlos_informal'), isTrue);
    });

    test('phrases.json and verb_phrases.json include newly added content', () {
      final phrasesFile = File('assets/data/phrases.json');
      expect(phrasesFile.existsSync(), isTrue);
      final List<dynamic> phrases = jsonDecode(phrasesFile.readAsStringSync());
      expect(phrases.length, greaterThan(30));

      final verbPhrasesFile = File('assets/data/verb_phrases.json');
      expect(verbPhrasesFile.existsSync(), isTrue);
      final List<dynamic> verbPhrases = jsonDecode(verbPhrasesFile.readAsStringSync());
      expect(verbPhrases.length, greaterThan(50));
    });

    test('questions.json has been regenerated with over 5000 questions', () {
      final file = File('assets/data/questions.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);

      expect(jsonList.length, greaterThanOrEqualTo(5000));
    });

    test('ExerciseListScreen includes new units in units list', () {
      const screen = ExerciseListScreen();
      final unitPaths = screen.units.map((u) => u['path']).toList();

      expect(unitPaths.contains('assets/data/exercises/unit_conjunctions.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_sentence_transformations.json'), isTrue);
    });
  });
}
