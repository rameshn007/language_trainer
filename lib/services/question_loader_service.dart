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
      return parseQuestionsJson(content, sourceItems);
    } catch (e) {
      // If file doesn't exist or bad json, return empty
      debugPrint('Question Loader Error: $e');
      return [];
    }
  }

  static String _normalize(String s) {
    return s.replaceAll(RegExp(r'[*_~`]+'), '').trim().toLowerCase();
  }

  List<Question> parseQuestionsJson(
    String content,
    List<LanguageItem> sourceItems,
  ) {
    final List<dynamic> jsonList = jsonDecode(content);
    final List<Question> result = [];

    // Precompute lookup map for O(1) matching of legacy source items
    final Map<String, LanguageItem> exactMap = {};
    for (final i in sourceItems) {
      final pt = _normalize(i.portuguese);
      final en = _normalize(i.english);
      if (pt.isNotEmpty) exactMap.putIfAbsent(pt, () => i);
      if (en.isNotEmpty) exactMap.putIfAbsent(en, () => i);

      // Also map individual parts split on common multi-phrase delimiters
      for (final part in pt.split(RegExp(r'[/;,]'))) {
        final cleanPart = _normalize(part);
        if (cleanPart.isNotEmpty) exactMap.putIfAbsent(cleanPart, () => i);
      }
      for (final part in en.split(RegExp(r'[/;,]'))) {
        final cleanPart = _normalize(part);
        if (cleanPart.isNotEmpty) exactMap.putIfAbsent(cleanPart, () => i);
      }
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
        final key = _normalize(ptWord);
        var matched = exactMap[key];

        // Secondary fallback tier: contains matching for compound notes/entries
        if (matched == null && key.isNotEmpty) {
          for (final i in sourceItems) {
            final ptNorm = _normalize(i.portuguese);
            final enNorm = _normalize(i.english);
            if (ptNorm.contains(key) ||
                enNorm.contains(key) ||
                key.contains(ptNorm) ||
                key.contains(enNorm)) {
              matched = i;
              exactMap[key] = i; // Cache for subsequent lookups
              break;
            }
          }
        }

        if (matched != null) {
          sourceItem = matched;
        } else {
          debugPrint(
            'QuestionLoaderService: No matching sourceItem found for "$ptWord"',
          );
          sourceItem = LanguageItem(
            id: 'legacy_${ptWord.hashCode}',
            portuguese: ptWord,
            english: '',
          );
          exactMap[key] = sourceItem;
        }
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
