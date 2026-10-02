import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/ui/quiz/category_selection_screen.dart';
import 'package:language_trainer/ui/quiz/quiz_category.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quiz Categories & Loader Tests', () {
    test('shared kQuizCategories contains all 13 expected categories', () {
      expect(kQuizCategories.length, equals(13));
      final names = kQuizCategories.map((c) => c.name).toSet();
      expect(names, containsAll([
        'Basics',
        'Family',
        'Food & Drink',
        'Travel & Directions',
        'Time & Numbers',
        'Grammar & Verbs',
        'Hobbies & Leisure',
        'Office & Work',
        'House & Rooms',
        'Household Items',
        'Body & Health',
        'Everyday Items',
        'General',
      ]));
    });

    test('CategorySelectionScreen categories agrees with kAllQuizCategoryNames', () {
      const screen = CategorySelectionScreen();
      expect(screen.categories, equals(kAllQuizCategoryNames));
      expect(screen.categories.first, equals('All'));
      for (final cat in kQuizCategories) {
        expect(screen.categories, contains(cat.name));
      }
    });

    test('every category in kQuizCategories yields > 0 questions in questions.json', () {
      final file = File('assets/data/questions.json');
      expect(file.existsSync(), isTrue, reason: 'assets/data/questions.json must exist');

      final List<dynamic> jsonList = jsonDecode(file.readAsStringSync());
      final Map<String, int> countsByCategory = {};

      for (final q in jsonList) {
        final cat = (q['category'] ?? q['cat'] ?? 'General') as String;
        countsByCategory[cat] = (countsByCategory[cat] ?? 0) + 1;
      }

      for (final catInfo in kQuizCategories) {
        final count = countsByCategory[catInfo.name] ?? 0;
        expect(
          count,
          greaterThan(0),
          reason: 'Quiz category "${catInfo.name}" has 0 matching questions in questions.json!',
        );
      }
    });

    test('getIconForQuizCategory returns valid icon for all categories and "All"', () {
      expect(getIconForQuizCategory('All'), isNotNull);
      for (final cat in kQuizCategories) {
        final icon = getIconForQuizCategory(cat.name);
        expect(icon, equals(cat.icon));
      }
      // Fallback for unknown category
      expect(getIconForQuizCategory('UnknownCategoryXYZ'), isNotNull);
    });
  });
}
