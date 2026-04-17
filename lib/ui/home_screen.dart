import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../services/markdown_parser.dart';
import 'quiz/category_selection_screen.dart';
import 'vocabulary/vocabulary_list_screen.dart';
import 'exercise/exercise_list_screen.dart';
import 'voice_trainer_screen.dart';
import 'phrase_trainer_screen.dart';
import 'quiz/verb_conjugation_screen.dart';
import 'quiz/verb_phrase_trainer_screen.dart';
import 'quiz/quiz_screen.dart';
import '../main.dart';
import 'widgets/word_star_field.dart';
import 'settings_screen.dart';
import '../services/verb_service.dart';
import '../models/language_item.dart';
import 'exercise/exercise_screen.dart';
import 'quiz/interrogative_quiz_screen.dart';

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
      _checkEnhancedVoice();
    });
  }

  Future<void> _checkEnhancedVoice() async {
    final tts = ref.read(ttsServiceProvider);
    final storage = ref.read(storageServiceProvider);

    if (tts.initFuture != null) {
      await tts.initFuture;
    }

    if (!mounted) return;

    final hasSeenPrompt =
        storage.getSetting('has_seen_enhanced_voice_prompt') ?? false;
    if (!tts.isEnhancedPtVoiceAvailable && !hasSeenPrompt) {
      await storage.saveSetting('has_seen_enhanced_voice_prompt', true);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Improve Voice Quality'),
            content: SingleChildScrollView(
              child: Text(tts.getVoiceInstallationInstructions()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final parser = MarkdownParser();
      final freshItems = await parser.loadAndParseRawData(
        'assets/data/source.md',
      );
      // merge logic similar to previous implementation
      final existingItems = storage.getAllItems();
      final masteryMap = {for (var i in existingItems) i.id: i.masteryLevel};
      final reviewMap = {for (var i in existingItems) i.id: i.lastReviewed};
      for (var item in freshItems) {
        if (masteryMap.containsKey(item.id)) {
          item.masteryLevel = masteryMap[item.id]!;
          item.lastReviewed = reviewMap[item.id];
        }
      }
      await storage.clearItems();
      await storage.saveItems(freshItems);

      // --- Also load verbs and add as vocabulary items ---
      final verbService = ref.read(verbServiceProvider);
      final verbs = await verbService.loadVerbs();
      final List<LanguageItem> verbItems = [];

      // Existing Portuguese words from source.md for deduplication
      final sourceWords = freshItems.map((i) => i.portuguese.toLowerCase().trim()).toSet();

      for (var v in verbs) {
        final ptWord = v.infinitive.toLowerCase().trim();
        if (!sourceWords.contains(ptWord)) {
          verbItems.add(
            LanguageItem(
              id: 'verb_${v.infinitive}',
              portuguese: v.infinitive,
              english: v.translation,
              notes: 'Verb conjugation exercise available',
            ),
          );
          sourceWords.add(ptWord);
        }
      }

      if (verbItems.isNotEmpty) {
        await storage.saveItems(verbItems);
        debugPrint('Added ${verbItems.length} new verbs to vocabulary storage.');
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _confirmShuffle() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shuffle Questions?'),
        content: const Text(
          'This will treat all questions as "new", allowing you to see the entire question pool again. Your learned mastery levels will remain unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Shuffle All'),
          ),
        ],
      ),
    );
    if (result == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.clearSeenQuestions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All questions randomized!')),
        );
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
      setState(() {});
    }
  }

  Future<T?> _pushScreen<T>(Widget screen, [Offset? center]) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (center == null) {
            return FadeTransition(opacity: animation, child: child);
          }

          return ClipPath(
            clipper: CircularRevealClipper(
              fraction: animation.value,
              center: center,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 650),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              } else if (value == 'shuffle') {
                _confirmShuffle();
              } else if (value == 'reset') {
                _confirmReset();
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                ),
              ),
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh Data'),
                ),
              ),
              const PopupMenuItem(
                value: 'shuffle',
                child: ListTile(
                  leading: Icon(Icons.shuffle),
                  title: Text('Shuffle All Questions'),
                ),
              ),
              const PopupMenuItem(
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
          SafeArea(
            child: Column(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      FadeInDown(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400.withValues(
                                  alpha: 0.9,
                                ),
                                Colors.deepPurple.shade700.withValues(
                                  alpha: 0.9,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  child: FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildGridButton(
                                context: context,
                                label: 'Start Quiz',
                                icon: Icons.quiz_rounded,
                                bgColor: Theme.of(context).colorScheme.primary,
                                fgColor: Colors.white,
                                onPressed: items.isEmpty || _isLoading
                                    ? null
                                    : (offset) {
                                        _pushScreen(
                                          const CategorySelectionScreen(),
                                          offset,
                                        ).then((_) => setState(() {}));
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildGridButton(
                                context: context,
                                label: 'Vocabulary',
                                icon: Icons.book_rounded,
                                bgColor: Colors.blue.shade600,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const VocabularyListScreen(),
                                    offset,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildGridButton(
                                context: context,
                                label: 'Exercises',
                                icon: Icons.assignment_rounded,
                                bgColor: Theme.of(
                                  context,
                                ).colorScheme.secondary,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const ExerciseListScreen(),
                                    offset,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildGridButton(
                                context: context,
                                label: 'Voice Trainer',
                                icon: Icons.mic_rounded,
                                bgColor: Colors.deepOrange,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const VoiceTrainerScreen(),
                                    offset,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildGridButton(
                                context: context,
                                label: 'Phrase Trainer',
                                icon: Icons.translate_rounded,
                                bgColor: Colors.green,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const PhraseTrainerScreen(),
                                    offset,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildGridButton(
                                context: context,
                                label: 'Verb Trainer',
                                icon: Icons.school_rounded,
                                bgColor: Colors.purple,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const VerbConjugationScreen(),
                                    offset,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildGridButton(
                                context: context,
                                label: 'Sentence Builder',
                                icon: Icons.reorder_rounded,
                                bgColor: Colors.indigo,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const ExerciseScreen(
                                      unitName: 'Unit 10: Word Order & Pronouns',
                                      unitPath: 'assets/data/exercises/unit_10.json',
                                    ),
                                    offset,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: _buildGridButton(
                                context: context,
                                label: '100 Phrases',
                                icon: Icons.style_rounded,
                                bgColor: Colors.teal,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const VerbPhraseTrainerScreen(),
                                    offset,
                                  );
                                },
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: _buildGridButton(
                                context: context,
                                label: 'Vocab Quiz',
                                icon: Icons.local_fire_department_rounded,
                                bgColor: Colors.amber.shade700,
                                fgColor: Colors.white,
                                onPressed: items.isEmpty || _isLoading
                                    ? null
                                    : (offset) {
                                        _pushScreen(
                                          const QuizScreen(isVocabularyQuiz: true),
                                          offset,
                                        ).then((_) => setState(() {}));
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildGridButton(
                                context: context,
                                label: 'Interrogatives',
                                icon: Icons.contact_support_rounded,
                                bgColor: Colors.cyan.shade700,
                                fgColor: Colors.white,
                                onPressed: (offset) {
                                  _pushScreen(
                                    const InterrogativeQuizScreen(),
                                    offset,
                                  );
                                },
                              ),
                            ),
                            const Expanded(flex: 2, child: SizedBox()),
                            const Expanded(flex: 2, child: SizedBox()),
                          ],
                        ),
                      ],
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

  Widget _buildGridButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color fgColor,
    void Function(Offset offset)? onPressed,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 110),
      child: Card(
        elevation: 2,
        color: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: null, // We handle tap via GestureDetector below
          child: GestureDetector(
            onTapUp: (details) {
              if (onPressed != null) {
                onPressed(details.globalPosition);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    onPressed == null
                        ? Colors.grey.shade300.withValues(alpha: 0.7)
                        : bgColor.withValues(alpha: 0.85),
                    onPressed == null
                        ? Colors.grey.shade400.withValues(alpha: 0.7)
                        : bgColor.withValues(alpha: 0.95),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 28,
                    color: onPressed == null ? Colors.white70 : fgColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: onPressed == null ? Colors.white70 : fgColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;

  CircularRevealClipper({required this.fraction, required this.center});

  @override
  Path getClip(Size size) {
    // Calculate the distance to the farthest corner
    final double maxRadius = _calculateDistanceToFarthestCorner(size, center);
    final double currentRadius = maxRadius * fraction;

    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: currentRadius));
  }

  @override
  bool shouldReclip(CircularRevealClipper oldClipper) {
    return oldClipper.fraction != fraction || oldClipper.center != center;
  }

  double _calculateDistanceToFarthestCorner(Size size, Offset center) {
    final List<Offset> corners = [
      const Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];

    double maxDistance = 0;
    for (final corner in corners) {
      final double distance = (center - corner).distance;
      if (distance > maxDistance) {
        maxDistance = distance;
      }
    }
    return maxDistance;
  }
}
