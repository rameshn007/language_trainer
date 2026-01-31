import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/language_item.dart';

import '../../main.dart'; // for storageServiceProvider
import '../../services/tts_service.dart';

class VocabularyListScreen extends ConsumerStatefulWidget {
  const VocabularyListScreen({super.key});

  @override
  ConsumerState<VocabularyListScreen> createState() =>
      _VocabularyListScreenState();
}

class _VocabularyListScreenState extends ConsumerState<VocabularyListScreen> {
  List<LanguageItem> _items = [];
  List<LanguageItem> _filteredItems = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TtsService _ttsService = TtsService();
  double _speedMultiplier = 0.75;

  @override
  void initState() {
    super.initState();
    _loadItems();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _ttsService.setRate(_speedMultiplier);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _toggleSpeed() {
    setState(() {
      if (_speedMultiplier == 0.75) {
        _speedMultiplier = 1.0;
      } else if (_speedMultiplier == 1.0) {
        _speedMultiplier = 1.5;
      } else if (_speedMultiplier == 1.5) {
        _speedMultiplier = 0.5;
      } else {
        _speedMultiplier = 0.75;
      }
    });
    _ttsService.setRate(_speedMultiplier);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Speed: ${_speedMultiplier}x"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _loadItems() {
    final storage = ref.read(storageServiceProvider);
    final allItems = storage.getAllItems();
    setState(() {
      _items = allItems;
      _filterItems();
    });
  }

  void _filterItems() {
    if (_searchQuery.isEmpty) {
      _filteredItems = List.from(_items);
    } else {
      _filteredItems = _items.where((item) {
        return item.portuguese.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            item.english.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterItems();
    });
  }

  Future<void> _showEditDialog(LanguageItem? item) async {
    await showDialog(
      context: context,
      builder: (context) => VocabularyItemDialog(
        item: item,
        onSave: (newItem, oldId) async {
          final storage = ref.read(storageServiceProvider);

          if (oldId != null && oldId != newItem.id) {
            await storage.deleteItem(oldId);
          }

          await storage.updateItem(newItem);
        },
      ),
    );
    _loadItems(); // Reload after save
  }

  Future<void> _deleteItem(LanguageItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word?'),
        content: Text('Are you sure you want to delete "${item.portuguese}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteItem(item.id);
      _loadItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'Toggle Speed',
            onPressed: _toggleSpeed,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: _filteredItems.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _filteredItems[index];
          return InkWell(
            onTap: () => _ttsService.speak(item.portuguese),
            onDoubleTap: () => _showEditDialog(item),
            onLongPress: () => _deleteItem(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.portuguese,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.english,
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class VocabularyItemDialog extends StatefulWidget {
  final LanguageItem? item;
  final Function(LanguageItem newItem, String? oldId) onSave;

  const VocabularyItemDialog({super.key, this.item, required this.onSave});

  @override
  State<VocabularyItemDialog> createState() => _VocabularyItemDialogState();
}

class _VocabularyItemDialogState extends State<VocabularyItemDialog> {
  late TextEditingController _portugueseController;
  late TextEditingController _englishController;

  @override
  void initState() {
    super.initState();
    _portugueseController = TextEditingController(
      text: widget.item?.portuguese ?? '',
    );
    _englishController = TextEditingController(
      text: widget.item?.english ?? '',
    );
  }

  @override
  void dispose() {
    _portugueseController.dispose();
    _englishController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Add Word' : 'Edit Word'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _portugueseController,
            decoration: const InputDecoration(labelText: 'Portuguese'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _englishController,
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
              id: '${pt}_${en}'.replaceAll(' ', '_'),
              portuguese: pt,
              english: en,
              masteryLevel: widget.item?.masteryLevel ?? 0,
              lastReviewed: widget.item?.lastReviewed,
              notes: widget.item?.notes ?? '',
            );

            widget.onSave(newItem, widget.item?.id);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
