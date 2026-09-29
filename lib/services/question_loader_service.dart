import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/question.dart';
import '../models/language_item.dart';

class QuestionLoaderService {
  Future<List<Question>> loadQuestions(
    String assetPath,
    List<LanguageItem> sourceItems,
  ) async {
    try {
      final String content = await rootBundle.loadString(assetPath);
      final List<dynamic> jsonList = jsonDecode(content);
      final List<Question> result = [];

      // Precompute lookup map for O(1) matching of legacy source items
      final Map<String, LanguageItem> exactMap = {};
      for (final i in sourceItems) {
        final pt = i.portuguese.trim().toLowerCase();
        final en = i.english.trim().toLowerCase();
        if (pt.isNotEmpty) exactMap.putIfAbsent(pt, () => i);
        if (en.isNotEmpty) exactMap.putIfAbsent(en, () => i);
      }

      for (var obj in jsonList) {
        // Handle Source Item
        LanguageItem sourceItem;
        if (obj['sourceItem'] is Map) {
          // New format: Embedded source item
          final map = obj['sourceItem'];
          sourceItem = LanguageItem(
            id:
                map['id'] ??
                'generated_${DateTime.now().millisecondsSinceEpoch}',
            portuguese: map['portuguese'] ?? '',
            english: map['english'] ?? '',
            notes: map['notes'] ?? '',
          );
        } else if (obj['sourceItem'] is String) {
          // Old format: Lookup by text
          final ptWord = obj['sourceItem'] as String;
          final key = ptWord.trim().toLowerCase();
          sourceItem = exactMap[key] ??
              (sourceItems.isNotEmpty
                  ? sourceItems.first
                  : LanguageItem(
                      id: 'legacy_${ptWord.hashCode}',
                      portuguese: ptWord,
                      english: '',
                    ));
        } else {
          // No source item
          sourceItem = LanguageItem.empty();
        }

        // Handle Key Aliases
        final questionText = obj['questionText'] ?? obj['question'] ?? '';
        final correctAnswer = obj['correctAnswer'] ?? obj['answer'] ?? '';
        final category = obj['category'] ?? obj['cat'];
        final options = List<String>.from(obj['options'] ?? []);

        result.add(
          Question(
            id:
                obj['id'] ??
                'json_${DateTime.now().millisecondsSinceEpoch}_${result.length}',
            questionText: questionText,
            options: options,
            correctAnswer: correctAnswer,
            type: _parseType(obj['type']),
            sourceItem: sourceItem,
            category: category,
          ),
        );
      }
      return result;
    } catch (e) {
      // If file doesn't exist or bad json, return empty
      debugPrint('Question Loader Error: $e');
      return [];
    }
  }

  QuestionType _parseType(String? type) {
    switch (type) {
      case 'cloze':
        return QuestionType.cloze;
      case 'trueFalse':
        return QuestionType.trueFalse;
      case 'jumble':
        return QuestionType.jumble;
      case 'reorderAndConjugate':
        return QuestionType.reorderAndConjugate;
      default:
        return QuestionType.multipleChoice;
    }
  }
}
