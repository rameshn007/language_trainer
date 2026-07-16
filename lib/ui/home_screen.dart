import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../services/markdown_parser.dart';
import '../services/progress_service.dart';
import '../models/progress_data.dart';
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
import 'stats_screen.dart';
import '../services/verb_service.dart';
import '../models/language_item.dart';
import 'exercise/exercise_screen.dart';
import 'quiz/interrogative_quiz_screen.dart';
import 'quiz/grammar_quiz_screen.dart';
import 'quiz/preposition_quiz_screen.dart';
import 'listen_repeat/listen_repeat_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  final GlobalKey _fabKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _checkEnhancedVoice();
      final notificationService = ref.read(notificationServiceProvider);
      notificationService.requestPermissionsIfFirstTime();
      notificationService.handlePendingNotification();
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
      final bool vocabOnly =
          storage.getSetting('vocab_only_mode', defaultValue: false) == true;
      final parser = MarkdownParser();
      final List<LanguageItem> freshItems = [];

      if (!vocabOnly) {
        freshItems.addAll(
          await parser.loadAndParseRawData('assets/data/source.md'),
        );
        // Also load combined class notes
        try {
          freshItems.addAll(
            await parser.loadAndParseRawData(
              'assets/Combined_Portuguese_Class_Notes.md',
            ),
          );
        } catch (e) {
          debugPrint('Error loading Combined notes: $e');
        }
      }

      try {
        final String jsonContent = await rootBundle.loadString(
          'assets/vocabulary.json',
        );
        final List<dynamic> jsonList = jsonDecode(jsonContent);

        for (var item in jsonList) {
          freshItems.add(
            LanguageItem(
              id: 'vocab_${item['id'] ?? item.hashCode}',
              portuguese: item['portuguese']?.toString() ?? '',
              english: item['english']?.toString() ?? '',
              pronunciation: item['pronunciation']?.toString(),
              wordType: item['word_type']?.toString(),
              cefrLevel: item['cefr_level']?.toString(),
              topicCategory: item['topic_category']?.toString(),
              exampleSentencePt: item['example_sentence_pt']?.toString(),
              exampleSentenceEn: item['example_sentence_en']?.toString(),
              gender: item['gender']?.toString(),
              plural: item['plural']?.toString(),
              irregular: item['irregular'] == true,
              verbClass: item['verb_class']?.toString(),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error loading vocabulary.json in HomeScreen: $e');
      }

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
      final sourceWords = freshItems
          .map((i) => i.portuguese.toLowerCase().trim())
          .toSet();

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
        debugPrint(
          'Added ${verbItems.length} new verbs to vocabulary storage.',
        );
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (!mounted) return;
    // Refresh the progress snapshot so dashboard updates
    ref
        .read(progressServiceProvider.notifier)
        .refresh(ref.read(storageServiceProvider));
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
        title: const Text('Reset All Progress?'),
        content: const Text(
          'This will reset all XP, streaks, mastery levels, and session history. This action cannot be undone.',
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
      final progressService = ref.read(progressServiceProvider.notifier);
      await progressService.resetAll(ref.read(storageServiceProvider));
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
    final progress = ref.watch(progressServiceProvider);
    final learnedCount = items.where((i) => i.masteryLevel > 0).length;

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : const Color(0xFFF5F7FA),
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
              } else if (value == 'test_notif') {
                ref.read(notificationServiceProvider).showTestNotification();
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
                value: 'test_notif',
                child: ListTile(
                  leading: Icon(Icons.notifications_active),
                  title: Text('Test Notification'),
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
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (items.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: Theme.of(context).brightness == Brightness.dark
                      ? 0.6
                      : 0.5,
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
            // Bottom Scrim for readability and safe area
            if (Theme.of(context).brightness == Brightness.dark)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 150,
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
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: 180.0 + MediaQuery.paddingOf(context).top,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
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
                                  child: const Text(
                                    'Tap here to load initial data',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        FadeInUp(
                          delay: const Duration(milliseconds: 200),
                          child: Column(
                            children: [
                              _buildSection(
                                title: 'Vocabulary & Flashcards',
                                icon: Icons.menu_book_rounded,
                                initiallyExpanded: true,
                                children: [
                                  _buildGridButton(
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
                                  _buildGridButton(
                                    context: context,
                                    label: 'Start Quiz',
                                    icon: Icons.quiz_rounded,
                                    bgColor: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                  _buildGridButton(
                                    context: context,
                                    label: 'Vocab Quiz',
                                    icon: Icons.local_fire_department_rounded,
                                    bgColor: Colors.amber.shade700,
                                    fgColor: Colors.white,
                                    onPressed: items.isEmpty || _isLoading
                                        ? null
                                        : (offset) {
                                            _pushScreen(
                                              const QuizScreen(
                                                isVocabularyQuiz: true,
                                              ),
                                              offset,
                                            ).then((_) => setState(() {}));
                                          },
                                  ),
                                ],
                              ),
                              _buildSection(
                                title: 'Grammar & Verbs',
                                icon: Icons.school_rounded,
                                children: [
                                  _buildGridButton(
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
                                  _buildGridButton(
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
                                  _buildGridButton(
                                    context: context,
                                    label: 'Prepositions',
                                    icon: Icons.link_rounded,
                                    bgColor: Colors.pink.shade700,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const PrepositionQuizScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Grammar Rules',
                                    icon: Icons.menu_book_rounded,
                                    bgColor: Colors.blue.shade700,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const GrammarQuizScreen(),
                                        offset,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              _buildSection(
                                title: 'Practice & Exercises',
                                icon: Icons.assignment_rounded,
                                children: [
                                  _buildGridButton(
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
                                  _buildGridButton(
                                    context: context,
                                    label: 'Sentence Builder',
                                    icon: Icons.reorder_rounded,
                                    bgColor: Colors.indigo,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const ExerciseScreen(
                                          unitName:
                                              'Unit 10: Word Order & Pronouns',
                                          unitPath:
                                              'assets/data/exercises/unit_10.json',
                                        ),
                                        offset,
                                      );
                                    },
                                  ),
                                  _buildGridButton(
                                    context: context,
                                    label: 'Question Builder',
                                    icon: Icons.chat_rounded,
                                    bgColor: Colors.lightBlue.shade600,
                                    fgColor: Colors.white,
                                    onPressed: (offset) {
                                      _pushScreen(
                                        const ExerciseScreen(
                                          unitName:
                                              'Question Builder: Make the Question',
                                          unitPath:
                                              'assets/data/exercises/question_builder.json',
                                        ),
                                        offset,
                                      );
                                    },
                                  ),
                                ],
                              ),
                              _buildSection(
                                title: 'Speaking & Phrases',
                                icon: Icons.mic_rounded,
                                children: [
                                  _buildGridButton(
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
                                  _buildGridButton(
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
                                  _buildGridButton(
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
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _scrollController,
                builder: (context, child) {
                  double offset = 0.0;
                  if (_scrollController.hasClients) {
                    offset = _scrollController.offset;
                  }
                  final topPadding = MediaQuery.paddingOf(context).top;
                  final minExtent = 85.0 + topPadding;
                  final maxExtent = 180.0 + topPadding;
                  final currentHeight = (maxExtent - offset).clamp(
                    minExtent,
                    maxExtent,
                  );
                  final shrinkPercentage = (offset / (maxExtent - minExtent))
                      .clamp(0.0, 1.0);

                  return _PinnedStatsCard(
                    progress: progress,
                    topPadding: topPadding,
                    shrinkPercentage: shrinkPercentage,
                    currentHeight: currentHeight,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatsScreen(),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'listenRepeat',
            onPressed: () {
              final RenderBox? renderBox =
                  _fabKey.currentContext?.findRenderObject() as RenderBox?;
              Offset? center;
              if (renderBox != null) {
                final position = renderBox.localToGlobal(Offset.zero);
                center =
                    position +
                    Offset(renderBox.size.width / 2, renderBox.size.height / 2);
              }
              _pushScreen(const ListenRepeatScreen(), center);
            },
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            child: const Icon(Icons.headset_rounded),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            key: _fabKey,
            onPressed: () {
              final RenderBox? renderBox =
                  _fabKey.currentContext?.findRenderObject() as RenderBox?;
              Offset? center;
              if (renderBox != null) {
                final position = renderBox.localToGlobal(Offset.zero);
                center =
                    position +
                    Offset(renderBox.size.width / 2, renderBox.size.height / 2);
              }
              _pushScreen(const QuizScreen(isLuckyQuiz: true), center);
            },
            backgroundColor: Colors.amber.shade700,
            foregroundColor: Colors.white,
            child: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 4,
      color: isDark
          ? Colors.black.withValues(alpha: 0.3)
          : Colors.white.withValues(alpha: 0.85),
      shadowColor: isDark ? Colors.transparent : Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: _buildSectionContent(
          title: title,
          icon: icon,
          children: children,
          initiallyExpanded: initiallyExpanded,
          isDark: isDark,
        ),
      ),
    );
  }

  Widget _buildSectionContent({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool initiallyExpanded,
    required bool isDark,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        listTileTheme: ListTileThemeData(
          dense: true,
          visualDensity: VisualDensity.compact,
          iconColor: isDark ? Colors.white : Colors.black87,
        ),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        iconColor: isDark ? Colors.white : Colors.black87,
        collapsedIconColor: isDark ? Colors.white70 : Colors.black54,
        leading: Icon(icon, color: isDark ? Colors.white : Colors.black87),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        childrenPadding: EdgeInsets.zero,
        children: [
          GridView.count(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: children,
          ),
        ],
      ),
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
    return Card(
      elevation: 2,
      color: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
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
    );
  }
}

class _PinnedStatsCard extends StatelessWidget {
  final ProgressSnapshot progress;
  final VoidCallback onTap;
  final double topPadding;
  final double shrinkPercentage;
  final double currentHeight;

  const _PinnedStatsCard({
    required this.progress,
    required this.onTap,
    required this.topPadding,
    required this.shrinkPercentage,
    required this.currentHeight,
  });

  @override
  Widget build(BuildContext context) {
    final clampedShrink = shrinkPercentage.clamp(0.0, 1.0);

    final expandedOpacity = (1.0 - clampedShrink * 2).clamp(0.0, 1.0);
    final collapsedOpacity = ((clampedShrink - 0.5) * 2).clamp(0.0, 1.0);

    return SizedBox(
      height: currentHeight,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            20,
            topPadding + 20 * (1 - clampedShrink),
            20,
            10,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade400.withValues(
                  alpha: 0.9 + 0.1 * clampedShrink,
                ),
                Colors.deepPurple.shade700.withValues(
                  alpha: 0.9 + 0.1 * clampedShrink,
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
                color: Colors.black.withValues(
                  alpha: 0.15 + 0.2 * clampedShrink,
                ),
                blurRadius: 15 - 5 * clampedShrink,
                offset: Offset(0, 8 - 4 * clampedShrink),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (expandedOpacity > 0.0)
                Opacity(
                  opacity: expandedOpacity,
                  child: OverflowBox(
                    maxHeight: 180.0 + topPadding,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: progress.currentStreak > 0
                                      ? Colors.deepOrange.shade300
                                      : Colors.white38,
                                  size: 22,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${progress.currentStreak}-day streak',
                                  style: TextStyle(
                                    color: progress.currentStreak > 0
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${progress.todayXP}/${progress.dailyGoal} XP',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: progress.dailyGoalProgress,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress.dailyGoalMet
                                  ? Colors.greenAccent.shade400
                                  : Colors.amber.shade300,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(5, (tier) {
                            final count =
                                progress.masteryDistribution[tier] ?? 0;
                            final tierColors = [
                              Colors.white38,
                              Colors.blue.shade200,
                              Colors.cyan.shade200,
                              Colors.orange.shade200,
                              Colors.greenAccent.shade200,
                            ];
                            return Column(
                              children: [
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    color: tierColors[tier],
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  WordProgress.tierName(tier),
                                  style: TextStyle(
                                    color: tierColors[tier].withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total XP: ${progress.totalXP}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Sessions today: ${progress.todaySessions}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white38,
                                  size: 16,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (collapsedOpacity > 0.0)
                Opacity(
                  opacity: collapsedOpacity,
                  child: Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: progress.currentStreak > 0
                                  ? Colors.deepOrange.shade300
                                  : Colors.white38,
                              size: 22,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${progress.currentStreak}',
                              style: TextStyle(
                                color: progress.currentStreak > 0
                                    ? Colors.white
                                    : Colors.white54,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${progress.todayXP}/${progress.dailyGoal} XP',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: LinearProgressIndicator(
                                    value: progress.dailyGoalProgress,
                                    minHeight: 6,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.15,
                                    ),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress.dailyGoalMet
                                          ? Colors.greenAccent.shade400
                                          : Colors.amber.shade300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          '${progress.totalXP} Total',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
