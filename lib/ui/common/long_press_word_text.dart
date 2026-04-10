import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart'; // for storageServiceProvider
import '../../models/language_item.dart';
import '../vocabulary/vocabulary_item_dialog.dart';

class LongPressWordText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  const LongPressWordText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
  });

  @override
  ConsumerState<LongPressWordText> createState() => _LongPressWordTextState();
}

class _LongPressWordTextState extends ConsumerState<LongPressWordText> {
  late List<LongPressGestureRecognizer> _recognizers;

  @override
  void initState() {
    super.initState();
    _recognizers = [];
  }

  @override
  void dispose() {
    for (var r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _handleWordPress(String word) {
    final cleanWord = word.trim().toLowerCase();
    
    // Look up in storage
    final storage = ref.read(storageServiceProvider);
    final allItems = storage.getAllItems();
    
    final exactMatch = allItems.where((item) => item.portuguese.toLowerCase() == cleanWord).firstOrNull;
    
    if (exactMatch != null) {
      _showTranslationCallout(exactMatch);
    } else {
      _showAddDialog(word.trim());
    }
  }

  void _showTranslationCallout(LanguageItem item) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Theme.of(context).cardColor,
            elevation: 16,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.portuguese,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 2,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.english,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddDialog(String word) {
    final tempItem = LanguageItem(
      id: 'temp',
      portuguese: word,
      english: '',
      masteryLevel: 0,
    );

    showDialog(
      context: context,
      builder: (context) => VocabularyItemDialog(
        item: tempItem,
        focusEnglish: true, // Jump straight to english translation
        onSave: (newItem, _) async {
          final storage = ref.read(storageServiceProvider);
          await storage.updateItem(newItem);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Clear old recognizers
    for (var r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final RegExp wordRegex = RegExp(r"[\p{L}\p{M}]+(?:[-'][\p{L}\p{M}]+)*", unicode: true);
    final List<TextSpan> spans = [];

    int lastMatchEnd = 0;
    for (var match in wordRegex.allMatches(widget.text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: widget.text.substring(lastMatchEnd, match.start),
        ));
      }

      final word = match.group(0)!;
      final recognizer = LongPressGestureRecognizer()..onLongPress = () {
        _handleWordPress(word);
      };
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: word,
        recognizer: recognizer,
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(lastMatchEnd)));
    }

    return RichText(
      textAlign: widget.textAlign,
      text: TextSpan(
        style: widget.style ?? DefaultTextStyle.of(context).style,
        children: spans,
      ),
    );
  }
}
