import 'dart:math';
import 'package:flutter/material.dart';
import '../../../models/flashcard_item.dart';
import 'conjugation_table_widget.dart';

/// Interactive 3D flip card widget with front (Portuguese) and back (English) faces.
class FlashcardCardWidget extends StatelessWidget {
  final FlashcardItem item;
  final double flipProgress; // 0.0 (front) to 1.0 (back)
  final VoidCallback onFlip;
  final VoidCallback onSpeak;
  final VoidCallback onSpeakSlow;
  final VoidCallback? onSpeakEnglish;
  final VoidCallback? onSpeakConjugations;
  final VoidCallback? onSpeakPlural;
  final bool isSpeaking;
  final bool isFlagged;
  final VoidCallback onToggleFlag;
  final void Function(int masteryLevel)? onRateMastery;
  final int currentMastery;
  final Animation<double>? countdownAnimation;
  final double autoAdvanceProgress;
  final bool isAutoAdvancing;

  const FlashcardCardWidget({
    super.key,
    required this.item,
    required this.flipProgress,
    required this.onFlip,
    required this.onSpeak,
    required this.onSpeakSlow,
    this.onSpeakEnglish,
    this.onSpeakConjugations,
    this.onSpeakPlural,
    this.isSpeaking = false,
    this.isFlagged = false,
    required this.onToggleFlag,
    this.onRateMastery,
    this.currentMastery = 0,
    this.countdownAnimation,
    this.autoAdvanceProgress = 0.0,
    this.isAutoAdvancing = false,
  });

  @override
  Widget build(BuildContext context) {
    final angle = flipProgress * pi;
    final isFront = flipProgress <= 0.5;

    return GestureDetector(
      onTap: onFlip,
      behavior: HitTestBehavior.opaque,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012) // 3D Perspective
          ..rotateY(angle),
        alignment: Alignment.center,
        child: isFront
            ? _buildFrontFace(context)
            : Transform(
                // Mirror back face so text renders forward
                transform: Matrix4.identity()..rotateY(pi),
                alignment: Alignment.center,
                child: _buildBackFace(context),
              ),
      ),
    );
  }

  /// Front Face: Portuguese, Phonetic pronunciation, Category, Audio
  Widget _buildFrontFace(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = item.categoryColor;

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Card(
      elevation: 6,
      shadowColor: accentColor.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      color: isDark ? const Color(0xFF1E222B) : Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20,
          vertical: isLandscape ? 6 : 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Card Number, Category Pill, Flag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: isLandscape ? 2 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    item.cardNumber,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                // Category Banner
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isLandscape ? 3 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.categoryIcon,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Flag / Bookmark Button
                IconButton(
                  visualDensity: isLandscape ? VisualDensity.compact : VisualDensity.standard,
                  icon: Icon(
                    isFlagged ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    color: isFlagged ? Colors.amber.shade600 : Colors.grey.shade400,
                  ),
                  tooltip: isFlagged ? 'Remove Bookmark' : 'Bookmark Card',
                  onPressed: onToggleFlag,
                ),
              ],
            ),

            // Center: Portuguese Word / Phrase & Phonetic Guide
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.portuguese,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: item.portuguese.length > 25
                              ? (isLandscape ? 22 : 26)
                              : (isLandscape ? 28 : 34),
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      if (item.formattedPronunciation != null) ...[
                        SizedBox(height: isLandscape ? 6 : 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.formattedPronunciation!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isLandscape ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: isLandscape ? 4 : 8),

            // Bottom Audio & Action Bar
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Slow Audio Button
                  IconButton.filledTonal(
                    visualDensity: isLandscape ? VisualDensity.compact : VisualDensity.standard,
                    icon: const Icon(Icons.slow_motion_video_rounded, size: 20),
                    tooltip: 'Listen slowly (0.5x)',
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                    ),
                    onPressed: onSpeakSlow,
                  ),
                  SizedBox(width: isLandscape ? 8 : 14),
                  // Main Speaker Button
                  ElevatedButton.icon(
                    onPressed: onSpeak,
                    icon: Icon(
                      isSpeaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                      size: isLandscape ? 18 : 22,
                      color: Colors.white,
                    ),
                    label: Text(
                      isSpeaking ? 'Speaking...' : 'Listen',
                      style: TextStyle(
                        fontSize: isLandscape ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 16 : 24,
                        vertical: isLandscape ? 6 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 3,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isLandscape ? 4 : 14),

            // Flip Hint / Status Row
            _buildFrontStatusRow(context, accentColor, isDark),
          ],
        ),
      ),
    );
  }

  /// Back Face: English Translation, Grammar details, Verb Conjugation, Rating
  Widget _buildBackFace(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = item.categoryColor;

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Card(
      elevation: 6,
      shadowColor: accentColor.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: isDark ? const Color(0xFF1E222B) : Colors.white,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: isLandscape ? 6 : 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: CEFR Badge, Type / Gender Pill, Flip Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // CEFR Level
                if (item.cefrLevel != null && item.cefrLevel!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: isLandscape ? 3 : 5,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.cefrLevel!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                // Type & Gender
                if (item.typeDetailsString.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: isLandscape ? 3 : 5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.typeDetailsString,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Flip Back Icon
                IconButton(
                  visualDensity: isLandscape ? VisualDensity.compact : VisualDensity.standard,
                  icon: const Icon(Icons.flip_camera_android_rounded, size: 22),
                  tooltip: 'Flip back to Portuguese',
                  onPressed: onFlip,
                ),
              ],
            ),

            SizedBox(height: isLandscape ? 4 : 10),

            // Scrollable & Vertically Balanced Content area
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Compute dynamic font size for English translation
                  final int len = item.english.length;
                  final double englishFontSize = len > 35
                      ? 26.0
                      : len > 22
                          ? 30.0
                          : len > 12
                              ? 34.0
                              : 38.0;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),

                            // English Translation (Significantly Enlarged with Speaker Button)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    item.english,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: englishFontSize,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : Colors.black87,
                                      letterSpacing: -0.5,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (onSpeakEnglish != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: Icon(
                                      isSpeaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                                      size: 24,
                                      color: accentColor,
                                    ),
                                    tooltip: 'Listen in English',
                                    onPressed: onSpeakEnglish,
                                  ),
                                ],
                              ],
                            ),

                            // Plural form if available
                            if (item.plural != null && item.plural!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Plural: ${item.plural}',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  if (onSpeakPlural != null) ...[
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: Icon(
                                        isSpeaking ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                                        size: 16,
                                        color: accentColor,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      tooltip: 'Listen to plural',
                                      onPressed: onSpeakPlural,
                                    ),
                                  ],
                                ],
                              ),
                            ],

                            // Verb Conjugations Table (if verb)
                            if (item.presentTense != null &&
                                item.presentTense!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              ConjugationTableWidget(
                                conjugations: item.presentTense!,
                                accentColor: accentColor,
                                onSpeak: onSpeakConjugations,
                                isSpeaking: isSpeaking,
                              ),
                            ],

                            // Grammar Rules Explanation (for #G1 - #G7)
                            if (item.isGrammarCard &&
                                item.grammarExplanation != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.menu_book_rounded,
                                              size: 16,
                                              color: accentColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Grammar Rule',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: accentColor,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (onSpeakEnglish != null)
                                          IconButton(
                                            icon: Icon(
                                              isSpeaking
                                                  ? Icons.volume_up_rounded
                                                  : Icons.volume_up_outlined,
                                              size: 18,
                                              color: accentColor,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Listen to grammar explanation',
                                            onPressed: onSpeakEnglish,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.grammarExplanation!,
                                      style: TextStyle(
                                        fontSize: 16,
                                        height: 1.55,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Example Sentence (if present)
                            if (item.examplePt != null &&
                                item.examplePt!.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.format_quote_rounded,
                                          size: 18,
                                          color: accentColor,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item.examplePt!,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        if (onSpeakEnglish != null) ...[
                                          const SizedBox(width: 4),
                                          IconButton(
                                            icon: Icon(
                                              Icons.volume_up_rounded,
                                              size: 20,
                                              color: accentColor,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Listen to example sentence',
                                            onPressed: onSpeakEnglish,
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (item.exampleEn != null &&
                                        item.exampleEn!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 26),
                                        child: Text(
                                          item.exampleEn!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Mastery Rating Controls (vocabulary cards only)
            if (!item.isGrammarCard && onRateMastery != null) ...[
              Divider(height: isLandscape ? 8 : 16),
              Text(
                'How well do you know this card?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              SizedBox(height: isLandscape ? 4 : 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRatingButton(
                    context: context,
                    label: 'Practice',
                    icon: Icons.refresh_rounded,
                    color: Colors.orange.shade700,
                    isActive: currentMastery >= 1 && currentMastery <= 2,
                    isLandscape: isLandscape,
                    onTap: () => onRateMastery!(1),
                  ),
                  _buildRatingButton(
                    context: context,
                    label: 'Familiar',
                    icon: Icons.thumb_up_alt_outlined,
                    color: Colors.blue.shade600,
                    isActive: currentMastery == 3,
                    isLandscape: isLandscape,
                    onTap: () => onRateMastery!(3),
                  ),
                  _buildRatingButton(
                    context: context,
                    label: 'Mastered',
                    icon: Icons.star_rounded,
                    color: Colors.green.shade600,
                    isActive: currentMastery >= 4,
                    isLandscape: isLandscape,
                    onTap: () => onRateMastery!(4),
                  ),
                ],
              ),
            ],
            // Back Status Row
            _buildBackStatusRow(context, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required bool isActive,
    required VoidCallback onTap,
    bool isLandscape = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 10 : 14,
          vertical: isLandscape ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontStatusRow(
    BuildContext context,
    Color accentColor,
    bool isDark,
  ) {
    Widget buildRow(double progress) {
      final isCountdown = isAutoAdvancing && progress > 0;
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSpeaking
                  ? Icons.volume_up_rounded
                  : isCountdown
                      ? Icons.timer_rounded
                      : Icons.touch_app_rounded,
              size: 14,
              color: (isSpeaking || isCountdown)
                  ? accentColor
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            const SizedBox(width: 6),
            Text(
              isSpeaking
                  ? 'Listening...'
                  : isCountdown
                      ? 'Flipping card soon...'
                      : 'Tap anywhere to flip card',
              style: TextStyle(
                fontSize: 12,
                fontWeight: (isSpeaking || isCountdown)
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: (isSpeaking || isCountdown)
                    ? accentColor
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      );
    }

    if (countdownAnimation != null) {
      return AnimatedBuilder(
        animation: countdownAnimation!,
        builder: (context, _) => buildRow(countdownAnimation!.value),
      );
    }
    return buildRow(autoAdvanceProgress);
  }

  Widget _buildBackStatusRow(BuildContext context, Color accentColor) {
    Widget buildRow(double progress) {
      if (isSpeaking) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.volume_up_rounded,
                  size: 14,
                  color: accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Listening...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (isAutoAdvancing && progress > 0) {
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: Colors.amber.shade700,
                ),
                const SizedBox(width: 5),
                Text(
                  'Advancing to next card...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (countdownAnimation != null) {
      return AnimatedBuilder(
        animation: countdownAnimation!,
        builder: (context, _) => buildRow(countdownAnimation!.value),
      );
    }
    return buildRow(autoAdvanceProgress);
  }
}
