import 'package:hive_flutter/hive_flutter.dart';
import '../models/language_item.dart';
import '../models/question.dart';

class StorageService {
  static const String _boxName = 'language_items';
  static const String _settingsBoxName = 'settings';
  static const String _seenQuestionsBoxName = 'seen_questions';

  Box<LanguageItem>? _itemsBox;
  Box? _settingsBox;
  Box<String>? _seenQuestionsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(LanguageItemAdapter());
    Hive.registerAdapter(QuestionTypeAdapter());
    Hive.registerAdapter(QuestionAdapter());
    _itemsBox = await Hive.openBox<LanguageItem>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    _seenQuestionsBox = await Hive.openBox<String>(_seenQuestionsBoxName);
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

  // --- Statistics ---
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

  Future<void> updateMastery(String itemId, bool isCorrect) async {
    if (_itemsBox == null) return;
    final item = _itemsBox!.get(itemId);
    if (item == null) return;

    if (isCorrect) {
      // Increment mastery, max 5 (Mastered)
      item.masteryLevel = (item.masteryLevel + 1).clamp(0, 5);
      item.lastReviewed = DateTime.now();
    } else {
      // Decrement mastery, min 0
      // If was > 3 (familiar), drop to 3? Or just decrement?
      // Simple decrement for now.
      item.masteryLevel = (item.masteryLevel - 1).clamp(0, 5);
    }
    await updateItem(item);
  }

  /// Gets mastery distribution statistics for adaptive learning
  Map<int, int> getMasteryDistribution() {
    final distro = <int, int>{};
    if (_itemsBox == null) return distro;
    
    for (var item in _itemsBox!.values) {
      distro[item.masteryLevel] = (distro[item.masteryLevel] ?? 0) + 1;
    }
    return distro;
  }

  /// Gets items grouped by mastery level for adaptive question selection
  Map<int, List<LanguageItem>> getItemsByMastery() {
    final result = <int, List<LanguageItem>>{};
    if (_itemsBox == null) return result;
    
    for (var item in _itemsBox!.values) {
      result.putIfAbsent(item.masteryLevel, () => []).add(item);
    }
    return result;
  }

  /// Gets average mastery level across all items
  double getAverageMastery() {
    final items = getAllItems();
    if (items.isEmpty) return 0.0;
    
    double sum = 0;
    for (var item in items) {
      sum += item.masteryLevel;
    }
    return sum / items.length;
  }

  /// Helper to check if we have data seeded
  bool get hasData => _itemsBox?.isNotEmpty ?? false;
}
