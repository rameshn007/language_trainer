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
import 'widgets/home_screen_background.dart';
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
  int _bgRefreshToken = 0;

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
    setState(() {
      _isLoading = false;
      _bgRefreshToken++;
    });
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
      setState(() {
        _bgRefreshToken++;
      });
    }
  }

  Future<T?> _pushScreen<T>(Widget screen, [Offset? center]) async {
    final result = await Navigator.push<T>(
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
    if (mounted) {
      setState(() {
        _bgRefreshToken++;
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(storageServiceProvider);
    final items = storage.getAllItems();
    final progress = ref.watch(progressServiceProvider);
    final isDuo = IPhoneDuoHelper.isDuo(context);
    final contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
    final appBarRightPadding = IPhoneDuoHelper.getAppBarActionsRightPadding(
      context,
    );
    final fabLocation = IPhoneDuoHelper.getFabLocation(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pills = _getPills(context, items, _isLoading);
    final displaySections = _getDisplaySections(
      context: context,
      items: items,
      isLoading: _isLoading,
      selectedCategory: _selectedCategory,
    );

    return Scaffold(
      extendBody: true,
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Language Trainer'),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: appBarRightPadding),
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
            Positioned.fill(
              child: HomeScreenBackground(refreshToken: _bgRefreshToken),
            ),
            if (isLandscape)
              _buildLandscapeBody(
                context: context,
                items: items,
                progress: progress,
                isDuo: isDuo,
                isDark: isDark,
                contentPadding: contentPadding,
                pills: pills,
                displaySections: displaySections,
              )
            else
              _buildPortraitBody(
                context: context,
                items: items,
                progress: progress,
                isDuo: isDuo,
                isDark: isDark,
                contentPadding: contentPadding,
                pills: pills,
                displaySections: displaySections,
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
    required List<_CategoryFilterItem> pills,
    required List<_CategoryData> displaySections,
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
    final leftRailWidth = (availableTotalWidth * 0.35).clamp(230.0, 280.0);
    const gap = 16.0;
    final rightAvailableWidth = availableTotalWidth - leftRailWidth - gap;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        contentPadding.left,
        10,
        contentPadding.right,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCategoryPills(pills: pills, isDark: isDark),
          const SizedBox(height: 10),
          Expanded(
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
                                  child: const Text(
                                    'Tap here to load initial data',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final cat = displaySections[index];
                            return _buildCategorySection(
                              context: context,
                              title: cat.title,
                              icon: cat.icon,
                              accentColor: cat.accentColor,
                              exercises: cat.exercises,
                              isDark: isDark,
                              availableWidth: rightAvailableWidth,
                              actionLabel: cat.actionLabel,
                              onActionTap: cat.onActionTap,
                            );
                          }, childCount: displaySections.length),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
                    ],
                  ),
                ),
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
    required List<_CategoryFilterItem> pills,
    required List<_CategoryData> displaySections,
  }) {
    final view = View.maybeOf(context);
    final fallbackWidth = view != null && view.devicePixelRatio > 0
        ? view.physicalSize.width / view.devicePixelRatio
        : 375.0;
    final screenWidth = MediaQuery.sizeOf(context).width > 0
        ? MediaQuery.sizeOf(context).width
        : fallbackWidth;
    final availableWidth =
        screenWidth - contentPadding.left - contentPadding.right;

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            const SliverPadding(padding: EdgeInsets.only(top: 172.0)),
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCategoryPills(
                            pills: pills,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          ...displaySections.map(
                            (cat) => _buildCategorySection(
                              context: context,
                              title: cat.title,
                              icon: cat.icon,
                              accentColor: cat.accentColor,
                              exercises: cat.exercises,
                              isDark: isDark,
                              availableWidth: availableWidth,
                              actionLabel: cat.actionLabel,
                              onActionTap: cat.onActionTap,
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
              final currentHeight = (maxExtent - offset).clamp(
                minExtent,
                maxExtent,
              );
              final shrinkPercentage = (offset / (maxExtent - minExtent)).clamp(
                0.0,
                1.0,
              );

              return _PinnedStatsCard(
                progress: progress,
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

  Widget _buildCategoryPills({
    required List<_CategoryFilterItem> pills,
    required bool isDark,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: pills.map((pill) {
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44.0),
              child: Center(
                widthFactor: 1.0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
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
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
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
              ),
            ),
          ),
        );
      }).toList(),
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
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scale = textScaler.scale(1.0);
    final effectiveWidth = math.max(60.0, availableWidth);
    // 1 column on narrow viewports (<340pt) or large text scales (>1.25x);
    // 3 columns on tablet/desktop/DeX widths (>=600pt); 2 columns on standard phones.
    final int crossAxisCount = (effectiveWidth < 340 || scale > 1.25)
        ? 1
        : (effectiveWidth >= 600 && scale <= 1.15 ? 3 : 2);
    const double cardSpacing = 10.0;
    final double cardHeight = scale > 1.5 ? 94.0 : (scale > 1.2 ? 86.0 : 72.0);

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
    } else if (crossAxisCount == 2) {
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
              if (second != null) ...[
                const SizedBox(width: cardSpacing),
                Expanded(
                  child: SizedBox(
                    height: cardHeight,
                    child: _buildActionCard(
                      context: context,
                      item: second,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }
    } else {
      for (int i = 0; i < exercises.length; i += 3) {
        if (i > 0) cardRows.add(const SizedBox(height: cardSpacing));
        final chunk = exercises.sublist(i, math.min(i + 3, exercises.length));
        cardRows.add(
          Row(
            children: [
              for (int j = 0; j < chunk.length; j++) ...[
                if (j > 0) const SizedBox(width: cardSpacing),
                Expanded(
                  child: SizedBox(
                    height: cardHeight,
                    child: _buildActionCard(
                      context: context,
                      item: chunk[j],
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
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
            padding: const EdgeInsets.only(bottom: 10.0, left: 2.0, right: 2.0),
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
                if (actionLabel != null && onActionTap != null) ...[
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (availableWidth * 0.45).clamp(60.0, 140.0),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onActionTap,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  actionLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: accentColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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

    const fgColor = Colors.white;
    final subtitleColor = Colors.white.withValues(alpha: 0.92);
    final iconBoxColor = Colors.white.withValues(alpha: 0.22);
    final chevronColor = Colors.white.withValues(alpha: 0.70);

    return Card(
      key: ValueKey(item.id),
      elevation: isEnabled ? 2 : 0,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      color: isEnabled
          ? item.color
          : (isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.grey.shade300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isEnabled
              ? Colors.white.withValues(alpha: 0.22)
              : Colors.transparent,
          width: 1.1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTapUp: isEnabled
            ? (details) => item.onPressed!(details.globalPosition)
            : null,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isEnabled
                  ? [item.color.withValues(alpha: 0.88), item.color]
                  : [
                      Colors.grey.shade500.withValues(alpha: 0.6),
                      Colors.grey.shade600.withValues(alpha: 0.7),
                    ],
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isEnabled ? iconBoxColor : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: isEnabled ? fgColor : Colors.white38,
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isEnabled
                                    ? fgColor
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.badge!,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: isEnabled
                              ? subtitleColor
                              : (isDark ? Colors.white24 : Colors.black26),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isEnabled ? chevronColor : Colors.transparent,
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
            MaterialPageRoute(builder: (context) => const StatsScreen()),
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
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: _StatsCardContent(progress: progress),
          ),
        ),
      ),
    );
  }

  List<_CategoryFilterItem> _getPills(
    BuildContext context,
    List<LanguageItem> items,
    bool isLoading,
  ) {
    return const [
      _CategoryFilterItem(
        id: 'all',
        label: 'All',
        icon: Icons.auto_awesome_mosaic_rounded,
        count: 18,
      ),
      _CategoryFilterItem(
        id: 'exercises',
        label: 'Exercises',
        icon: Icons.assignment_rounded,
        count: 19,
      ),
      _CategoryFilterItem(
        id: 'topics',
        label: 'Topics',
        icon: Icons.category_rounded,
        count: 13,
      ),
      _CategoryFilterItem(
        id: 'vocab',
        label: 'Vocabulary',
        icon: Icons.menu_book_rounded,
        count: 4,
      ),
      _CategoryFilterItem(
        id: 'grammar',
        label: 'Grammar',
        icon: Icons.school_rounded,
        count: 5,
      ),
      _CategoryFilterItem(
        id: 'speaking',
        label: 'Speaking',
        icon: Icons.mic_rounded,
        count: 4,
      ),
    ];
  }

  List<_CategoryData> _getDisplaySections({
    required BuildContext context,
    required List<LanguageItem> items,
    required bool isLoading,
    required String selectedCategory,
  }) {
    // ── Exercise Units ──
    final sentenceBuilder = _ExerciseItem(
      id: 'ex_unit_10',
      title: 'Sentence Builder',
      subtitle: 'Unit 10: Word Order & Pronouns',
      icon: Icons.reorder_rounded,
      color: Colors.indigo.shade600,
      badge: 'Unit 10',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 10: Word Order & Pronouns',
            unitPath: 'assets/data/exercises/unit_10.json',
          ),
          offset,
        );
      },
    );

    final questionBuilder = _ExerciseItem(
      id: 'ex_question_builder',
      title: 'Question Builder',
      subtitle: 'Make questions with interrogatives',
      icon: Icons.chat_rounded,
      color: Colors.lightBlue.shade700,
      badge: 'Questions',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Question Builder: Make the Question',
            unitPath: 'assets/data/exercises/question_builder.json',
          ),
          offset,
        );
      },
    );

    final verbConjugationQuiz = _ExerciseItem(
      id: 'ex_verb_quiz',
      title: 'Verb Conjugation Quiz',
      subtitle: 'Practice all verb conjugations',
      icon: Icons.school_rounded,
      color: Colors.purple.shade600,
      badge: 'All Verbs',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Verb Conjugation Quiz',
            unitPath: 'assets/data/exercises/verb_conjugation_quiz.json',
          ),
          offset,
        );
      },
    );

    final prepositionalPronouns = _ExerciseItem(
      id: 'ex_prep_pronouns',
      title: 'Prepositional Pronouns',
      subtitle: 'Comigo, contigo, connosco...',
      icon: Icons.link_rounded,
      color: Colors.pink.shade700,
      badge: 'Pronouns',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Prepositional Pronouns',
            unitPath: 'assets/data/exercises/prepositional_pronouns.json',
          ),
          offset,
        );
      },
    );

    final indirectObjectPronouns = _ExerciseItem(
      id: 'ex_indirect_obj',
      title: 'Indirect Pronouns',
      subtitle: 'Me, te, lhe, nos, vos, lhes',
      icon: Icons.contact_mail_rounded,
      color: Colors.cyan.shade700,
      badge: 'Pronouns',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Indirect Object Pronouns',
            unitPath: 'assets/data/exercises/indirect_object_pronouns.json',
          ),
          offset,
        );
      },
    );

    final conjunctions = _ExerciseItem(
      id: 'ex_conjunctions',
      title: 'Conjunctions & Connectors',
      subtitle: 'Quando, Porque, Mas, E',
      icon: Icons.alt_route_rounded,
      color: Colors.orange.shade700,
      badge: 'Connectors',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Conjunctions: Quando, Porque, Mas, E',
            unitPath: 'assets/data/exercises/unit_conjunctions.json',
          ),
          offset,
        );
      },
    );

    final comparatives = _ExerciseItem(
      id: 'ex_comparatives',
      title: 'Comparatives & Duration',
      subtitle: 'Tão... como, há vs desde',
      icon: Icons.compare_arrows_rounded,
      color: Colors.deepOrange.shade600,
      badge: 'Unit 11',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 11: Comparatives, Time & Life Events',
            unitPath:
                'assets/data/exercises/unit_comparatives_and_duration.json',
          ),
          offset,
        );
      },
    );

    final sentenceTransformations = _ExerciseItem(
      id: 'ex_sentence_trans',
      title: 'Transformations & Syntax',
      subtitle: 'Future tense & comparatives',
      icon: Icons.transform_rounded,
      color: Colors.deepPurple.shade700,
      badge: 'Advanced',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Sentence Transformations & Grammar',
            unitPath: 'assets/data/exercises/unit_sentence_transformations.json',
          ),
          offset,
        );
      },
    );

    final unit2IrregularVerbs = _ExerciseItem(
      id: 'ex_unit_2',
      title: 'Irregular Verbs (Pt 1)',
      subtitle: 'Sentir, Dormir, etc. (Unit 2)',
      icon: Icons.school_rounded,
      color: Colors.deepPurple.shade600,
      badge: 'Unit 2',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 2: Irregular Verbs (Part 1)',
            unitPath: 'assets/data/exercises/unit_2.json',
            hintPath: 'assets/images/unit_2_hint.png',
          ),
          offset,
        );
      },
    );

    final unit3Ser = _ExerciseItem(
      id: 'ex_unit_3',
      title: 'Verbo Ser vs Ficar',
      subtitle: 'Identity vs Location (Unit 3)',
      icon: Icons.person_rounded,
      color: Colors.blue.shade700,
      badge: 'Unit 3',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 3: Verbo Ser',
            unitPath: 'assets/data/exercises/unit_3.json',
            hintPath: 'assets/images/unit_3_hint.png',
          ),
          offset,
        );
      },
    );

    final unit4IrregularVerbs = _ExerciseItem(
      id: 'ex_unit_4',
      title: 'Irregular Verbs (Pt 2)',
      subtitle: 'Ter, Ver, Fazer, Dizer (Unit 4)',
      icon: Icons.build_rounded,
      color: Colors.indigo.shade700,
      badge: 'Unit 4',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 4: Irregular Verbs (Part 2)',
            unitPath: 'assets/data/exercises/unit_4.json',
            hintPath: 'assets/images/unit_4_hint.png',
          ),
          offset,
        );
      },
    );

    final unit5RegularVerbs = _ExerciseItem(
      id: 'ex_unit_5',
      title: 'Regular Verbs',
      subtitle: 'Presente: -ar, -er, -ir (Unit 5)',
      icon: Icons.forum_rounded,
      color: Colors.teal.shade700,
      badge: 'Unit 5',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 5: Regular Verbs',
            unitPath: 'assets/data/exercises/unit_5.json',
            hintPath: 'assets/images/unit_5_hint.png',
          ),
          offset,
        );
      },
    );

    final unit12Rooms = _ExerciseItem(
      id: 'ex_unit_12',
      title: 'Rooms in the House',
      subtitle: 'Cozinha, sala, quarto (Unit 12)',
      icon: Icons.home_rounded,
      color: Colors.green.shade700,
      badge: 'Unit 12',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 12: Rooms in the House',
            unitPath: 'assets/data/exercises/unit_rooms_in_the_house.json',
          ),
          offset,
        );
      },
    );

    final unit13HouseholdItems = _ExerciseItem(
      id: 'ex_unit_13',
      title: 'Household Items',
      subtitle: 'Frigorífico, loiça, utensílios',
      icon: Icons.kitchen_rounded,
      color: Colors.teal.shade600,
      badge: 'Unit 13',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 13: Household Items & Appliances',
            unitPath: 'assets/data/exercises/unit_household_items.json',
          ),
          offset,
        );
      },
    );

    final unit14BodyHealth = _ExerciseItem(
      id: 'ex_unit_14',
      title: 'Body Parts & Health',
      subtitle: 'Corpo humano, dores, sintomas',
      icon: Icons.health_and_safety_rounded,
      color: Colors.red.shade700,
      badge: 'Unit 14',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 14: Parts of the Body & Health',
            unitPath: 'assets/data/exercises/unit_body_parts_and_health.json',
          ),
          offset,
        );
      },
    );

    final unit15EverydayItems = _ExerciseItem(
      id: 'ex_unit_15',
      title: 'Everyday Items',
      subtitle: 'Telemóvel, chaves, carteira',
      icon: Icons.backpack_rounded,
      color: Colors.amber.shade800,
      badge: 'Unit 15',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 15: Everyday Items & Belongings',
            unitPath: 'assets/data/exercises/unit_everyday_items.json',
          ),
          offset,
        );
      },
    );

    final unit6NewVocab = _ExerciseItem(
      id: 'ex_unit_6',
      title: 'New Vocabulary',
      subtitle: 'Practice words from new.md',
      icon: Icons.menu_book_rounded,
      color: Colors.blue.shade600,
      badge: 'Unit 6',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 6: New Vocabulary',
            unitPath: 'assets/data/exercises/unit_6.json',
          ),
          offset,
        );
      },
    );

    final unit7MoreVocab = _ExerciseItem(
      id: 'ex_unit_7',
      title: 'More Vocabulary',
      subtitle: 'From Even_More_words.md',
      icon: Icons.auto_stories_rounded,
      color: Colors.blue.shade800,
      badge: 'Unit 7',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 7: Even More Vocabulary',
            unitPath: 'assets/data/exercises/unit_7.json',
          ),
          offset,
        );
      },
    );

    final unit8MonVocab = _ExerciseItem(
      id: 'ex_unit_8',
      title: 'Weekly Vocabulary',
      subtitle: 'New words & related phrases',
      icon: Icons.library_books_rounded,
      color: Colors.indigo.shade800,
      badge: 'Unit 8',
      onPressed: (offset) {
        _pushScreen(
          const ExerciseScreen(
            unitName: 'Unit 8: Monday Mar 9 Vocabulary',
            unitPath: 'assets/data/exercises/unit_8.json',
          ),
          offset,
        );
      },
    );

    final allExercisesCard = _ExerciseItem(
      id: 'ex_all_list',
      title: 'All Units Directory',
      subtitle: 'Browse all 18 units in list view',
      icon: Icons.view_list_rounded,
      color: Theme.of(context).colorScheme.secondary,
      badge: 'All 18',
      onPressed: (offset) {
        _pushScreen(const ExerciseListScreen(), offset);
      },
    );

    // ── Topic Items ──
    final topicFood = _ExerciseItem(
      id: 'topic_food',
      title: 'Food & Drink',
      subtitle: 'Meals, dining & groceries',
      icon: Icons.restaurant_rounded,
      color: Colors.amber.shade700,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'Food & Drink'), offset);
            },
    );

    final topicHouse = _ExerciseItem(
      id: 'topic_house',
      title: 'House & Rooms',
      subtitle: 'Divisões da casa & mobília',
      icon: Icons.home_rounded,
      color: Colors.green.shade700,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'House & Rooms'), offset);
            },
    );

    final topicTravel = _ExerciseItem(
      id: 'topic_travel',
      title: 'Travel & Directions',
      subtitle: 'Transport, city & navigation',
      icon: Icons.explore_rounded,
      color: Colors.cyan.shade700,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(
                const QuizScreen(category: 'Travel & Directions'),
                offset,
              );
            },
    );

    final topicHealth = _ExerciseItem(
      id: 'topic_health',
      title: 'Body & Health',
      subtitle: 'Anatomy, symptoms & care',
      icon: Icons.health_and_safety_rounded,
      color: Colors.red.shade600,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'Body & Health'), offset);
            },
    );

    final topicFamily = _ExerciseItem(
      id: 'topic_family',
      title: 'Family & People',
      subtitle: 'Relatives & personal status',
      icon: Icons.family_restroom_rounded,
      color: Colors.pink.shade600,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'Family'), offset);
            },
    );

    final topicTime = _ExerciseItem(
      id: 'topic_time',
      title: 'Time & Numbers',
      subtitle: 'Hours, dates, calendar & math',
      icon: Icons.schedule_rounded,
      color: Colors.purple.shade600,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'Time & Numbers'), offset);
            },
    );

    final topicEveryday = _ExerciseItem(
      id: 'topic_everyday',
      title: 'Everyday Items',
      subtitle: 'Keys, phone, wallet, bags',
      icon: Icons.backpack_rounded,
      color: Colors.orange.shade700,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'Everyday Items'), offset);
            },
    );

    final topicHousehold = _ExerciseItem(
      id: 'topic_household',
      title: 'Household Items',
      subtitle: 'Appliances, utensils & tools',
      icon: Icons.kitchen_rounded,
      color: Colors.teal.shade700,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(
                const QuizScreen(category: 'Household Items'),
                offset,
              );
            },
    );

    final topicWork = _ExerciseItem(
      id: 'topic_work',
      title: 'Office & Work',
      subtitle: 'Professions & workplace',
      icon: Icons.work_rounded,
      color: Colors.blue.shade700,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'Office & Work'), offset);
            },
    );

    final topicHobbies = _ExerciseItem(
      id: 'topic_hobbies',
      title: 'Hobbies & Leisure',
      subtitle: 'Sports, leisure & culture',
      icon: Icons.sports_tennis_rounded,
      color: Colors.indigo.shade600,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(
                const QuizScreen(category: 'Hobbies & Leisure'),
                offset,
              );
            },
    );

    final topicBasics = _ExerciseItem(
      id: 'topic_basics',
      title: 'Basics & Greetings',
      subtitle: 'Essential daily responses',
      icon: Icons.chat_bubble_outline_rounded,
      color: Colors.blue.shade600,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'Basics'), offset);
            },
    );

    final topicGrammarVerbs = _ExerciseItem(
      id: 'topic_grammar_verbs',
      title: 'Grammar & Verbs',
      subtitle: 'Syntax, tenses & conjugations',
      icon: Icons.school_rounded,
      color: Colors.deepPurple.shade600,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(
                const QuizScreen(category: 'Grammar & Verbs'),
                offset,
              );
            },
    );

    final topicGeneral = _ExerciseItem(
      id: 'topic_general',
      title: 'General Mix',
      subtitle: 'Comprehensive multi-topic test',
      icon: Icons.grid_view_rounded,
      color: Colors.blueGrey.shade700,
      badge: 'Quiz',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(category: 'General'), offset);
            },
    );

    final topicGridPicker = _ExerciseItem(
      id: 'topic_all_grid',
      title: 'Select Topic Grid',
      subtitle: 'Full grid category selector',
      icon: Icons.category_rounded,
      color: Theme.of(context).colorScheme.primary,
      badge: 'Grid',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const CategorySelectionScreen(), offset);
            },
    );

    // ── Fast Practice ──
    final fastVocabQuiz = _ExerciseItem(
      id: 'fast_vocab_quiz',
      title: 'Vocab Quiz',
      subtitle: 'Rapid-fire 10-Q challenge',
      icon: Icons.local_fire_department_rounded,
      color: Colors.amber.shade700,
      badge: 'Rapid',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(isVocabularyQuiz: true), offset);
            },
    );

    final fastListenRepeat = _ExerciseItem(
      id: 'fast_listen_repeat',
      title: 'Listen & Repeat',
      subtitle: 'Hands-free ear training',
      icon: Icons.headset_rounded,
      color: Colors.indigo.shade600,
      badge: 'Audio',
      onPressed: (offset) {
        _pushScreen(const ListenRepeatScreen(), offset);
      },
    );

    final fastLuckyQuiz = _ExerciseItem(
      id: 'fast_lucky_quiz',
      title: 'Lucky Challenge',
      subtitle: 'Smart adaptive practice',
      icon: Icons.auto_awesome_rounded,
      color: Colors.purple.shade600,
      badge: 'Adaptive',
      onPressed: (offset) {
        _pushScreen(const QuizScreen(isLuckyQuiz: true), offset);
      },
    );

    final fastVoiceTrainer = _ExerciseItem(
      id: 'fast_voice_trainer',
      title: 'Voice Trainer',
      subtitle: 'Speech & pronunciation',
      icon: Icons.mic_rounded,
      color: Colors.deepOrange.shade600,
      badge: 'Speak',
      onPressed: (offset) {
        _pushScreen(const VoiceTrainerScreen(), offset);
      },
    );

    // ── Core Skills ──
    final vocabList = _ExerciseItem(
      id: 'vocab_list',
      title: 'Vocabulary',
      subtitle: 'Browse, search & word graph',
      icon: Icons.book_rounded,
      color: Colors.blue.shade600,
      badge: 'Search',
      onPressed: (offset) {
        _pushScreen(const VocabularyListScreen(), offset);
      },
    );

    final vocabQuizCat = _ExerciseItem(
      id: 'vocab_quiz_cat',
      title: 'Start Quiz',
      subtitle: 'Category multi-choice',
      icon: Icons.quiz_rounded,
      color: Theme.of(context).colorScheme.primary,
      badge: 'Topics',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const CategorySelectionScreen(), offset);
            },
    );

    final vocabQuizQuick = _ExerciseItem(
      id: 'vocab_quiz_quick',
      title: 'Vocab Quiz',
      subtitle: 'Rapid-fire challenge',
      icon: Icons.local_fire_department_rounded,
      color: Colors.amber.shade700,
      badge: 'Rapid',
      onPressed: items.isEmpty || isLoading
          ? null
          : (offset) {
              _pushScreen(const QuizScreen(isVocabularyQuiz: true), offset);
            },
    );

    final vocab100Phrases = _ExerciseItem(
      id: 'vocab_100_phrases',
      title: '100 Phrases',
      subtitle: 'Essential daily phrases',
      icon: Icons.style_rounded,
      color: Colors.teal.shade600,
      badge: 'Daily',
      onPressed: (offset) {
        _pushScreen(const VerbPhraseTrainerScreen(), offset);
      },
    );

    final phraseTrainer = _ExerciseItem(
      id: 'phrase_trainer',
      title: 'Phrase Trainer',
      subtitle: 'Everyday conversation',
      icon: Icons.translate_rounded,
      color: Colors.green.shade700,
      badge: 'Dialogues',
      onPressed: (offset) {
        _pushScreen(const PhraseTrainerScreen(), offset);
      },
    );

    final verbTrainer = _ExerciseItem(
      id: 'verb_trainer',
      title: 'Verb Trainer',
      subtitle: 'Conjugations & tenses',
      icon: Icons.school_rounded,
      color: Colors.purple.shade600,
      badge: 'Verbs',
      onPressed: (offset) {
        _pushScreen(const VerbConjugationScreen(), offset);
      },
    );

    final interrogatives = _ExerciseItem(
      id: 'interrogatives',
      title: 'Interrogatives',
      subtitle: 'Question words & usage',
      icon: Icons.contact_support_rounded,
      color: Colors.cyan.shade700,
      badge: 'Questions',
      onPressed: (offset) {
        _pushScreen(const InterrogativeQuizScreen(), offset);
      },
    );

    final prepositions = _ExerciseItem(
      id: 'prepositions',
      title: 'Prepositions',
      subtitle: 'Rules & connectors',
      icon: Icons.link_rounded,
      color: Colors.pink.shade700,
      badge: 'Rules',
      onPressed: (offset) {
        _pushScreen(const PrepositionQuizScreen(), offset);
      },
    );

    final grammarRules = _ExerciseItem(
      id: 'grammar_rules',
      title: 'Grammar Rules',
      subtitle: 'Essential syntax & tips',
      icon: Icons.menu_book_rounded,
      color: Colors.blue.shade700,
      badge: 'Syntax',
      onPressed: (offset) {
        _pushScreen(const GrammarQuizScreen(), offset);
      },
    );

    final voiceTrainer = _ExerciseItem(
      id: 'voice_trainer',
      title: 'Voice Trainer',
      subtitle: 'Speech & pronunciation',
      icon: Icons.mic_rounded,
      color: Colors.deepOrange.shade600,
      badge: 'Speak',
      onPressed: (offset) {
        _pushScreen(const VoiceTrainerScreen(), offset);
      },
    );

    final speakingListenRepeat = _ExerciseItem(
      id: 'speaking_listen_repeat',
      title: 'Listen & Repeat',
      subtitle: 'Hands-free audio trainer',
      icon: Icons.headset_rounded,
      color: Colors.indigo.shade600,
      badge: 'Audio',
      onPressed: (offset) {
        _pushScreen(const ListenRepeatScreen(), offset);
      },
    );

    // ── Build Sections Depending on Selection ──
    if (selectedCategory == 'exercises') {
      return [
        _CategoryData(
          id: 'ex_section_structure',
          title: 'Sentence & Structure (7 Units)',
          shortTitle: 'Structure',
          icon: Icons.reorder_rounded,
          accentColor: Colors.indigo.shade400,
          exercises: [
            sentenceBuilder,
            questionBuilder,
            prepositionalPronouns,
            indirectObjectPronouns,
            conjunctions,
            comparatives,
            sentenceTransformations,
          ],
        ),
        _CategoryData(
          id: 'ex_section_verbs',
          title: 'Verb Mastery (5 Units)',
          shortTitle: 'Verbs',
          icon: Icons.school_rounded,
          accentColor: Colors.purple.shade400,
          exercises: [
            verbConjugationQuiz,
            unit2IrregularVerbs,
            unit3Ser,
            unit4IrregularVerbs,
            unit5RegularVerbs,
          ],
        ),
        _CategoryData(
          id: 'ex_section_thematic',
          title: 'Thematic Vocabulary Units (7 Units)',
          shortTitle: 'Thematic',
          icon: Icons.home_work_rounded,
          accentColor: Colors.teal.shade400,
          exercises: [
            unit12Rooms,
            unit13HouseholdItems,
            unit14BodyHealth,
            unit15EverydayItems,
            unit6NewVocab,
            unit7MoreVocab,
            unit8MonVocab,
            allExercisesCard,
          ],
        ),
      ];
    }

    if (selectedCategory == 'topics') {
      return [
        _CategoryData(
          id: 'topics_all',
          title: 'Explore by Topic (13 Topics)',
          shortTitle: 'Topics',
          icon: Icons.category_rounded,
          accentColor: Colors.orange.shade500,
          exercises: [
            topicFood,
            topicHouse,
            topicTravel,
            topicHealth,
            topicFamily,
            topicTime,
            topicEveryday,
            topicHousehold,
            topicWork,
            topicHobbies,
            topicBasics,
            topicGrammarVerbs,
            topicGeneral,
            topicGridPicker,
          ],
        ),
      ];
    }

    if (selectedCategory == 'vocab') {
      return [
        _CategoryData(
          id: 'vocab_all',
          title: 'Vocabulary & Flashcards',
          shortTitle: 'Vocabulary',
          icon: Icons.menu_book_rounded,
          accentColor: Colors.blue.shade500,
          exercises: [
            vocabList,
            vocabQuizCat,
            vocabQuizQuick,
            vocab100Phrases,
            phraseTrainer,
          ],
        ),
      ];
    }

    if (selectedCategory == 'grammar') {
      return [
        _CategoryData(
          id: 'grammar_all',
          title: 'Grammar & Verbs',
          shortTitle: 'Grammar',
          icon: Icons.school_rounded,
          accentColor: Colors.purple.shade400,
          exercises: [
            verbTrainer,
            verbConjugationQuiz,
            interrogatives,
            prepositions,
            grammarRules,
            sentenceBuilder,
          ],
        ),
      ];
    }

    if (selectedCategory == 'speaking') {
      return [
        _CategoryData(
          id: 'speaking_all',
          title: 'Speaking & Phrases',
          shortTitle: 'Speaking',
          icon: Icons.mic_rounded,
          accentColor: Colors.deepOrange.shade400,
          exercises: [
            voiceTrainer,
            phraseTrainer,
            vocab100Phrases,
            speakingListenRepeat,
          ],
        ),
      ];
    }

    // Default: 'all' (Streamlined Overview)
    return [
      _CategoryData(
        id: 'fast_practice',
        title: '⚡ Fast Practice',
        shortTitle: 'Fast Practice',
        icon: Icons.bolt_rounded,
        accentColor: Colors.amber.shade600,
        exercises: [
          fastVocabQuiz,
          fastListenRepeat,
          fastLuckyQuiz,
          fastVoiceTrainer,
        ],
      ),
      _CategoryData(
        id: 'exercises_featured',
        title: '🎯 Practice & Exercises',
        shortTitle: 'Exercises',
        icon: Icons.assignment_rounded,
        accentColor: Colors.teal.shade400,
        actionLabel: 'All 18 Units',
        onActionTap: () => setState(() => _selectedCategory = 'exercises'),
        exercises: [
          sentenceBuilder,
          questionBuilder,
          verbConjugationQuiz,
          prepositionalPronouns,
        ],
      ),
      _CategoryData(
        id: 'topics_featured',
        title: '🏷️ Explore Topics',
        shortTitle: 'Topics',
        icon: Icons.category_rounded,
        accentColor: Colors.orange.shade500,
        actionLabel: 'All 13 Topics',
        onActionTap: () => setState(() => _selectedCategory = 'topics'),
        exercises: [
          topicFood,
          topicHouse,
          topicTravel,
          topicHealth,
        ],
      ),
      _CategoryData(
        id: 'vocab_featured',
        title: '📚 Vocabulary & Phrases',
        shortTitle: 'Vocabulary',
        icon: Icons.menu_book_rounded,
        accentColor: Colors.blue.shade500,
        actionLabel: 'View All',
        onActionTap: () => setState(() => _selectedCategory = 'vocab'),
        exercises: [
          vocabList,
          vocab100Phrases,
        ],
      ),
      _CategoryData(
        id: 'grammar_featured',
        title: '🧠 Grammar & Verbs',
        shortTitle: 'Grammar',
        icon: Icons.school_rounded,
        accentColor: Colors.purple.shade400,
        actionLabel: 'View All',
        onActionTap: () => setState(() => _selectedCategory = 'grammar'),
        exercises: [
          verbTrainer,
          grammarRules,
          prepositions,
          interrogatives,
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
  final String? badge;
  final void Function(Offset offset)? onPressed;

  const _ExerciseItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.badge,
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
  final String shortTitle;
  final IconData icon;
  final Color accentColor;
  final List<_ExerciseItem> exercises;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const _CategoryData({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.accentColor,
    required this.exercises,
    this.actionLabel,
    this.onActionTap,
  });
}

class _StatsCardContent extends StatelessWidget {
  final ProgressSnapshot progress;

  const _StatsCardContent({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
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
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
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
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
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
    );
  }
}

class _PinnedStatsCard extends StatelessWidget {
  final ProgressSnapshot progress;
  final VoidCallback onTap;
  final double shrinkPercentage;
  final double currentHeight;
  final bool isDuo;
  final double leftMargin;
  final double rightMargin;

  const _PinnedStatsCard({
    required this.progress,
    required this.onTap,
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
                    child: _StatsCardContent(progress: progress),
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
