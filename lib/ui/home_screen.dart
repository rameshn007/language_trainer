import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../services/markdown_parser.dart';
import '../services/progress_service.dart';
import '../models/progress_data.dart';
import 'quiz/quiz_screen.dart';
import '../main.dart';
import 'widgets/home_screen_background.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import '../services/verb_service.dart';
import '../models/language_item.dart';
import 'listen_repeat/listen_repeat_screen.dart';
import '../utils/iphone_duo_helper.dart';
import 'home_tiles_data.dart';
import 'home_tile_layout.dart';

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
    final sectionsBuilder = HomeSectionsBuilder(
      context: context,
      isQuizDisabled: items.isEmpty || _isLoading,
      pushScreen: _pushScreen,
      selectCategory: (cat) => setState(() => _selectedCategory = cat),
    );
    final pills = sectionsBuilder.getPills();
    final displaySections = sectionsBuilder.getSections(_selectedCategory);

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
    required List<HomeCategoryPill> pills,
    required List<HomeSectionData> displaySections,
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
    required List<HomeCategoryPill> pills,
    required List<HomeSectionData> displaySections,
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
    required List<HomeCategoryPill> pills,
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
    required List<HomeTileItem> exercises,
    required bool isDark,
    required double availableWidth,
    String? actionLabel,
    VoidCallback? onActionTap,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final effectiveWidth = math.max(60.0, availableWidth);
    const double cardSpacing = 10.0;

    // Grid follows the copy: the widest column count in which every tile still
    // gets one full-size line of text. A narrower column would not truncate —
    // text is laid out unbounded inside a FittedBox — it shrinks instead, and
    // two columns on a 430 pt phone shrank this section's copy to ~9 pt.
    final Size textBlock = measureTileTextBlock(exercises, textScaler);
    final int crossAxisCount = chooseTileColumnCount(
      availableWidth: effectiveWidth,
      textWidth: textBlock.width,
      gutter: cardSpacing,
    );
    final double cardHeight = tileCardHeight(textBlock);

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
              // An odd last tile used to sit in a lone Expanded and stretch to
              // the full row width, misaligning it with the paired row above.
              // The empty slot keeps the gutter and the column width.
              const SizedBox(width: cardSpacing),
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : SizedBox(
                        height: cardHeight,
                        child: _buildActionCard(
                          context: context,
                          item: second,
                          isDark: isDark,
                        ),
                      ),
              ),
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
              // Three slots rather than `chunk.length`: a short last row keeps
              // its empty columns so its tiles stay the width of the row above.
              for (int j = 0; j < 3; j++) ...[
                if (j > 0) const SizedBox(width: cardSpacing),
                Expanded(
                  child: j < chunk.length
                      ? SizedBox(
                          height: cardHeight,
                          child: _buildActionCard(
                            context: context,
                            item: chunk[j],
                            isDark: isDark,
                          ),
                        )
                      : const SizedBox.shrink(),
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
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44.0),
                            child: Center(
                              widthFactor: 1.0,
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
    required HomeTileItem item,
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
          padding: const EdgeInsets.symmetric(
            horizontal: tileHorizontalPadding,
            vertical: tileVerticalPadding,
          ),
          child: Row(
            children: [
              Container(
                width: tileIconBox,
                height: tileIconBox,
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
              const SizedBox(width: tileIconTextGap),
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
                                // Design size plus an explicit line height:
                                // `Text` applies the ambient
                                // `MediaQuery.textScaler` itself, and with no
                                // `height` here it also inherits the theme's
                                // `bodyMedium` - neither of which
                                // `measureTileTextBlock` can see, which is how
                                // the tile ended up sized for a shorter block
                                // than it painted.
                                fontSize: tileTitleSize,
                                height: tileLineHeight,
                                fontWeight: FontWeight.bold,
                                color: isEnabled
                                    ? fgColor
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                          ),
                          if (item.badge != null) ...[
                            const SizedBox(width: tileBadgeGap),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: tileBadgePaddingHorizontal,
                                vertical: tileBadgePaddingVertical,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.badge!,
                                style: TextStyle(
                                  fontSize: tileBadgeSize,
                                  height: tileLineHeight,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: tileLineGap),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: tileSubtitleSize,
                          height: tileLineHeight,
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
                size: tileChevronWidth,
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
