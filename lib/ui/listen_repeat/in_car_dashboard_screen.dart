import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../models/language_item.dart';
import '../../services/carplay_service.dart';
import '../../services/listen_repeat_content_service.dart';
import '../../services/storage_service.dart';
import '../../theme/carplay_theme.dart';
import '../widgets/xp_popup.dart';
import 'listen_repeat_view_model.dart';

import '../../utils/iphone_duo_helper.dart';

/// Pixel-perfect in-car landscape dashboard implementing the Listen & Repeat
/// brand specification and 3-column automotive layout.
class InCarDashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final VoidCallback? onStop;
  final bool embedded;

  const InCarDashboardScreen({
    super.key,
    this.onBack,
    this.onStop,
    this.embedded = false,
  });

  @override
  ConsumerState<InCarDashboardScreen> createState() => _InCarDashboardScreenState();
}

class _InCarDashboardScreenState extends ConsumerState<InCarDashboardScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.embedded) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(listenRepeatViewModelProvider);
      if (!state.isPlaying && state.currentItem == null) {
        ref.read(listenRepeatViewModelProvider.notifier).startSession();
      }
    });
  }

  @override
  void dispose() {
    if (!widget.embedded) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    super.dispose();
  }

  void _stopSessionAndPop() async {
    if (widget.onStop != null) {
      widget.onStop!();
      return;
    }
    final xp = await ref.read(listenRepeatViewModelProvider.notifier).stopSession();
    if (mounted) {
      if (xp > 0) {
        XPPopup.show(context, xp);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listenRepeatViewModelProvider);
    final storage = ref.watch(storageServiceProvider);
    final modeCounts = ref.watch(listenRepeatModeCountsProvider).value ?? {};
    final item = state.currentItem;
    final isFlagged = item != null && storage.isItemFlagged(item.id);
    final notifier = ref.read(listenRepeatViewModelProvider.notifier);
    final isCompact = MediaQuery.sizeOf(context).height < 500;

    return Scaffold(
      backgroundColor: CarPlayTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(context, state, notifier, isCompact: isCompact),

            // Main 3-Column Content
            Expanded(
              child: Builder(
                builder: (context) {
                  final isDuo = IPhoneDuoHelper.isDuo(context);
                  final rightContentPadding = isDuo ? 48.0 : 24.0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      isCompact ? 4 : 8,
                      rightContentPadding,
                      isCompact ? 4 : 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Column: Practice Sets
                        Expanded(
                          flex: 3,
                          child: _buildPracticeSetsColumn(
                            state,
                            notifier,
                            modeCounts,
                            isCompact: isCompact,
                          ),
                        ),

                        const SizedBox(width: 20),

                        // Center Column: Flashcard & Status
                        Expanded(
                          flex: 6,
                          child: _buildCenterCardColumn(
                            state,
                            item,
                            isFlagged,
                            storage,
                            modeCounts,
                            isCompact: isCompact,
                          ),
                        ),

                        const SizedBox(width: 20),

                        // Right Column: Playback Controls
                        Expanded(
                          flex: 3,
                          child: _buildPlaybackControlsColumn(
                            state,
                            notifier,
                            isCompact: isCompact,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    ListenRepeatState state,
    ListenRepeatViewModel notifier, {
    bool isCompact = false,
  }) {
    final isDuo = IPhoneDuoHelper.isDuo(context);
    final topBarRightPadding = isDuo ? 64.0 : 24.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        isCompact ? 4 : 12,
        topBarRightPadding,
        isCompact ? 4 : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Navigation
          InkWell(
            key: const Key('carplay_dash_back_button'),
            borderRadius: BorderRadius.circular(CarPlayTheme.pillRadius),
            onTap: widget.onBack ?? () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    color: CarPlayTheme.fg,
                    size: 28,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Listen & Repeat',
                    style: CarPlayTheme.headerTitle,
                  ),
                ],
              ),
            ),
          ),

          // Header Actions (Speed + Stop)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Speed Indicator
              InkWell(
                key: const Key('carplay_dash_speed_button'),
                borderRadius: BorderRadius.circular(CarPlayTheme.pillRadius),
                onTap: () => notifier.cycleSpeed(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.speed_rounded,
                        color: CarPlayTheme.fg,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${state.playbackSpeed}x',
                        style: const TextStyle(
                          color: CarPlayTheme.fg,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Stop Action
              TextButton(
                key: const Key('carplay_dash_stop_button'),
                onPressed: _stopSessionAndPop,
                child: const Text(
                  'Stop',
                  style: CarPlayTheme.headerAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeSetsColumn(
    ListenRepeatState state,
    ListenRepeatViewModel notifier,
    Map<ListenRepeatMode, int> modeCounts, {
    bool isCompact = false,
  }) {
    const modes = [
      ListenRepeatMode.all,
      ListenRepeatMode.verbs,
      ListenRepeatMode.prepositions,
      ListenRepeatMode.phrases,
      ListenRepeatMode.vocabulary,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: isCompact ? 6 : 12),
          child: const Text(
            'PRACTICE SET',
            style: CarPlayTheme.sectionHeader,
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: modes.length,
            separatorBuilder: (_, _) => SizedBox(height: isCompact ? 6 : 10),
            itemBuilder: (context, index) {
              final mode = modes[index];
              final isSelected = state.mode == mode;
              final wordCount = modeCounts[mode] ??
                  ((isSelected && state.pool.isNotEmpty) ? state.pool.length : 0);
              final countText = wordCount > 0 ? '$wordCount words' : 'Available words';

              return InkWell(
                key: Key('carplay_dash_mode_${mode.name}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => notifier.setMode(mode),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: isCompact ? 8 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: CarPlayTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? CarPlayTheme.accentLine
                          : CarPlayTheme.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: CarPlayTheme.accent.withAlpha(30),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              mode.label,
                              style: CarPlayTheme.cardTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              countText,
                              style: CarPlayTheme.cardSubtitle,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_rounded,
                          color: CarPlayTheme.accent,
                          size: 22,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCenterCardColumn(
    ListenRepeatState state,
    LanguageItem? item,
    bool isFlagged,
    StorageService storage,
    Map<ListenRepeatMode, int> modeCounts, {
    bool isCompact = false,
  }) {
    final int wordsSeen = state.totalWordsSeen;
    final int poolCount = state.pool.isNotEmpty
        ? state.pool.length
        : (modeCounts[state.mode] ?? 0);
    final int currentWordPos = (poolCount > 0 && wordsSeen > 0)
        ? ((wordsSeen - 1) % poolCount) + 1
        : max(1, wordsSeen);
    final int dotCount = poolCount > 0 ? min(poolCount, 12) : 12;
    final int currentDot = (currentWordPos - 1) % dotCount;
    final String counterText = poolCount > 0
        ? 'Word $currentWordPos of $poolCount'
        : 'Word $wordsSeen';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Center Flashcard with Steel-Blue Radial Halo
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CarPlayTheme.cardRadius),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x333B68A8),
                  blurRadius: 48,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                color: CarPlayTheme.surface,
                borderRadius: BorderRadius.circular(CarPlayTheme.cardRadius),
                border: Border.all(color: CarPlayTheme.border, width: 1.5),
              ),
              child: Stack(
                children: [
                  // Star Bookmark Action
                  Positioned(
                    top: isCompact ? 6 : 14,
                    right: isCompact ? 6 : 14,
                    child: IconButton(
                      key: const Key('carplay_dash_star_button'),
                      icon: Icon(
                        isFlagged ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFlagged
                            ? CarPlayTheme.starGold
                            : CarPlayTheme.muted,
                        size: isCompact ? 24 : 28,
                      ),
                      tooltip: isFlagged ? 'Remove bookmark' : 'Flag for review',
                      onPressed: item != null
                          ? () async {
                              final newFlagged = await storage.toggleItemFlagged(item.id);
                              setState(() {});
                              CarPlayService().onItemFlagToggled(item, newFlagged);
                            }
                          : null,
                    ),
                  ),

                  // Main Text Content
                  Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 16 : 28,
                          vertical: isCompact ? 8 : 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Grammar / Tense Pill Badge
                            if (item != null && item.notes.trim().isNotEmpty) ...[
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isCompact ? 10 : 14,
                                  vertical: isCompact ? 3 : 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2E2C3D),
                                  borderRadius: BorderRadius.circular(CarPlayTheme.badgeRadius),
                                  border: Border.all(
                                    color: const Color(0x55B587FA),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  item.notes.trim(),
                                  style: isCompact
                                      ? CarPlayTheme.badgeText.copyWith(fontSize: 11)
                                      : CarPlayTheme.badgeText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(height: isCompact ? 8 : 18),
                            ],

                            // Portuguese Target Phrase
                            Text(
                              item?.portuguese ?? (state.failure ?? 'Loading words...'),
                              style: isCompact
                                  ? CarPlayTheme.phraseText.copyWith(fontSize: 22)
                                  : CarPlayTheme.phraseText,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(height: isCompact ? 6 : 12),

                            // English Translation
                            Text(
                              item?.english ?? '',
                              style: isCompact
                                  ? CarPlayTheme.translationText.copyWith(fontSize: 15)
                                  : CarPlayTheme.translationText,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: isCompact ? 6 : 14),

        // Sub-Card Progress & Status
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Label
            Text(
              state.isSpeaking ? 'Speaking ...' : '... Ready',
              style: isCompact
                  ? CarPlayTheme.metaText.copyWith(fontSize: 11)
                  : CarPlayTheme.metaText,
            ),

            SizedBox(height: isCompact ? 4 : 8),

            // Pagination Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(dotCount, (index) {
                final isCurrent = index == currentDot;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isCompact ? 6 : 7,
                  height: isCompact ? 6 : 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? CarPlayTheme.accent
                        : const Color(0xFF424050),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: CarPlayTheme.accent.withAlpha(128),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),

            SizedBox(height: isCompact ? 4 : 6),

            // Word Counter Text
            Text(
              counterText,
              style: isCompact
                  ? CarPlayTheme.metaText.copyWith(fontSize: 11)
                  : CarPlayTheme.metaText,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlaybackControlsColumn(
    ListenRepeatState state,
    ListenRepeatViewModel notifier, {
    bool isCompact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: isCompact ? 6 : 12),
          child: const Text(
            'PLAYBACK',
            style: CarPlayTheme.sectionHeader,
          ),
        ),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top Transport Row: Prev, Big Play, Next
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Prev Button
                    _buildPillButton(
                      key: const Key('carplay_dash_prev_button'),
                      icon: Icons.skip_previous_rounded,
                      label: 'Prev',
                      onTap: () => notifier.previousWord(),
                      isCompact: isCompact,
                    ),

                    SizedBox(width: isCompact ? 8 : 12),

                    // Large Circular Violet Play/Pause Button
                    GestureDetector(
                      key: const Key('carplay_dash_play_button'),
                      onTap: () => notifier.togglePlayPause(),
                      child: Container(
                        width: isCompact ? 54 : 68,
                        height: isCompact ? 54 : 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CarPlayTheme.accent,
                          boxShadow: [
                            BoxShadow(
                              color: CarPlayTheme.accent.withAlpha(100),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          state.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF1B1924),
                          size: isCompact ? 30 : 38,
                        ),
                      ),
                    ),

                    SizedBox(width: isCompact ? 8 : 12),

                    // Next Button
                    _buildPillButton(
                      key: const Key('carplay_dash_next_button'),
                      icon: Icons.skip_next_rounded,
                      label: 'Next',
                      trailingIcon: true,
                      onTap: () => notifier.nextWord(),
                      isCompact: isCompact,
                    ),
                  ],
                ),
              ),

              SizedBox(height: isCompact ? 10 : 18),

              // Bottom Row: Shuffle & Stop
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Shuffle Button
                    _buildPillButton(
                      key: const Key('carplay_dash_shuffle_button'),
                      icon: Icons.shuffle_rounded,
                      label: 'Shuffle',
                      onTap: () => notifier.shufflePool(),
                      isCompact: isCompact,
                    ),

                    SizedBox(width: isCompact ? 8 : 12),

                    // Stop Button
                    _buildPillButton(
                      key: const Key('carplay_dash_bottom_stop_button'),
                      icon: Icons.stop_rounded,
                      label: 'Stop',
                      onTap: _stopSessionAndPop,
                      isCompact: isCompact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool trailingIcon = false,
    bool isCompact = false,
  }) {
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(CarPlayTheme.pillRadius),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: isCompact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: CarPlayTheme.surface2,
          borderRadius: BorderRadius.circular(CarPlayTheme.pillRadius),
          border: Border.all(color: CarPlayTheme.border, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!trailingIcon) ...[
              Icon(icon, color: CarPlayTheme.fg, size: isCompact ? 16 : 18),
              SizedBox(width: isCompact ? 4 : 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: CarPlayTheme.fg,
                fontSize: isCompact ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailingIcon) ...[
              SizedBox(width: isCompact ? 4 : 6),
              Icon(icon, color: CarPlayTheme.fg, size: isCompact ? 16 : 18),
            ],
          ],
        ),
      ),
    );
  }
}
