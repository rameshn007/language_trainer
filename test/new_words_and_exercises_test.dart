import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/ui/exercise/exercise_list_screen.dart';
import 'package:language_trainer/ui/quiz/category_selection_screen.dart';

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

    test('unit_comparatives_and_duration.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_comparatives_and_duration.json');
    });

    test('unit_rooms_in_the_house.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_rooms_in_the_house.json');
    });

    test('unit_household_items.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_household_items.json');
    });

    test('unit_body_parts_and_health.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_body_parts_and_health.json');
    });

    test('unit_everyday_items.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_everyday_items.json');
    });

    test('unit_question_formation.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_question_formation.json');
    });

    test('unit_prepositions_para_por.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_prepositions_para_por.json');
    });

    test('unit_imperative_formal_informal.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_imperative_formal_informal.json');
    });

    test('unit_synonyms_antonyms.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_synonyms_antonyms.json');
    });

    test('unit_past_tense_and_holidays.json adheres to exercise invariants', () {
      validateExerciseFile('assets/data/exercises/unit_past_tense_and_holidays.json');
    });

    test('indirect_object_pronouns.json adheres to exercise invariants and includes target items', () {
      validateExerciseFile('assets/data/exercises/indirect_object_pronouns.json');

      final file = File('assets/data/exercises/indirect_object_pronouns.json');
      final List<dynamic> jsonList = jsonDecode(file.readAsStringSync());
      final ids = jsonList.map((e) => e['id']).toSet();
      expect(ids.contains('indir_pron_carlos_senha'), isTrue);
      expect(ids.contains('indir_pron_carlos_informal'), isTrue);
    });

    test('phrases.json and verb_phrases.json have valid non-empty structures and cover new topics', () {
      final phrasesFile = File('assets/data/phrases.json');
      expect(phrasesFile.existsSync(), isTrue);
      final List<dynamic> phrases = jsonDecode(phrasesFile.readAsStringSync());
      expect(phrases, isNotEmpty);
      final phraseCategories = <String>{};
      for (final p in phrases) {
        expect((p['portuguese'] ?? '').toString().trim(), isNotEmpty);
        expect((p['english'] ?? '').toString().trim(), isNotEmpty);
        if (p['category'] != null) {
          phraseCategories.add(p['category'].toString());
        }
      }
      expect(phraseCategories, contains('House & Rooms'));
      expect(phraseCategories, contains('Household Items'));
      expect(phraseCategories, contains('Body & Health'));
      expect(phraseCategories, contains('Everyday Items'));

      final verbPhrasesFile = File('assets/data/verb_phrases.json');
      expect(verbPhrasesFile.existsSync(), isTrue);
      final List<dynamic> verbPhrases = jsonDecode(verbPhrasesFile.readAsStringSync());
      expect(verbPhrases, isNotEmpty);
      final verbSet = <String>{};
      for (final vp in verbPhrases) {
        expect((vp['verb'] ?? '').toString().trim(), isNotEmpty);
        expect((vp['portuguese'] ?? '').toString().trim(), isNotEmpty);
        expect((vp['english'] ?? '').toString().trim(), isNotEmpty);
        verbSet.add(vp['verb'].toString());
      }
      expect(verbSet, contains('cozinhar'));
      expect(verbSet, contains('dormir'));
      expect(verbSet, contains('doer'));
      expect(verbSet, contains('carregar'));
      expect(verbSet, contains('decidir'));
      expect(verbSet, contains('trocar'));
      expect(verbSet, contains('festejar'));
      expect(verbSet, contains('aceitar'));
      expect(verbSet, contains('empurrar'));
    });

    test('verbs.csv includes traduzir, sentar, espirrar, herdar, and praticar with all conjugation fields populated', () {
      final verbsFile = File('assets/data/verbs.csv');
      expect(verbsFile.existsSync(), isTrue);
      final lines = verbsFile.readAsLinesSync();

      for (final verb in ['traduzir', 'sentar', 'espirrar', 'herdar', 'praticar', 'atender', 'tirar', 'decidir', 'trocar', 'festejar', 'celebrar', 'aceitar', 'puxar', 'empurrar']) {
        final verbLine = lines.firstWhere((l) => l.startsWith('$verb,'), orElse: () => '');
        expect(verbLine, isNotEmpty, reason: 'verbs.csv must contain an entry for $verb');
        final parts = verbLine.split(',');
        expect(parts.length, greaterThanOrEqualTo(7),
            reason: '$verb entry in verbs.csv must have at least 7 fields');
      }
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

    test('combined_questions.json and questions.json have zero question text overlap with any exercise unit file', () {
      final combinedFile = File('assets/data/combined_questions.json');
      expect(combinedFile.existsSync(), isTrue);
      final List<dynamic> combinedList = jsonDecode(combinedFile.readAsStringSync());
      final combinedQuestions = combinedList
          .map((q) => (q['question'] ?? q['questionText'] ?? '').toString().trim())
          .where((t) => t.isNotEmpty)
          .toSet();

      final questionsFile = File('assets/data/questions.json');
      expect(questionsFile.existsSync(), isTrue);
      final List<dynamic> questionsList = jsonDecode(questionsFile.readAsStringSync());
      final bankQuestions = questionsList
          .map((q) => (q['question'] ?? q['questionText'] ?? '').toString().trim())
          .where((t) => t.isNotEmpty)
          .toSet();

      final exercisesDir = Directory('assets/data/exercises');
      expect(exercisesDir.existsSync(), isTrue);

      for (final entity in exercisesDir.listSync()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final List<dynamic> exerciseList = jsonDecode(entity.readAsStringSync());
          for (final eq in exerciseList) {
            final text = (eq['questionText'] ?? eq['question'] ?? '').toString().trim();
            if (text.isNotEmpty) {
              expect(combinedQuestions.contains(text), isFalse,
                  reason: 'Question "$text" in ${entity.path} must not be duplicated in combined_questions.json');
              expect(bankQuestions.contains(text), isFalse,
                  reason: 'Question "$text" in ${entity.path} must not be duplicated in questions.json');
            }
          }
        }
      }

      // Case-insensitive bank x bank check for newly added questions (q_5734+)
      final preExistingBankLower = <String>{};
      final newBankQuestions = <Map<String, dynamic>>[];
      for (final q in questionsList) {
        final idStr = (q['id'] as String?) ?? '';
        final numPart = int.tryParse(idStr.replaceFirst('q_', '')) ?? 0;
        final textLower = (q['question'] ?? q['questionText'] ?? '').toString().trim().toLowerCase();
        if (numPart <= 5733) {
          preExistingBankLower.add(textLower);
        } else {
          newBankQuestions.add(Map<String, dynamic>.from(q as Map));
        }
      }
      final combinedLower = combinedQuestions.map((t) => t.toLowerCase()).toSet();
      for (final nq in newBankQuestions) {
        final textLower = (nq['question'] ?? nq['questionText'] ?? '').toString().trim().toLowerCase();
        expect(preExistingBankLower.contains(textLower), isFalse,
            reason: 'New question ${nq['id']} ("${nq['question']}") duplicates pre-existing questions.json');
        expect(combinedLower.contains(textLower), isFalse,
            reason: 'New question ${nq['id']} ("${nq['question']}") duplicates combined_questions.json');
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
      expect(unitPaths.contains('assets/data/exercises/unit_comparatives_and_duration.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_rooms_in_the_house.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_household_items.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_body_parts_and_health.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_everyday_items.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_question_formation.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_prepositions_para_por.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_imperative_formal_informal.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_synonyms_antonyms.json'), isTrue);
      expect(unitPaths.contains('assets/data/exercises/unit_past_tense_and_holidays.json'), isTrue);
    });

    test('CategorySelectionScreen covers all categories present in questions.json', () {
      const screen = CategorySelectionScreen();
      expect(screen.categories, contains('Hobbies & Leisure'));
      expect(screen.categories, contains('Office & Work'));
      expect(screen.categories, contains('House & Rooms'));
      expect(screen.categories, contains('Household Items'));
      expect(screen.categories, contains('Body & Health'));
      expect(screen.categories, contains('Everyday Items'));

      final file = File('assets/data/questions.json');
      final List<dynamic> jsonList = jsonDecode(file.readAsStringSync());
      final categoriesInBank = jsonList
          .map((q) => (q['cat'] as String?) ?? 'General')
          .toSet();

      for (final cat in categoriesInBank) {
        expect(screen.categories.contains(cat), isTrue,
            reason: 'Category "$cat" from questions.json must have a corresponding route in CategorySelectionScreen');
      }
    });

    test('vocabulary.json present_tense and past_tense are null or 5-person Maps and new entries do not overlap source.md', () {
      final vocabFile = File('assets/vocabulary.json');
      expect(vocabFile.existsSync(), isTrue);
      final List<dynamic> vocabList = jsonDecode(vocabFile.readAsStringSync());
      const requiredKeys = {'eu', 'tu', 'ele_ela_voce', 'nos', 'voces_eles'};

      final sourceLines = File('assets/data/source.md').readAsLinesSync();
      final sourcePt = <String>{};
      for (final line in sourceLines) {
        final s = line.trim();
        if (s.startsWith('|')) {
          final parts = s.split('|').map((p) => p.trim()).toList();
          if (parts.length >= 4 && !parts[1].contains('Portugues') && !parts[1].contains('---')) {
            sourcePt.add(parts[1].toLowerCase());
          }
        }
      }

      for (final entry in vocabList) {
        final id = entry['id'];
        for (final field in ['present_tense', 'past_tense']) {
          final val = entry[field];
          if (val != null) {
            expect(val, isA<Map>(), reason: 'Entry $id $field must be null or a Map');
            final keys = (val as Map).keys.map((k) => k.toString()).toSet();
            expect(keys, equals(requiredKeys), reason: 'Entry $id $field must have 5 person keys');
          }
        }
        if (id is int && id >= 985) {
          final pt = (entry['portuguese'] as String).trim().toLowerCase();
          expect(sourcePt.contains(pt), isFalse,
              reason: 'New vocabulary.json entry $id ("$pt") must not duplicate source.md');
        }
      }
    });
  });
}
