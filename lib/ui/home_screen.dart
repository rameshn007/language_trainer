import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../services/markdown_parser.dart';
import '../../main.dart';
import 'quiz/category_selection_screen.dart';
import 'loading_screen.dart';
import 'widgets/word_star_field.dart';

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
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(storageServiceProvider);

      // Always reload to ensure sync with source.md/questions.json
      // OLD: if (!storage.hasData) { ... }

      final parser = MarkdownParser();
      final items = await parser.loadAndParseRawData('assets/data/source.md');

      // Clear old data to remove orphans (sanitization cleanup)
      await storage.clearItems();
      await storage.saveItems(items);

      if (!mounted) return;
      // Optional: Show snackbar only if meaningful change or debug?
      // Keeping it for confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synced ${items.length} items from source'),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingScreen();
    }

    final storage = ref.watch(storageServiceProvider);
    final items = storage.getAllItems();
    final highScore = storage.getHighScore();
    final learnedCount = items.where((i) => i.masteryLevel > 0).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Language Trainer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Reload from File',
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

                if (items.isEmpty)
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
                    child: SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white,
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
                                ).then(
                                  (_) => setState(() {}),
                                ); // Refresh stats when back
                              },
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Text(
                          'Start Quiz',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
