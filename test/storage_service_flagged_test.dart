import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('storage_flagged_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );

    storage = StorageService();
    await storage.init();
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StorageService - Flagged Items', () {
    test('initially returns empty set and false for any itemId', () {
      expect(storage.getFlaggedItemIds(), isEmpty);
      expect(storage.isItemFlagged('item_1'), isFalse);
      expect(storage.getFlaggedItems(), isEmpty);
    });

    test('toggleItemFlagged adds item ID to flagged set and persists', () async {
      final item = LanguageItem(id: 'item_1', portuguese: 'obrigado', english: 'thank you');
      final willBeFlagged = await storage.toggleItemFlagged('item_1', item: item);

      expect(willBeFlagged, isTrue);
      expect(storage.isItemFlagged('item_1'), isTrue);
      expect(storage.getFlaggedItemIds(), contains('item_1'));

      final flaggedItems = storage.getFlaggedItems();
      expect(flaggedItems, hasLength(1));
      expect(flaggedItems.first.id, 'item_1');
      expect(flaggedItems.first.portuguese, 'obrigado');
    });

    test('toggleItemFlagged second time removes item ID from flagged set', () async {
      final item = LanguageItem(id: 'item_1', portuguese: 'obrigado', english: 'thank you');
      await storage.toggleItemFlagged('item_1', item: item);
      expect(storage.isItemFlagged('item_1'), isTrue);

      final willBeFlagged = await storage.toggleItemFlagged('item_1');
      expect(willBeFlagged, isFalse);
      expect(storage.isItemFlagged('item_1'), isFalse);
      expect(storage.getFlaggedItemIds(), isEmpty);
      expect(storage.getFlaggedItems(), isEmpty);
    });

    test('getItem returns item if saved or null if absent', () async {
      expect(storage.getItem('missing_id'), isNull);

      final item = LanguageItem(id: 'item_2', portuguese: 'olá', english: 'hello');
      await storage.toggleItemFlagged('item_2', item: item);

      final retrieved = storage.getItem('item_2');
      expect(retrieved, isNotNull);
      expect(retrieved!.english, 'hello');
    });
  });
}
