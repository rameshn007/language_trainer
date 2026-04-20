import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../services/progress_service.dart';
import '../models/progress_data.dart';
import '../main.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressServiceProvider);
    final storage = ref.read(storageServiceProvider);
    final xpHistory = storage.getXPHistory(7);
    final xpLabels = storage.getXPHistoryLabels(7);
    final activeDays = storage.getActiveDays(30);
    final recentSessions = storage.getRecentSessions(10);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress & Stats'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary cards
            FadeInDown(
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.bolt,
                      iconColor: Colors.amber.shade700,
                      label: 'Total XP',
                      value: '${progress.totalXP}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.local_fire_department,
                      iconColor: Colors.deepOrange,
                      label: 'Streak',
                      value: '${progress.currentStreak} day${progress.currentStreak == 1 ? '' : 's'}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      icon: Icons.star,
                      iconColor: Colors.purple,
                      label: 'Best Streak',
                      value: '${progress.bestStreak}',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 7-day XP chart
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: _SectionCard(
                title: 'Last 7 Days',
                child: SizedBox(
                  height: 160,
                  child: _XPBarChart(values: xpHistory, labels: xpLabels),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Daily goal progress
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: _SectionCard(
                title: 'Today\'s Goal',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${progress.todayXP} / ${progress.dailyGoal} XP',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${(progress.dailyGoalProgress * 100).round()}%',
                          style: TextStyle(
                            color: progress.dailyGoalMet
                                ? Colors.green
                                : Theme.of(context).colorScheme.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress.dailyGoalProgress,
                        minHeight: 14,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progress.dailyGoalMet
                              ? Colors.green
                              : Colors.deepPurple,
                        ),
                      ),
                    ),
                    if (progress.dailyGoalMet)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green.shade400, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Goal complete!',
                              style: TextStyle(
                                color: Colors.green.shade400,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 30-day streak calendar
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: _SectionCard(
                title: 'Activity (Last 30 Days)',
                child: _StreakCalendar(activeDays: activeDays),
              ),
            ),
            const SizedBox(height: 20),

            // Mastery breakdown
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: _SectionCard(
                title: 'Vocabulary Mastery',
                child: _MasteryBreakdown(
                  distribution: progress.masteryDistribution,
                  totalWords: progress.totalWords,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Recent sessions
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: _SectionCard(
                title: 'Recent Sessions',
                child: recentSessions.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No sessions yet. Start a quiz!',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      )
                    : Column(
                        children: recentSessions
                            .map((s) => _SessionTile(session: s))
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Card ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Card ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─── 7-day XP Bar Chart (CustomPaint) ────────────────────────────────────────

class _XPBarChart extends StatelessWidget {
  final List<int> values;
  final List<String> labels;

  const _XPBarChart({required this.values, required this.labels});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 160),
      painter: _BarChartPainter(
        values: values,
        labels: labels,
        barColor: Colors.deepPurple,
        textColor: Theme.of(context).colorScheme.outline,
        todayColor: Colors.amber.shade700,
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> values;
  final List<String> labels;
  final Color barColor;
  final Color textColor;
  final Color todayColor;

  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.barColor,
    required this.textColor,
    required this.todayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.reduce(max).toDouble();
    final effectiveMax = maxVal > 0 ? maxVal : 1.0;

    final barWidth = (size.width / values.length) * 0.55;
    final gap = size.width / values.length;
    const labelHeight = 24.0;
    const valueHeight = 18.0;
    final chartHeight = size.height - labelHeight - valueHeight;

    for (int i = 0; i < values.length; i++) {
      final x = gap * i + (gap - barWidth) / 2;
      final barHeight = (values[i] / effectiveMax) * (chartHeight - 4);
      final isToday = i == values.length - 1;
      final color = isToday ? todayColor : barColor;

      // Bar
      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          valueHeight + chartHeight - barHeight,
          barWidth,
          barHeight.clamp(4, chartHeight),
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(barRect, Paint()..color = color.withValues(alpha: 0.85));

      // Value label above bar
      final valuePainter = TextPainter(
        text: TextSpan(
          text: '${values[i]}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      valuePainter.paint(
        canvas,
        Offset(
          x + (barWidth - valuePainter.width) / 2,
          valueHeight + chartHeight - barHeight - 16,
        ),
      );

      // Day label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: isToday ? color : textColor,
            fontSize: 11,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(
        canvas,
        Offset(
          x + (barWidth - labelPainter.width) / 2,
          size.height - labelHeight + 4,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

// ─── 30-Day Streak Calendar ──────────────────────────────────────────────────

class _StreakCalendar extends StatelessWidget {
  final Set<String> activeDays;

  const _StreakCalendar({required this.activeDays});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(30, (i) {
        final day = now.subtract(Duration(days: 29 - i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final isActive = activeDays.contains(key);
        final isToday = i == 29;

        return Tooltip(
          message: '${day.day}/${day.month} — ${isActive ? "Active" : "Inactive"}',
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.green.withValues(alpha: 0.8)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(6),
              border: isToday
                  ? Border.all(color: Colors.deepPurple, width: 2)
                  : null,
            ),
            child: isActive
                ? const Center(
                    child: Icon(Icons.check, size: 14, color: Colors.white),
                  )
                : null,
          ),
        );
      }),
    );
  }
}

// ─── Mastery Breakdown ───────────────────────────────────────────────────────

class _MasteryBreakdown extends StatelessWidget {
  final Map<int, int> distribution;
  final int totalWords;

  const _MasteryBreakdown({
    required this.distribution,
    required this.totalWords,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.grey,
      Colors.blue,
      Colors.cyan,
      Colors.orange,
      Colors.green,
    ];

    return Column(
      children: List.generate(5, (tier) {
        final count = distribution[tier] ?? 0;
        final fraction = totalWords > 0 ? count / totalWords : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  WordProgress.tierName(tier),
                  style: TextStyle(
                    fontSize: 12,
                    color: colors[tier],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 10,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(colors[tier]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 32,
                child: Text(
                  '$count',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Session Tile ────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final SessionRecord session;

  const _SessionTile({required this.session});

  String _activityName(ActivityType type) {
    switch (type) {
      case ActivityType.quiz:
        return 'Quiz';
      case ActivityType.vocabularyQuiz:
        return 'Vocab Quiz';
      case ActivityType.interrogativeQuiz:
        return 'Interrogatives';
      case ActivityType.verbConjugation:
        return 'Verb Trainer';
      case ActivityType.phraseTrainer:
        return 'Phrase Trainer';
      case ActivityType.voiceTrainer:
        return 'Voice Trainer';
      case ActivityType.sentenceBuilder:
        return 'Sentence Builder';
    }
  }

  IconData _activityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.quiz:
        return Icons.quiz_rounded;
      case ActivityType.vocabularyQuiz:
        return Icons.local_fire_department_rounded;
      case ActivityType.interrogativeQuiz:
        return Icons.contact_support_rounded;
      case ActivityType.verbConjugation:
        return Icons.school_rounded;
      case ActivityType.phraseTrainer:
        return Icons.translate_rounded;
      case ActivityType.voiceTrainer:
        return Icons.mic_rounded;
      case ActivityType.sentenceBuilder:
        return Icons.reorder_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _activityIcon(session.activityType),
              size: 18,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activityName(session.activityType),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${session.score}/${session.total} · ${_timeAgo(session.timestamp)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.shade700.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+${session.xpEarned} XP',
              style: TextStyle(
                color: Colors.amber.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
