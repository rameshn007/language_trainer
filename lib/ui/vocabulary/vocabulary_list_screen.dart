import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/language_item.dart';

import '../../main.dart'; // for storageServiceProvider
import '../../services/tts_service.dart';

enum SortMode { alphabetical, mastery, random }

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
  bool _isTranslationsHidden = false;
  SortMode _sortMode = SortMode.alphabetical;
  bool _isPlaying = false;
  String? _currentlyPlayingId;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};

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
    _scrollController.dispose();
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

      // Migrate old boolean setting or load new enum setting
      final savedSort = storage.getSetting('sort_mode');
      if (savedSort != null && savedSort is int) {
        _sortMode = SortMode.values[savedSort];
      } else {
        // Fallback for previous boolean saving logic
        final oldBoolSetting =
            storage.getSetting('sort_by_mastery', defaultValue: false) as bool;
        _sortMode = oldBoolSetting ? SortMode.mastery : SortMode.alphabetical;
      }

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
    _sortItems();
  }

  void _sortItems() {
    switch (_sortMode) {
      case SortMode.mastery:
        // Sort by mastery level ascending (lowest first), then alphabetical
        _filteredItems.sort((a, b) {
          int cmp = a.masteryLevel.compareTo(b.masteryLevel);
          if (cmp != 0) return cmp;
          return a.portuguese.compareTo(b.portuguese);
        });
        break;
      case SortMode.random:
        _filteredItems.shuffle();
        break;
      case SortMode.alphabetical:
        // Sort alphabetical
        _filteredItems.sort((a, b) => a.portuguese.compareTo(b.portuguese));
        break;
    }
  }

  void _toggleTranslations() {
    setState(() {
      _isTranslationsHidden = !_isTranslationsHidden;
    });
  }

  void _toggleSort() {
    setState(() {
      // Cycle through modes: Alphabetical -> Mastery -> Random -> Alphabetical...
      int nextIndex = (_sortMode.index + 1) % SortMode.values.length;
      _sortMode = SortMode.values[nextIndex];
      _sortItems();
    });

    // Save preference as integer index
    final storage = ref.read(storageServiceProvider);
    storage.saveSetting('sort_mode', _sortMode.index);
  }

  Future<void> _togglePlayStop() async {
    if (_isPlaying) {
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = null;
      });
      await _ttsService.stop();
    } else {
      setState(() {
        _isPlaying = true;
      });
      _playPlaylist();
    }
  }

  Future<void> _playPlaylist({String? startFromId}) async {
    int startIndex = 0;
    if (startFromId != null) {
      startIndex = _filteredItems.indexWhere((item) => item.id == startFromId);
      if (startIndex == -1) startIndex = 0;

      setState(() {
        _isPlaying = true;
      });
    }

    // A tiny delay to allow the list to render if it just started
    await Future.delayed(const Duration(milliseconds: 100));

    for (int i = startIndex; i < _filteredItems.length; i++) {
      if (!mounted || !_isPlaying) break;

      final item = _filteredItems[i];
      setState(() {
        _currentlyPlayingId = item.id;
      });

      // Scroll to item using GlobalKey
      final key = _itemKeys[item.id];
      if (key != null &&
          key.currentContext != null &&
          _scrollController.hasClients) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment:
              0.1, // Aligns item near top (0.0 = top, 1.0 = bottom) but below the search bar
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      }

      // Speak Portuguese
      await _ttsService.speak(item.portuguese, language: 'pt-PT');
      // TTS service's speak is fire-and-forget for now, but we wait roughly appropriately
      // A better way is using flutter_tts completion handler, but we'll approximate with delay based on text length + margin
      int ptDurationMs =
          500 + (item.portuguese.length * 75 * (1 / _speedMultiplier)).toInt();
      await Future.delayed(Duration(milliseconds: ptDurationMs));

      if (!mounted || !_isPlaying) break;

      // Speak English
      await _ttsService.speak(item.english, language: 'en-US');
      int enDurationMs =
          500 + (item.english.length * 75 * (1 / _speedMultiplier)).toInt();
      // Delay for English + pause before next word
      await Future.delayed(Duration(milliseconds: enDurationMs + 1000));
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _currentlyPlayingId = null;
      });
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

  void _showContextMenu(LanguageItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play from here'),
              onTap: () {
                Navigator.pop(context); // Close sheet
                // Stop any current playback before starting new one
                if (_isPlaying) {
                  _ttsService.stop().then((_) {
                    _playPlaylist(startFromId: item.id);
                  });
                } else {
                  _playPlaylist(startFromId: item.id);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit word'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete word',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary List'),
        actions: [
          IconButton(
            icon: Icon(
              _isTranslationsHidden ? Icons.visibility_off : Icons.visibility,
            ),
            tooltip: 'Toggle Translations',
            onPressed: _toggleTranslations,
          ),
          IconButton(
            icon: Icon(
              _sortMode == SortMode.alphabetical
                  ? Icons.sort_by_alpha
                  : (_sortMode == SortMode.mastery
                        ? Icons.sort
                        : Icons.shuffle),
            ),
            tooltip: 'Sort Mode: ${_sortMode.name}',
            onPressed: _toggleSort,
          ),
          IconButton(
            icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
            tooltip: _isPlaying ? 'Stop Playlist' : 'Play Playlist',
            color: _isPlaying ? Colors.red : null,
            onPressed: _togglePlayStop,
          ),
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
        controller: _scrollController,
        itemCount: _filteredItems.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _filteredItems[index];

          Color masteryColor;
          if (item.masteryLevel >= 4) {
            masteryColor = Colors.green;
          } else if (item.masteryLevel >= 2) {
            masteryColor = Colors.orange;
          } else {
            masteryColor = Colors.red;
          }

          final isCurrentlyPlaying = item.id == _currentlyPlayingId;

          // Assign GlobalKey for scrolling
          if (!_itemKeys.containsKey(item.id)) {
            _itemKeys[item.id] = GlobalKey();
          }

          return Dismissible(
            key: Key('dismissible_${item.id}'),
            background: Container(
              color: Colors.green,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.check, color: Colors.white),
            ),
            secondaryBackground: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart) {
                // Return true to dismiss if confirmed
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Word?'),
                    content: Text(
                      'Are you sure you want to delete "${item.portuguese}"?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  final storage = ref.read(storageServiceProvider);
                  await storage.deleteItem(item.id);
                  // Not calling _loadItems() immediately so Dismissible handles the animation
                  // and we just remove it from our local lists
                  setState(() {
                    _items.removeWhere((i) => i.id == item.id);
                    _filteredItems.removeAt(index);
                  });
                  return true;
                }
                return false;
              } else if (direction == DismissDirection.startToEnd) {
                // Swipe right: Mark as mastered
                setState(() {
                  item.masteryLevel = 5;
                  item.lastReviewed = DateTime.now();
                });

                // Keep local ref to context to avoid async gap warning
                final scaffoldMsg = ScaffoldMessenger.of(context);

                final storage = ref.read(storageServiceProvider);
                await storage.updateItem(item);

                if (mounted) {
                  scaffoldMsg.hideCurrentSnackBar();
                  scaffoldMsg.showSnackBar(
                    const SnackBar(
                      content: Text('Marked as mastered!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }

                // If sorted by mastery or random, re-sort
                if (_sortMode != SortMode.alphabetical) {
                  setState(() => _sortItems());
                }

                return false; // Don't actually dismiss the item, just update it
              }
              return false;
            },
            child: InkWell(
              onTap: () {
                if (_isTranslationsHidden) {
                  // Temporary reveal
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(item.english),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
                _ttsService.speak(item.portuguese, language: 'pt-PT');
              },
              onDoubleTap: () => _showEditDialog(item),
              onLongPress: () => _showContextMenu(item),
              child: Container(
                key: _itemKeys[item.id],
                color: isCurrentlyPlaying
                    ? Colors.teal.withValues(alpha: 0.2)
                    : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 40,
                      decoration: BoxDecoration(
                        color: masteryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                      child: _isTranslationsHidden
                          ? Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            )
                          : Text(
                              item.english,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ],
                ),
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
              id: '${pt}_$en'.replaceAll(' ', '_'),
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
