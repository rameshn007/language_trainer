import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/ui/exercise/exercise_list_screen.dart';

void main() {
  group('New Words & Exercises Validation — Invariant Checks', () {
    void validateExerciseFile(String relativePath) {
      final file = File(relativePath);
      expect(file.existsSync(), isTrue, reason: 'File $relativePath must exist');

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);
      expect(jsonList, isNotEmpty, reason: '$relativePath must not be empty');

      final seenIds = <String>{};
      for (final item in jsonList) {
        final id = item['id'] as String?;
        expect(id, isNotNull);
        expect(id, isNotEmpty);
        expect(seenIds.add(id!), isTrue, reason: 'Duplicate ID "$id" found in $relativePath');

        final questionText = item['questionText'] as String?;
        expect(questionText, isNotNull);
        expect(questionText, isNotEmpty);

        final options = List<String>.from(item['options'] ?? []);
        expect(options.length, greaterThanOrEqualTo(2),
            reason: 'Question $id in $relativePath must have at least 2 options');

        final correctAnswer = item['correctAnswer'];
        expect(options.contains(correctAnswer), isTrue,
            reason: 'Question $id in $relativePath: correctAnswer "$correctAnswer" must be present in options');

        if (item['sourceItem'] is Map) {
          final source = item['sourceItem'] as Map;
          expect(source['portuguese'], isNotEmpty);
          expect(source['english'], isNotEmpty);
        }
      }
    }

    test('unit_conjunctions.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_conjunctions.json');
    });

    test('unit_sentence_transformations.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_sentence_transformations.json');
    });

    test('indirect_object_pronouns.json adheres to exercise invariants and includes target items', () {
      validateExerciseFile('assets/data/exercises/indirect_object_pronouns.json');

      final file = File('assets/data/exercises/indirect_object_pronouns.json');
      final List<dynamic> jsonList = jsonDecode(file.readAsStringSync());
      final ids = jsonList.map((e) => e['id']).toSet();
      expect(ids.contains('indir_pron_carlos_senha'), isTrue);
      expect(ids.contains('indir_pron_carlos_informal'), isTrue);
    });

    test('phrases.json and verb_phrases.json have valid non-empty structures', () {
      final phrasesFile = File('assets/data/phrases.json');
      expect(phrasesFile.existsSync(), isTrue);
      final List<dynamic> phrases = jsonDecode(phrasesFile.readAsStringSync());
      expect(phrases, isNotEmpty);
      for (final p in phrases) {
        expect((p['portuguese'] ?? '').toString().trim(), isNotEmpty);
        expect((p['english'] ?? '').toString().trim(), isNotEmpty);
      }

      final verbPhrasesFile = File('assets/data/verb_phrases.json');
      expect(verbPhrasesFile.existsSync(), isTrue);
      final List<dynamic> verbPhrases = jsonDecode(verbPhrasesFile.readAsStringSync());
      expect(verbPhrases, isNotEmpty);
      for (final vp in verbPhrases) {
        expect((vp['verb'] ?? '').toString().trim(), isNotEmpty);
        expect((vp['portuguese'] ?? '').toString().trim(), isNotEmpty);
        expect((vp['english'] ?? '').toString().trim(), isNotEmpty);
      }
    });

    test('verbs.csv includes atender and tirar with all conjugation fields populated', () {
      final verbsFile = File('assets/data/verbs.csv');
      expect(verbsFile.existsSync(), isTrue);
      final lines = verbsFile.readAsLinesSync();

      final atenderLine = lines.firstWhere((l) => l.startsWith('atender,'), orElse: () => '');
      expect(atenderLine, isNotEmpty, reason: 'verbs.csv must contain an entry for atender');
      final atenderParts = atenderLine.split(',');
      expect(atenderParts.length, greaterThanOrEqualTo(7));

      final tirarLine = lines.firstWhere((l) => l.startsWith('tirar,'), orElse: () => '');
      expect(tirarLine, isNotEmpty, reason: 'verbs.csv must contain an entry for tirar');
      final tirarParts = tirarLine.split(',');
      expect(tirarParts.length, greaterThanOrEqualTo(7));
    });

    test('questions.json has unique IDs and all answers present in options', () {
      final file = File('assets/data/questions.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final List<dynamic> jsonList = jsonDecode(content);
      expect(jsonList, isNotEmpty);

      final seenIds = <String>{};
      for (final q in jsonList) {
        final id = q['id'] as String;
        expect(seenIds.add(id), isTrue, reason: 'Duplicate question ID "$id" in questions.json');

        final options = List<String>.from(q['options'] ?? []);
        final answer = q['answer'] ?? q['correctAnswer'];
        expect(options.contains(answer), isTrue,
            reason: 'Question $id: answer "$answer" must be in options');
      }
    });

    test('ExerciseListScreen registers valid units with existing asset paths', () {
      const screen = ExerciseListScreen();
      expect(screen.units, isNotEmpty);

      for (final unit in screen.units) {
        expect(unit['title'], isNotEmpty);
        expect(unit['subtitle'], isNotEmpty);
        expect(unit['path'], isNotEmpty);
        expect(unit['icon'], isNotEmpty);

        final assetFile = File(unit['path']!);
        expect(assetFile.existsSync(), isTrue,
            reason: 'Exercise unit path "${unit['path']}" must exist on disk');
      }

      final unitPaths = screen.units.map((u) => u['path']).toList();
      expect(unitPaths.contains('assets/data/exercises/unit_conjunctions.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_sentence_transformations.json'), isTrue);
    });
  });
}
