import 'package:hive_flutter/hive_flutter.dart';
import '../models/language_item.dart';
import '../models/question.dart';
import '../models/progress_data.dart';

class StorageService {
  static const String _boxName = 'language_items';
  static const String _settingsBoxName = 'settings';
  static const String _seenQuestionsBoxName = 'seen_questions';
  static const String _dailyRecordsBoxName = 'daily_records';
  static const String _sessionRecordsBoxName = 'session_records';
  static const String _wordProgressBoxName = 'word_progress';

  Box<LanguageItem>? _itemsBox;
  Box? _settingsBox;
  Box<String>? _seenQuestionsBox;
  Box<DailyRecord>? _dailyRecordsBox;
  Box<SessionRecord>? _sessionRecordsBox;
  Box<WordProgress>? _wordProgressBox;

  Future<void> init() async {
    await Hive.initFlutter();

    // Register all adapters
    Hive.registerAdapter(LanguageItemAdapter());
    Hive.registerAdapter(QuestionTypeAdapter());
    Hive.registerAdapter(QuestionAdapter());
    Hive.registerAdapter(ActivityTypeAdapter());
    Hive.registerAdapter(DailyRecordAdapter());
    Hive.registerAdapter(SessionRecordAdapter());
    Hive.registerAdapter(WordProgressAdapter());

    // Open all boxes
    _itemsBox = await Hive.openBox<LanguageItem>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _seenQuestionsBox = await Hive.openBox<String>(_seenQuestionsBoxName);
    _dailyRecordsBox = await Hive.openBox<DailyRecord>(_dailyRecordsBoxName);
    _sessionRecordsBox = await Hive.openBox<SessionRecord>(_sessionRecordsBoxName);
    _wordProgressBox = await Hive.openBox<WordProgress>(_wordProgressBoxName);
  }

  // --- Items ---
  List<LanguageItem> getAllItems() {
    if (_itemsBox == null) return [];
    return _itemsBox!.values.toList();
  }

  Future<void> saveItems(List<LanguageItem> items) async {
    if (_itemsBox == null) return;
    // We can use a map to put all at once which is faster
    final Map<String, LanguageItem> itemsMap = {
      for (var item in items) item.id: item,
    };
    await _itemsBox!.putAll(itemsMap);
  }

  Future<void> clearItems() async {
    if (_itemsBox == null) return;
    await _itemsBox!.clear();
  }

  Future<void> updateItem(LanguageItem item) async {
    if (_itemsBox == null) return;
    await _itemsBox!.put(item.id, item);
  }

  Future<void> deleteItem(String id) async {
    if (_itemsBox == null) return;
    await _itemsBox!.delete(id);
  }

  // --- Settings / Progress ---
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue);
  }

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox?.put(key, value);
  }

  // --- Daily XP Goal ---
  int getDailyXPGoal() {
    return _settingsBox?.get('daily_xp_goal', defaultValue: 50) ?? 50;
  }

  Future<void> setDailyXPGoal(int goal) async {
    await _settingsBox?.put('daily_xp_goal', goal);
  }

  // --- Legacy Statistics (kept for backward compat) ---
  int getHighScore() {
    return _settingsBox?.get('high_score', defaultValue: 0) ?? 0;
  }

  Future<void> saveHighScore(int score) async {
    final current = getHighScore();
    if (score > current) {
      await _settingsBox?.put('high_score', score);
    }
  }

  Future<void> resetHighScore() async {
    await _settingsBox?.delete('high_score');
  }
  
  // --- Notification Settings ---
  bool get remindersEnabled => getSetting('reminders_enabled', defaultValue: true);
  int get reminderHour => getSetting('reminder_hour', defaultValue: 9);
  int get reminderMinute => getSetting('reminder_minute', defaultValue: 0);
  bool get hasRequestedNotifications => getSetting('has_requested_notifications', defaultValue: false);

  Future<void> setRemindersEnabled(bool enabled) async => saveSetting('reminders_enabled', enabled);
  Future<void> setReminderTime(int hour, int minute) async {
    await saveSetting('reminder_hour', hour);
    await saveSetting('reminder_minute', minute);
  }
  Future<void> markNotificationsRequested() async => saveSetting('has_requested_notifications', true);

  // --- Seen Questions Tracking ---
  bool isQuestionSeen(String id) {
    return _seenQuestionsBox?.containsKey(id) ?? false;
  }

  Future<void> markQuestionAsSeen(String id) async {
    await _seenQuestionsBox?.put(id, DateTime.now().toIso8601String());
  }

  Set<String> getSeenQuestionIds() {
    if (_seenQuestionsBox == null) return {};
    // Keys in Hive are usually dynamic, cast to String
    return _seenQuestionsBox!.keys.cast<String>().toSet();
  }

  Future<void> clearSeenQuestions() async {
    await _seenQuestionsBox?.clear();
  }

  // =========================================================================
  // NEW PROGRESS SYSTEM
  // =========================================================================

  // --- Daily Records ---

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DailyRecord _getOrCreateToday() {
    final key = _todayKey();
    var record = _dailyRecordsBox?.get(key);
    if (record == null) {
      record = DailyRecord(date: key);
      _dailyRecordsBox?.put(key, record);
    }
    return record;
  }

  Future<void> addXP(int amount) async {
    if (_dailyRecordsBox == null) return;
    final record = _getOrCreateToday();
    record.xpEarned += amount;
    await _dailyRecordsBox!.put(record.date, record);
  }

  Future<void> incrementDailySessions() async {
    if (_dailyRecordsBox == null) return;
    final record = _getOrCreateToday();
    record.sessionsCompleted += 1;
    await _dailyRecordsBox!.put(record.date, record);
  }

  Future<void> incrementWordsReviewed(int count) async {
    if (_dailyRecordsBox == null) return;
    final record = _getOrCreateToday();
    record.wordsReviewed += count;
    await _dailyRecordsBox!.put(record.date, record);
  }

  int getTodayXP() {
    final record = _dailyRecordsBox?.get(_todayKey());
    return record?.xpEarned ?? 0;
  }

  int getTodaySessions() {
    final record = _dailyRecordsBox?.get(_todayKey());
    return record?.sessionsCompleted ?? 0;
  }

  int getTotalXP() {
    if (_dailyRecordsBox == null) return 0;
    int total = 0;
    for (final record in _dailyRecordsBox!.values) {
      total += record.xpEarned;
    }
    return total;
  }

  /// Returns XP totals for the last [days] days, ordered oldest → newest.
  List<int> getXPHistory(int days) {
    final result = <int>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final record = _dailyRecordsBox?.get(key);
      result.add(record?.xpEarned ?? 0);
    }
    return result;
  }

  /// Returns day labels for the last [days] days (e.g. "Mon", "Tue").
  List<String> getXPHistoryLabels(int days) {
    final labels = <String>[];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      labels.add(dayNames[date.weekday - 1]);
    }
    return labels;
  }

  // --- Streak ---

  int getCurrentStreak() {
    if (_dailyRecordsBox == null) return 0;
    int streak = 0;
    final now = DateTime.now();

    // Check today first
    final todayRecord = _dailyRecordsBox!.get(_todayKey());
    if (todayRecord != null && todayRecord.xpEarned > 0) {
      streak = 1;
    }

    // Walk backwards from yesterday
    for (int i = 1; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final record = _dailyRecordsBox!.get(key);
      if (record != null && record.xpEarned > 0) {
        if (streak == 0 && i == 1) {
          // Today had no XP, but yesterday did — streak still counts
          streak = 1;
        }
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  int getBestStreak() {
    if (_dailyRecordsBox == null) return 0;
    // Get all daily records sorted by date
    final records = _dailyRecordsBox!.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    if (records.isEmpty) return 0;

    int bestStreak = 0;
    int currentStreak = 0;
    DateTime? lastDate;

    for (final record in records) {
      if (record.xpEarned <= 0) continue;
      
      final parts = record.date.split('-');
      final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      
      if (lastDate == null || date.difference(lastDate).inDays == 1) {
        currentStreak++;
      } else if (date.difference(lastDate).inDays > 1) {
        currentStreak = 1;
      }
      
      if (currentStreak > bestStreak) bestStreak = currentStreak;
      lastDate = date;
    }

    return bestStreak;
  }

  /// Returns a set of date keys (yyyy-MM-dd) that had XP in the last [days] days.
  Set<String> getActiveDays(int days) {
    final result = <String>{};
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = _dateKey(date);
      final record = _dailyRecordsBox?.get(key);
      if (record != null && record.xpEarned > 0) {
        result.add(key);
      }
    }
    return result;
  }

  // --- Session Records ---

  Future<void> saveSession(SessionRecord session) async {
    if (_sessionRecordsBox == null) return;
    final key = session.timestamp.millisecondsSinceEpoch.toString();
    await _sessionRecordsBox!.put(key, session);
  }

  List<SessionRecord> getRecentSessions(int limit) {
    if (_sessionRecordsBox == null) return [];
    final all = _sessionRecordsBox!.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.take(limit).toList();
  }

  // --- Word Progress ---

  WordProgress getWordProgress(String itemId) {
    if (_wordProgressBox == null) {
      return WordProgress(itemId: itemId);
    }
    return _wordProgressBox!.get(itemId) ?? WordProgress(itemId: itemId);
  }

  /// Updates word progress and mastery tier based on correctness.
  /// Returns the XP awarded for this answer.
  Future<int> updateWordProgress(String itemId, bool correct, {bool firstAttempt = true}) async {
    if (_wordProgressBox == null || _itemsBox == null) return 0;
    
    final progress = getWordProgress(itemId);
    final item = _itemsBox!.get(itemId);
    int xp = 0;

    if (correct) {
      progress.totalCorrect += 1;
      progress.correctStreak += 1;
      progress.lastReviewedAt = DateTime.now();
      
      // Award XP
      xp = firstAttempt ? 10 : 5;

      // Check for tier advancement
      if (item != null) {
        final currentTier = item.masteryLevel.clamp(0, WordProgress.maxTier);
        if (currentTier < WordProgress.maxTier &&
            progress.correctStreak >= WordProgress.tierUpThreshold) {
          // Advance tier!
          item.masteryLevel = currentTier + 1;
          item.lastReviewed = DateTime.now();
          progress.correctStreak = 0; // Reset for new tier
          await updateItem(item);
        } else {
          item.lastReviewed = DateTime.now();
          await updateItem(item);
        }
      }
    } else {
      progress.totalWrong += 1;
      progress.correctStreak = 0; // Reset streak, but don't drop tier
    }

    await _wordProgressBox!.put(itemId, progress);
    return xp;
  }

  /// Returns count of items at each mastery tier (0–4).
  Map<int, int> getMasteryDistribution() {
    if (_itemsBox == null) return {};
    final dist = <int, int>{0: 0, 1: 0, 2: 0, 3: 0, 4: 0};
    for (final item in _itemsBox!.values) {
      final tier = item.masteryLevel.clamp(0, 4);
      dist[tier] = (dist[tier] ?? 0) + 1;
    }
    return dist;
  }

  // --- Legacy updateMastery (delegates to new system) ---
  Future<void> updateMastery(String itemId, bool isCorrect) async {
    await updateWordProgress(itemId, isCorrect);
  }

  // --- Stats Reset ---
  Future<void> resetStats() async {
    if (_itemsBox == null) return;
    final allItems = _itemsBox!.values.toList();
    for (var item in allItems) {
      item.masteryLevel = 0;
      item.lastReviewed = null;
    }
    await saveItems(allItems);
    // Also reset seen questions
    await _seenQuestionsBox?.clear();
  }

  Future<void> resetAllProgress() async {
    await resetStats();
    await resetHighScore();
    await _dailyRecordsBox?.clear();
    await _sessionRecordsBox?.clear();
    await _wordProgressBox?.clear();
  }

  // Helper to check if we have data seeded
  bool get hasData => _itemsBox?.isNotEmpty ?? false;
}
