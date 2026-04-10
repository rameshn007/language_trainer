import 'package:flutter/material.dart';
import '../../models/language_item.dart';

class VocabularyItemDialog extends StatefulWidget {
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
  State<VocabularyItemDialog> createState() => _VocabularyItemDialogState();
}

class _VocabularyItemDialogState extends State<VocabularyItemDialog> {
  late TextEditingController _portugueseController;
  late TextEditingController _englishController;
  late FocusNode _portugueseFocusNode;
  late FocusNode _englishFocusNode;

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
            decoration: const InputDecoration(labelText: 'Portuguese'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _englishController,
            focusNode: _englishFocusNode,
            decoration: const InputDecoration(labelText: 'English'),
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
