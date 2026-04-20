import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/progress_data.dart';
import 'storage_service.dart';

/// Immutable snapshot of the user's progress, used by the UI.
class ProgressSnapshot {
  final int todayXP;
  final int dailyGoal;
  final int currentStreak;
  final int bestStreak;
  final int totalXP;
  final int todaySessions;
  final Map<int, int> masteryDistribution;

  const ProgressSnapshot({
    this.todayXP = 0,
    this.dailyGoal = 50,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalXP = 0,
    this.todaySessions = 0,
    this.masteryDistribution = const {},
  });

  double get dailyGoalProgress =>
      dailyGoal > 0 ? (todayXP / dailyGoal).clamp(0.0, 1.0) : 0.0;

  bool get dailyGoalMet => todayXP >= dailyGoal;

  int get totalWords {
    int sum = 0;
    for (final count in masteryDistribution.values) {
      sum += count;
    }
    return sum;
  }

  ProgressSnapshot copyWith({
    int? todayXP,
    int? dailyGoal,
    int? currentStreak,
    int? bestStreak,
    int? totalXP,
    int? todaySessions,
    Map<int, int>? masteryDistribution,
  }) {
    return ProgressSnapshot(
      todayXP: todayXP ?? this.todayXP,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalXP: totalXP ?? this.totalXP,
      todaySessions: todaySessions ?? this.todaySessions,
      masteryDistribution: masteryDistribution ?? this.masteryDistribution,
    );
  }
}

/// High-level progress service that wraps StorageService
/// and provides a reactive [ProgressSnapshot] via Riverpod.
class ProgressService extends Notifier<ProgressSnapshot> {
  @override
  ProgressSnapshot build() {
    return const ProgressSnapshot();
  }

  /// Call this once on app start, after StorageService.init().
  void refresh(StorageService storage) {
    state = ProgressSnapshot(
      todayXP: storage.getTodayXP(),
      dailyGoal: storage.getDailyXPGoal(),
      currentStreak: storage.getCurrentStreak(),
      bestStreak: storage.getBestStreak(),
      totalXP: storage.getTotalXP(),
      todaySessions: storage.getTodaySessions(),
      masteryDistribution: storage.getMasteryDistribution(),
    );
  }

  /// Record a quiz answer.
  /// Returns the XP awarded (so the UI can show a pop-up).
  Future<int> recordQuizAnswer({
    required StorageService storage,
    required String itemId,
    required bool correct,
    bool firstAttempt = true,
  }) async {
    final xp = await storage.updateWordProgress(
      itemId,
      correct,
      firstAttempt: firstAttempt,
    );

    if (xp > 0) {
      await storage.addXP(xp);
    }

    if (correct) {
      await storage.incrementWordsReviewed(1);
    }

    // Refresh snapshot
    refresh(storage);
    return xp;
  }

  /// Record a completed session.
  /// Awards completion bonus XP and daily goal bonus.
  Future<int> recordSessionComplete({
    required StorageService storage,
    required ActivityType activityType,
    required int score,
    required int total,
    int durationSeconds = 0,
    int sessionXP = 0,
  }) async {
    // Session completion bonus
    const completionBonus = 20;
    final totalSessionXP = sessionXP + completionBonus;

    await storage.addXP(completionBonus);
    await storage.incrementDailySessions();

    // Check if daily goal was just met
    final wasGoalMet = (storage.getTodayXP() - completionBonus) >= storage.getDailyXPGoal();
    int dailyGoalBonus = 0;
    if (!wasGoalMet && storage.getTodayXP() >= storage.getDailyXPGoal()) {
      dailyGoalBonus = 10;
      await storage.addXP(dailyGoalBonus);
    }

    // Save session record
    await storage.saveSession(SessionRecord(
      timestamp: DateTime.now(),
      activityType: activityType,
      score: score,
      total: total,
      xpEarned: totalSessionXP + dailyGoalBonus,
      durationSeconds: durationSeconds,
    ));

    // Refresh snapshot
    refresh(storage);
    debugPrint(
      '[ProgressService] Session complete: $activityType, '
      'score=$score/$total, xp=$totalSessionXP, dailyBonus=$dailyGoalBonus',
    );
    return totalSessionXP + dailyGoalBonus;
  }

  /// Reset all progress data.
  Future<void> resetAll(StorageService storage) async {
    await storage.resetAllProgress();
    refresh(storage);
  }
}

final progressServiceProvider =
    NotifierProvider<ProgressService, ProgressSnapshot>(ProgressService.new);
