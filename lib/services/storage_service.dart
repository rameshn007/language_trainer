import 'package:hive_flutter/hive_flutter.dart';
import '../models/language_item.dart';
import '../models/question.dart';

class StorageService {
  static const String _boxName = 'language_items';
  static const String _settingsBoxName = 'settings';

  Box<LanguageItem>? _itemsBox;
  Box? _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(LanguageItemAdapter());
    Hive.registerAdapter(QuestionTypeAdapter());
    Hive.registerAdapter(QuestionAdapter());
    _itemsBox = await Hive.openBox<LanguageItem>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
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

  Future<void> resetStats() async {
    if (_itemsBox == null) return;
    final allItems = _itemsBox!.values.toList();
    for (var item in allItems) {
      item.masteryLevel = 0;
      item.lastReviewed = null;
    }
    await saveItems(allItems);
  }

  // Helper to check if we have data seeded
  bool get hasData => _itemsBox?.isNotEmpty ?? false;
}
