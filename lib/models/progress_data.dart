import 'package:hive/hive.dart';

part 'progress_data.g.dart';

/// Type of training activity for session logging.
@HiveType(typeId: 3)
enum ActivityType {
  @HiveField(0)
  quiz,
  @HiveField(1)
  vocabularyQuiz,
  @HiveField(2)
  interrogativeQuiz,
  @HiveField(3)
  verbConjugation,
  @HiveField(4)
  phraseTrainer,
  @HiveField(5)
  voiceTrainer,
  @HiveField(6)
  sentenceBuilder,
  @HiveField(7)
  prepositionQuiz,
}

/// A record of XP and activity for a single calendar day.
@HiveType(typeId: 4)
class DailyRecord {
  @HiveField(0)
  final String date; // ISO date string yyyy-MM-dd

  @HiveField(1)
  int xpEarned;

  @HiveField(2)
  int sessionsCompleted;

  @HiveField(3)
  int wordsReviewed;

  DailyRecord({
    required this.date,
    this.xpEarned = 0,
    this.sessionsCompleted = 0,
    this.wordsReviewed = 0,
  });
}

/// A record of a single practice session.
@HiveType(typeId: 5)
class SessionRecord {
  @HiveField(0)
  final DateTime timestamp;

  @HiveField(1)
  final ActivityType activityType;

  @HiveField(2)
  final int score;

  @HiveField(3)
  final int total;

  @HiveField(4)
  final int xpEarned;

  @HiveField(5)
  final int durationSeconds;

  SessionRecord({
    required this.timestamp,
    required this.activityType,
    required this.score,
    required this.total,
    required this.xpEarned,
    this.durationSeconds = 0,
  });
}

/// Per-word progress tracking for mastery advancement.
@HiveType(typeId: 6)
class WordProgress {
  @HiveField(0)
  final String itemId;

  /// Consecutive correct answers at the current mastery tier.
  /// Resets to 0 on wrong answer. When it reaches [tierUpThreshold],
  /// the word advances a mastery tier and this resets.
  @HiveField(1)
  int correctStreak;

  @HiveField(2)
  int totalCorrect;

  @HiveField(3)
  int totalWrong;

  @HiveField(4)
  DateTime? lastReviewedAt;

  WordProgress({
    required this.itemId,
    this.correctStreak = 0,
    this.totalCorrect = 0,
    this.totalWrong = 0,
    this.lastReviewedAt,
  });

  static const int tierUpThreshold = 3;
  static const int maxTier = 4;

  static String tierName(int tier) {
    switch (tier) {
      case 0:
        return 'New';
      case 1:
        return 'Learning';
      case 2:
        return 'Familiar';
      case 3:
        return 'Strong';
      case 4:
        return 'Mastered';
      default:
        return 'New';
    }
  }
}
