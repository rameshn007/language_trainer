import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/language_item.dart';
import '../main.dart'; // added
import 'storage_service.dart';

final relatedWordsServiceProvider = Provider<RelatedWordsService>((ref) {
  final storageService = ref.watch(storageServiceProvider);
  return RelatedWordsService(storageService);
});

class RelatedWordsService {
  final StorageService _storageService;

  RelatedWordsService(this._storageService);

  List<LanguageItem> getRelatedWords(LanguageItem source, {int limit = 6}) {
    final allItems = _storageService.getAllItems();
    final List<_ScoredItem> scoredItems = [];

    // Stop words to ignore when comparing English definitions
    final stopWords = {
      'to',
      'the',
      'a',
      'an',
      'is',
      'are',
      'in',
      'on',
      'at',
      'for',
      'with',
      'of',
    };

    Set<String> sourceEnTokens = source.english
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.isNotEmpty && !stopWords.contains(w))
        .toSet();

    String sourcePtLower = source.portuguese.toLowerCase();

    // We want to avoid exact matches
    for (var item in allItems) {
      if (item.id == source.id) continue;

      int score = 0;
      String itemPtLower = item.portuguese.toLowerCase();

      // Portuguese substring match
      if (itemPtLower.contains(sourcePtLower) ||
          sourcePtLower.contains(itemPtLower)) {
        score += 50;

        // Bonus for word boundary match (e.g., "comer" inside "comer fruta")
        if (RegExp(
          r'\b' + RegExp.escape(sourcePtLower) + r'\b',
        ).hasMatch(itemPtLower)) {
          score += 50;
        }
      }

      // English meaning overlap
      Set<String> itemEnTokens = item.english
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .split(' ')
          .where((w) => w.isNotEmpty && !stopWords.contains(w))
          .toSet();

      int overlap = sourceEnTokens.intersection(itemEnTokens).length;
      score += overlap * 30;

      if (score > 0) {
        // Add tiny random jitter to break ties
        scoredItems.add(
          _ScoredItem(item, score + (DateTime.now().millisecond % 10)),
        );
      }
    }

    // Sort by descending score
    scoredItems.sort((a, b) => b.score.compareTo(a.score));

    // Pad with random items if we don't naturally have enough
    final result = scoredItems.take(limit).map((e) => e.item).toList();
    if (result.length < limit) {
      final additional = allItems
          .where((i) => i.id != source.id && !result.any((r) => r.id == i.id))
          .toList();
      additional.shuffle();
      result.addAll(additional.take(limit - result.length));
    }

    return result.take(limit).toList();
  }
}

class _ScoredItem {
  final LanguageItem item;
  final int score;

  _ScoredItem(this.item, this.score);
}
