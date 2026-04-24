import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/language_item.dart';
import '../../services/translation_service.dart';

class VocabularyItemDialog extends ConsumerStatefulWidget {
  final LanguageItem? item;
  final bool focusEnglish;
  final Function(LanguageItem newItem, String? oldId) onSave;

  const VocabularyItemDialog({
    super.key,
    this.item,
    this.focusEnglish = false,
    required this.onSave,
  });

  @override
  ConsumerState<VocabularyItemDialog> createState() => _VocabularyItemDialogState();
}

class _VocabularyItemDialogState extends ConsumerState<VocabularyItemDialog> {
  late TextEditingController _portugueseController;
  late TextEditingController _englishController;
  late FocusNode _portugueseFocusNode;
  late FocusNode _englishFocusNode;

  bool _isTranslatingPt = false;
  bool _isTranslatingEn = false;

  @override
  void initState() {
    super.initState();
    _portugueseController = TextEditingController(
      text: widget.item?.portuguese ?? '',
    );
    _englishController = TextEditingController(
      text: widget.item?.english ?? '',
    );
    
    _portugueseFocusNode = FocusNode();
    _englishFocusNode = FocusNode();

    // Auto focus logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.focusEnglish) {
        _englishFocusNode.requestFocus();
      } else {
        _portugueseFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _portugueseController.dispose();
    _englishController.dispose();
    _portugueseFocusNode.dispose();
    _englishFocusNode.dispose();
    super.dispose();
  }

  Future<void> _translate(bool fromPortuguese) async {
    final sourceController = fromPortuguese ? _portugueseController : _englishController;
    final targetController = fromPortuguese ? _englishController : _portugueseController;
    
    final text = sourceController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (fromPortuguese) {
        _isTranslatingPt = true;
      } else {
        _isTranslatingEn = true;
      }
    });

    try {
      final translationService = ref.read(translationServiceProvider);
      final result = await translationService.translate(text, fromEn: !fromPortuguese);

      if (result != null && mounted) {
        targetController.text = result;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Translation failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslatingPt = false;
          _isTranslatingEn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null || widget.item!.id == 'temp' ? 'Add Word' : 'Edit Word'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _portugueseController,
            focusNode: _portugueseFocusNode,
            decoration: InputDecoration(
              labelText: 'Portuguese',
              suffixIcon: _isTranslatingPt 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _translate(true),
                    tooltip: 'Translate to English',
                  ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _englishController,
            focusNode: _englishFocusNode,
            decoration: InputDecoration(
              labelText: 'English',
              suffixIcon: _isTranslatingEn
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _translate(false),
                    tooltip: 'Translate to Portuguese',
                  ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final pt = _portugueseController.text.trim();
            final en = _englishController.text.trim();
            if (pt.isEmpty || en.isEmpty) return;

            // Create new item
            // If editing, preserve mastery and lastReviewed
            final newItem = LanguageItem(
              id: '${pt}_$en'.replaceAll(' ', '_'),
              portuguese: pt,
              english: en,
              masteryLevel: widget.item?.masteryLevel ?? 0,
              lastReviewed: widget.item?.lastReviewed,
              notes: widget.item?.notes ?? '',
            );

            widget.onSave(newItem, widget.item?.id == 'temp' ? null : widget.item?.id);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
