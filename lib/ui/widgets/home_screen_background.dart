import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/ui/widgets/word_star_field.dart';

/// Decoupled ambient word cloud background for the Home Screen.
///
/// Keeps word list state and animation lifecycle completely isolated from
/// filter selections, category tabs, and scroll updates on the Home Screen.
class HomeScreenBackground extends ConsumerStatefulWidget {
  const HomeScreenBackground({super.key});

  @override
  ConsumerState<HomeScreenBackground> createState() =>
      _HomeScreenBackgroundState();
}

class _HomeScreenBackgroundState extends ConsumerState<HomeScreenBackground> {
  List<String> _cachedWords = const [];
  int _cachedItemCount = -1;
  int _cachedLearnedCount = -1;

  List<String> _getWords(List<LanguageItem> items) {
    if (items.isEmpty) return const [];
    final learnedCount = items.where((i) => i.masteryLevel > 0).length;
    if (items.length == _cachedItemCount &&
        learnedCount == _cachedLearnedCount &&
        _cachedWords.isNotEmpty) {
      return _cachedWords;
    }
    _cachedItemCount = items.length;
    _cachedLearnedCount = learnedCount;
    _cachedWords = learnedCount > 25
        ? items
            .where((i) => i.masteryLevel > 0)
            .map((i) => i.portuguese)
            .toList(growable: false)
        : items.map((i) => i.portuguese).toList(growable: false);
    return _cachedWords;
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final items = storage.getAllItems();
    final words = _getWords(items);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Stack(
      children: [
        if (words.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: isDark ? 0.6 : 0.5,
              child: WordStarField(
                words: words,
                wordCount: 25,
              ),
            ),
          ),
        // Bottom Scrim for readability and safe area
        if (isDark)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: isLandscape ? 80 : 150,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
