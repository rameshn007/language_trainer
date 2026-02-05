import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../services/markdown_parser.dart';
import '../../main.dart';
import 'quiz/category_selection_screen.dart';
import 'widgets/word_star_field.dart';
import 'vocabulary/vocabulary_list_screen.dart';
import 'exercise/exercise_list_screen.dart';
import 'voice_trainer_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize CarPlay after the first frame to avoid disrupting startup
      // CarPlayService().init(); // Moved to main.dart
      // try {
      //   CarPlayService().init();
      // } catch (e) {
      //   debugPrint("CarPlay Init Error: $e");
      // }
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(storageServiceProvider);

      // Always reload to ensure sync with source.md/questions.json
      // OLD: if (!storage.hasData) { ... }

      // Merge logic:
      // 1. Get existing items map for fast lookup
      final existingItems = storage.getAllItems();
      final Map<String, int> masteryMap = {
        for (var i in existingItems) i.id: i.masteryLevel,
      };
      final Map<String, DateTime?> reviewMap = {
        for (var i in existingItems) i.id: i.lastReviewed,
      };

      // 2. Parse fresh items from source
      final parser = MarkdownParser();
      final freshItems = await parser.loadAndParseRawData(
        'assets/data/source.md',
      );

      // 3. Update fresh items with existing progress
      for (var item in freshItems) {
        if (masteryMap.containsKey(item.id)) {
          item.masteryLevel = masteryMap[item.id]!;
          item.lastReviewed = reviewMap[item.id];
        }
      }

      // 4. Save merged list (overwrites structure but keeps progress)
      await storage.clearItems();
      await storage.saveItems(freshItems);

      if (!mounted) return;
      // Optional: Show snackbar only if meaningful change or debug?
      // Keeping it for confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${freshItems.length} items from source'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmReset() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Statistics?'),
        content: const Text(
          'This will reset your "Learned" count and High Score to zero. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (result == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.resetStats();
      await storage.resetHighScore();
      setState(() {}); // Refresh UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Statistics reset successfully.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // return const LoadingScreen(); // Removed as per request
    }

    final storage = ref.watch(storageServiceProvider);
    final items = storage.getAllItems();
    final highScore = storage.getHighScore();
    final learnedCount = items.where((i) => i.masteryLevel > 0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language Trainer'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refresh') {
                _loadData();
              } else if (value == 'reset') {
                _confirmReset();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh Data'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('Reset Stats'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Star Field
          if (items.isNotEmpty)
            Positioned.fill(
              child: Opacity(
                opacity: 0.6,
                child: WordStarField(
                  words: learnedCount > 25
                      ? items
                            .where((i) => i.masteryLevel > 0)
                            .map((i) => i.portuguese)
                            .toList()
                      : items.map((i) => i.portuguese).toList(),
                  wordCount: 25,
                ),
              ),
            ),

          // Foreground Content
          SafeArea(
            child: Column(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Stats Board
                      FadeInDown(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.deepPurple.shade700,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem(
                                'Words',
                                '${items.length}',
                                Icons.book,
                              ),
                              _buildStatItem(
                                'Learned',
                                '$learnedCount',
                                Icons.check_circle_outline,
                              ),
                              _buildStatItem(
                                'High Score',
                                '$highScore',
                                Icons.emoji_events,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),

                const Spacer(),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (items.isEmpty)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 50,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 10),
                        const Text('No vocabulary loaded.'),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Tap here to load initial data'),
                        ),
                      ],
                    ),
                  ),

                if (items.isEmpty) const Spacer(),

                // Pinned Bottom Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                  child: FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            onPressed: items.isEmpty || _isLoading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const CategorySelectionScreen(),
                                      ),
                                    ).then((_) => setState(() {}));
                                  },
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 28,
                            ),
                            label: const Text(
                              'Start Quiz',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.secondary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ExerciseListScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.assignment, size: 28),
                            label: const Text(
                              'Exercises',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const VoiceTrainerScreen(),
                                ),
                              ).then((_) => setState(() {}));
                            },
                            icon: const Icon(Icons.mic, size: 28),
                            label: const Text(
                              'Voice Trainer',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Vocabulary List FAB
          Positioned(
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 260,
            child: FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: FloatingActionButton(
                heroTag: 'vocab_fab',
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VocabularyListScreen(),
                    ),
                  ).then((_) => setState(() {}));
                },
                child: const Icon(Icons.list),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 30),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
