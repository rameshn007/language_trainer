import 'dart:convert';
import 'dart:math' as math;
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
import '../utils/iphone_duo_helper.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  final GlobalKey _fabKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _landscapeScrollController = ScrollController();
  String _selectedCategory = 'all';

  @override
  void dispose() {
    _scrollController.dispose();
    _landscapeScrollController.dispose();
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
    final isDuo = IPhoneDuoHelper.isDuo(context);
    final contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
    final appBarRightPadding =
        IPhoneDuoHelper.getAppBarActionsRightPadding(context);
    final fabLocation = IPhoneDuoHelper.getFabLocation(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allCategories = _getCategories(context, items, _isLoading);
    final filteredCategories = _selectedCategory == 'all'
        ? allCategories
        : allCategories.where((c) => c.id == _selectedCategory).toList();

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Language Trainer'),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(
              right: appBarRightPadding,
            ),
            child: PopupMenuButton<String>(
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
          ),
        ],
      ),
      body: SizedBox.expand(
        child: Stack(
          children: [
            if (items.isNotEmpty)
              Positioned.fill(
                child: Opacity(
                  opacity: isDark ? 0.6 : 0.5,
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
            if (isLandscape)
              _buildLandscapeBody(
                context: context,
                items: items,
                progress: progress,
                isDuo: isDuo,
                isDark: isDark,
                contentPadding: contentPadding,
                filteredCategories: filteredCategories,
              )
            else
              _buildPortraitBody(
                context: context,
                items: items,
                progress: progress,
                isDuo: isDuo,
                isDark: isDark,
                contentPadding: contentPadding,
                filteredCategories: filteredCategories,
              ),
          ],
        ),
      ),
      floatingActionButtonLocation: fabLocation,
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

  Widget _buildLandscapeBody({
    required BuildContext context,
    required List<LanguageItem> items,
    required ProgressSnapshot progress,
    required bool isDuo,
    required bool isDark,
    required EdgeInsets contentPadding,
    required List<_CategoryData> filteredCategories,
  }) {
    final view = View.maybeOf(context);
    final fallbackWidth = view != null && view.devicePixelRatio > 0
        ? view.physicalSize.width / view.devicePixelRatio
        : 667.0;
    final screenWidth = MediaQuery.sizeOf(context).width > 0
        ? MediaQuery.sizeOf(context).width
        : fallbackWidth;
    final availableTotalWidth =
        screenWidth - contentPadding.left - contentPadding.right;
    final leftRailWidth =
        (availableTotalWidth * 0.35).clamp(230.0, 280.0);
    const gap = 16.0;
    final rightAvailableWidth = availableTotalWidth - leftRailWidth - gap;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        contentPadding.left,
        10,
        contentPadding.right,
        10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: leftRailWidth,
            child: _buildLandscapeStatsCard(context, progress, isDuo),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: CustomScrollView(
              controller: _landscapeScrollController,
              slivers: [
                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (items.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
                  ),
                SliverToBoxAdapter(
                  child: _buildCategoryPills(isDark),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 14),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cat = filteredCategories[index];
                      return _buildCategorySection(
                        context: context,
                        title: cat.title,
                        icon: cat.icon,
                        accentColor: cat.accentColor,
                        exercises: cat.exercises,
                        isDark: isDark,
                        availableWidth: rightAvailableWidth,
                      );
                    },
                    childCount: filteredCategories.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitBody({
    required BuildContext context,
    required List<LanguageItem> items,
    required ProgressSnapshot progress,
    required bool isDuo,
    required bool isDark,
    required EdgeInsets contentPadding,
    required List<_CategoryData> filteredCategories,
  }) {
    final view = View.maybeOf(context);
    final fallbackWidth = view != null && view.devicePixelRatio > 0
        ? view.physicalSize.width / view.devicePixelRatio
        : 375.0;
    final screenWidth = MediaQuery.sizeOf(context).width > 0
        ? MediaQuery.sizeOf(context).width
        : fallbackWidth;
    final availableWidth = screenWidth -
        contentPadding.left -
        contentPadding.right;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.only(
                top: 172.0,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  contentPadding.left,
                  0,
                  contentPadding.right,
                  80,
                ),
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
                              child: const Text('Tap here to load initial data'),
                            ),
                          ],
                        ),
                      ),
                    FadeInUp(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCategoryPills(isDark),
                          const SizedBox(height: 14),
                          ...filteredCategories.map(
                            (cat) => _buildCategorySection(
                              context: context,
                              title: cat.title,
                              icon: cat.icon,
                              accentColor: cat.accentColor,
                              exercises: cat.exercises,
                              isDark: isDark,
                              availableWidth: availableWidth,
                            ),
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
              if (_scrollController.hasClients &&
                  _scrollController.positions.length == 1) {
                offset = _scrollController.offset;
              }
              const minExtent = 64.0;
              const maxExtent = 162.0;
              final currentHeight =
                  (maxExtent - offset).clamp(minExtent, maxExtent);
              final shrinkPercentage =
                  (offset / (maxExtent - minExtent)).clamp(0.0, 1.0);

              return _PinnedStatsCard(
                progress: progress,
                topPadding: 0.0,
                shrinkPercentage: shrinkPercentage,
                currentHeight: currentHeight,
                isDuo: isDuo,
                leftMargin: contentPadding.left,
                rightMargin: contentPadding.right,
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
    );
  }

  Widget _buildCategoryPills(bool isDark) {
    const pills = [
      _CategoryFilterItem(
        id: 'all',
        label: 'All',
        icon: Icons.auto_awesome_mosaic_rounded,
        count: 13,
      ),
      _CategoryFilterItem(
        id: 'vocab',
        label: 'Vocabulary',
        icon: Icons.menu_book_rounded,
        count: 3,
      ),
      _CategoryFilterItem(
        id: 'grammar',
        label: 'Grammar',
        icon: Icons.school_rounded,
        count: 4,
      ),
      _CategoryFilterItem(
        id: 'practice',
        label: 'Practice',
        icon: Icons.assignment_rounded,
        count: 3,
      ),
      _CategoryFilterItem(
        id: 'speaking',
        label: 'Speaking',
        icon: Icons.mic_rounded,
        count: 3,
      ),
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pill = pills[index];
          final isSelected = _selectedCategory == pill.id;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() {
                  if (_selectedCategory == pill.id && pill.id != 'all') {
                    _selectedCategory = 'all';
                  } else {
                    _selectedCategory = pill.id;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            Colors.deepPurple.shade500,
                            Colors.deepPurple.shade700,
                          ],
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.4)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1)),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      pill.icon,
                      size: 15,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      pill.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pill.count}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white60 : Colors.black54),
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
    );
  }

  Widget _buildCategorySection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<_ExerciseItem> exercises,
    required bool isDark,
    required double availableWidth,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scale = textScaler.scale(1.0);
    final effectiveWidth = math.max(60.0, availableWidth);
    final int crossAxisCount = (effectiveWidth < 340 || scale > 1.25) ? 1 : 2;
    const double cardSpacing = 10.0;
    final double cardHeight =
        scale > 1.5 ? 94.0 : (scale > 1.2 ? 86.0 : 72.0);

    final List<Widget> cardRows = [];
    if (crossAxisCount == 1) {
      for (int i = 0; i < exercises.length; i++) {
        if (i > 0) cardRows.add(const SizedBox(height: cardSpacing));
        cardRows.add(
          SizedBox(
            height: cardHeight,
            width: double.infinity,
            child: _buildActionCard(
              context: context,
              item: exercises[i],
              isDark: isDark,
            ),
          ),
        );
      }
    } else {
      for (int i = 0; i < exercises.length; i += 2) {
        if (i > 0) cardRows.add(const SizedBox(height: cardSpacing));
        final first = exercises[i];
        final second = (i + 1 < exercises.length) ? exercises[i + 1] : null;
        cardRows.add(
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: cardHeight,
                  child: _buildActionCard(
                    context: context,
                    item: first,
                    isDark: isDark,
                  ),
                ),
              ),
              const SizedBox(width: cardSpacing),
              Expanded(
                child: second != null
                    ? SizedBox(
                        height: cardHeight,
                        child: _buildActionCard(
                          context: context,
                          item: second,
                          isDark: isDark,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.only(bottom: 10.0, left: 2.0, right: 2.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...cardRows,
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required _ExerciseItem item,
    required bool isDark,
  }) {
    final bool isEnabled = item.onPressed != null;
    final fgColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;

    return Card(
      elevation: isDark ? 0 : 2,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.grey.shade300,
          width: 1.1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isEnabled ? () {} : null,
        onTapUp: isEnabled
            ? (details) => item.onPressed!(details.globalPosition)
            : null,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isEnabled
                        ? [
                            item.color.withValues(alpha: 0.82),
                            item.color,
                          ]
                        : [
                            Colors.grey.shade400,
                            Colors.grey.shade500,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isEnabled
                      ? [
                          BoxShadow(
                            color: item.color.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isEnabled
                              ? fgColor
                              : fgColor.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w400,
                          color: isEnabled
                              ? subtitleColor
                              : subtitleColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isEnabled
                    ? (isDark ? Colors.white30 : Colors.black26)
                    : Colors.transparent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeStatsCard(
    BuildContext context,
    ProgressSnapshot progress,
    bool isDuo,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StatsScreen(),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade500.withValues(alpha: 0.95),
                Colors.deepPurple.shade800.withValues(alpha: 0.98),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: progress.currentStreak > 0
                                ? Colors.deepOrange.shade300
                                : Colors.white38,
                            size: 20,
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${progress.todayXP}/${progress.dailyGoal} XP',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress.dailyGoalProgress,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress.dailyGoalMet
                        ? Colors.greenAccent.shade400
                        : Colors.amber.shade300,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(5, (tier) {
                  final count = progress.masteryDistribution[tier] ?? 0;
                  final tierColors = [
                    Colors.white38,
                    Colors.blue.shade200,
                    Colors.cyan.shade200,
                    Colors.orange.shade200,
                    Colors.greenAccent.shade200,
                  ];
                  return Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: tierColors[tier],
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            WordProgress.tierName(tier),
                            style: TextStyle(
                              color: tierColors[tier].withValues(alpha: 0.7),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total: ${progress.totalXP} XP',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Stats',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_CategoryData> _getCategories(
    BuildContext context,
    List<LanguageItem> items,
    bool isLoading,
  ) {
    return [
      _CategoryData(
        id: 'vocab',
        title: 'Vocabulary & Flashcards',
        icon: Icons.menu_book_rounded,
        accentColor: Colors.blue.shade500,
        exercises: [
          _ExerciseItem(
            id: 'vocab_list',
            title: 'Vocabulary',
            subtitle: 'Browse & search words',
            icon: Icons.book_rounded,
            color: Colors.blue.shade600,
            onPressed: (offset) {
              _pushScreen(const VocabularyListScreen(), offset);
            },
          ),
          _ExerciseItem(
            id: 'vocab_quiz_cat',
            title: 'Start Quiz',
            subtitle: 'Category multi-choice',
            icon: Icons.quiz_rounded,
            color: Theme.of(context).colorScheme.primary,
            onPressed: items.isEmpty || isLoading
                ? null
                : (offset) {
                    _pushScreen(
                      const CategorySelectionScreen(),
                      offset,
                    ).then((_) => setState(() {}));
                  },
          ),
          _ExerciseItem(
            id: 'vocab_quiz_quick',
            title: 'Vocab Quiz',
            subtitle: 'Rapid-fire challenge',
            icon: Icons.local_fire_department_rounded,
            color: Colors.amber.shade700,
            onPressed: items.isEmpty || isLoading
                ? null
                : (offset) {
                    _pushScreen(
                      const QuizScreen(isVocabularyQuiz: true),
                      offset,
                    ).then((_) => setState(() {}));
                  },
          ),
        ],
      ),
      _CategoryData(
        id: 'grammar',
        title: 'Grammar & Verbs',
        icon: Icons.school_rounded,
        accentColor: Colors.purple.shade400,
        exercises: [
          _ExerciseItem(
            id: 'verb_trainer',
            title: 'Verb Trainer',
            subtitle: 'Conjugations & tenses',
            icon: Icons.school_rounded,
            color: Colors.purple,
            onPressed: (offset) {
              _pushScreen(const VerbConjugationScreen(), offset);
            },
          ),
          _ExerciseItem(
            id: 'interrogatives',
            title: 'Interrogatives',
            subtitle: 'Question words & usage',
            icon: Icons.contact_support_rounded,
            color: Colors.cyan.shade700,
            onPressed: (offset) {
              _pushScreen(const InterrogativeQuizScreen(), offset);
            },
          ),
          _ExerciseItem(
            id: 'prepositions',
            title: 'Prepositions',
            subtitle: 'Rules & connectors',
            icon: Icons.link_rounded,
            color: Colors.pink.shade700,
            onPressed: (offset) {
              _pushScreen(const PrepositionQuizScreen(), offset);
            },
          ),
          _ExerciseItem(
            id: 'grammar_rules',
            title: 'Grammar Rules',
            subtitle: 'Essential syntax & tips',
            icon: Icons.menu_book_rounded,
            color: Colors.blue.shade700,
            onPressed: (offset) {
              _pushScreen(const GrammarQuizScreen(), offset);
            },
          ),
        ],
      ),
      _CategoryData(
        id: 'practice',
        title: 'Practice & Exercises',
        icon: Icons.assignment_rounded,
        accentColor: Colors.teal.shade400,
        exercises: [
          _ExerciseItem(
            id: 'exercises_list',
            title: 'Exercises',
            subtitle: 'Structured practice units',
            icon: Icons.assignment_rounded,
            color: Theme.of(context).colorScheme.secondary,
            onPressed: (offset) {
              _pushScreen(const ExerciseListScreen(), offset);
            },
          ),
          _ExerciseItem(
            id: 'sentence_builder',
            title: 'Sentence Builder',
            subtitle: 'Word order & pronouns',
            icon: Icons.reorder_rounded,
            color: Colors.indigo,
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
          _ExerciseItem(
            id: 'question_builder',
            title: 'Question Builder',
            subtitle: 'Make the question',
            icon: Icons.chat_rounded,
            color: Colors.lightBlue.shade600,
            onPressed: (offset) {
              _pushScreen(
                const ExerciseScreen(
                  unitName: 'Question Builder: Make the Question',
                  unitPath: 'assets/data/exercises/question_builder.json',
                ),
                offset,
              );
            },
          ),
        ],
      ),
      _CategoryData(
        id: 'speaking',
        title: 'Speaking & Phrases',
        icon: Icons.mic_rounded,
        accentColor: Colors.deepOrange.shade400,
        exercises: [
          _ExerciseItem(
            id: 'voice_trainer',
            title: 'Voice Trainer',
            subtitle: 'Speech & pronunciation',
            icon: Icons.mic_rounded,
            color: Colors.deepOrange,
            onPressed: (offset) {
              _pushScreen(const VoiceTrainerScreen(), offset);
            },
          ),
          _ExerciseItem(
            id: 'phrase_trainer',
            title: 'Phrase Trainer',
            subtitle: 'Everyday conversation',
            icon: Icons.translate_rounded,
            color: Colors.green,
            onPressed: (offset) {
              _pushScreen(const PhraseTrainerScreen(), offset);
            },
          ),
          _ExerciseItem(
            id: '100_phrases',
            title: '100 Phrases',
            subtitle: 'Essential daily phrases',
            icon: Icons.style_rounded,
            color: Colors.teal,
            onPressed: (offset) {
              _pushScreen(const VerbPhraseTrainerScreen(), offset);
            },
          ),
        ],
      ),
    ];
  }
}

class _ExerciseItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final void Function(Offset offset)? onPressed;

  const _ExerciseItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onPressed,
  });
}

class _CategoryFilterItem {
  final String id;
  final String label;
  final IconData icon;
  final int count;

  const _CategoryFilterItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.count,
  });
}

class _CategoryData {
  final String id;
  final String title;
  final IconData icon;
  final Color accentColor;
  final List<_ExerciseItem> exercises;

  const _CategoryData({
    required this.id,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.exercises,
  });
}

@visibleForTesting
class SectionContent extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;
  final bool isDark;

  const SectionContent({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    required this.initiallyExpanded,
    required this.isDark,
  });

  @override
  State<SectionContent> createState() => _SectionContentState();
}

class _SectionContentState extends State<SectionContent>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  late Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: _isExpanded ? 1.0 : 0.0,
    );
    _iconTurns = _controller.drive(
      Tween<double>(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeIn)),
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = widget.isDark ? Colors.white : Colors.black87;
    final chevronColor = widget.isDark
        ? (_isExpanded ? Colors.white : Colors.white70)
        : (_isExpanded ? Colors.black87 : Colors.black54);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(widget.icon, color: fgColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RotationTransition(
                  turns: _iconTurns,
                  child: Icon(Icons.expand_more, color: chevronColor),
                ),
              ],
            ),
          ),
        ),
        ClipRect(
          child: AnimatedBuilder(
            animation: _controller.view,
            builder: (context, child) {
              return Align(
                alignment: Alignment.topCenter,
                heightFactor: _heightFactor.value,
                child: child,
              );
            },
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: widget.children,
            ),
          ),
        ),
      ],
    );
  }
}

class _PinnedStatsCard extends StatelessWidget {
  final ProgressSnapshot progress;
  final VoidCallback onTap;
  final double topPadding;
  final double shrinkPercentage;
  final double currentHeight;
  final bool isDuo;
  final double leftMargin;
  final double rightMargin;

  const _PinnedStatsCard({
    required this.progress,
    required this.onTap,
    required this.topPadding,
    required this.shrinkPercentage,
    required this.currentHeight,
    this.isDuo = false,
    this.leftMargin = 20.0,
    this.rightMargin = 20.0,
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
            leftMargin,
            8.0 * (1 - clampedShrink),
            rightMargin,
            8.0,
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
                    maxHeight: 180.0,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${progress.todayXP}/${progress.dailyGoal} XP',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
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
                            return Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: tierColors[tier],
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      WordProgress.tierName(tier),
                                      style: TextStyle(
                                        color: tierColors[tier].withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Total XP: ${progress.totalXP}',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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
                              ),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
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
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${progress.todayXP}/${progress.dailyGoal} XP',
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${progress.totalXP} Total',
                            maxLines: 1,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
