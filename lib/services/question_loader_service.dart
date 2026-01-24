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

      for (var obj in jsonList) {
        final ptWord = obj['sourceItem'];
        // Find source item to link back for mastery tracking
        // 1. Try exact match
        // 2. Try contains match (for rows with multiple phrases)
        LanguageItem sourceItem = sourceItems.firstWhere(
          (i) =>
              i.portuguese.trim() == ptWord.trim() ||
              i.english.trim() == ptWord.trim(),
          orElse: () => LanguageItem.empty(),
        );

        if (sourceItem.isEmpty) {
          sourceItem = sourceItems.firstWhere(
            (i) =>
                i.portuguese.toLowerCase().contains(ptWord.toLowerCase()) ||
                i.english.toLowerCase().contains(ptWord.toLowerCase()),
            orElse: () {
              debugPrint(
                'Warning: Could not find source item for "$ptWord". Using fallback.',
              );
              return sourceItems.first;
            },
          );
        }

        result.add(
          Question(
            id:
                obj['id'] ??
                'json_${DateTime.now().millisecondsSinceEpoch}_${result.length}',
            questionText: obj['question'],
            options: List<String>.from(obj['options']),
            correctAnswer: obj['answer'],
            type: _parseType(obj['type']),
            sourceItem: sourceItem,
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
      default:
        return QuestionType.multipleChoice;
    }
  }
}
