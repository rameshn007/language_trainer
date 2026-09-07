import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
    });

    test('toggleItemFlagged adds item ID to flagged set and persists', () async {
      final willBeFlagged = await storage.toggleItemFlagged('item_1');

      expect(willBeFlagged, isTrue);
      expect(storage.isItemFlagged('item_1'), isTrue);
      expect(storage.getFlaggedItemIds(), contains('item_1'));
    });

    test('persists flagged IDs across re-initialization (Hive reload into in-memory Set)', () async {
      await storage.toggleItemFlagged('item_persist_1');
      await storage.toggleItemFlagged('item_persist_2');
      expect(storage.isItemFlagged('item_persist_1'), isTrue);
      expect(storage.isItemFlagged('item_persist_2'), isTrue);

      // Create second storage service pointing to same Hive data
      final secondStorage = StorageService();
      await secondStorage.init();

      expect(secondStorage.isItemFlagged('item_persist_1'), isTrue);
      expect(secondStorage.isItemFlagged('item_persist_2'), isTrue);
      expect(secondStorage.isItemFlagged('other_item'), isFalse);
      expect(secondStorage.getFlaggedItemIds(), containsAll(['item_persist_1', 'item_persist_2']));
    });

    test('toggleItemFlagged second time removes item ID from flagged set and persists', () async {
      await storage.toggleItemFlagged('item_1');
      expect(storage.isItemFlagged('item_1'), isTrue);

      final willBeFlagged = await storage.toggleItemFlagged('item_1');
      expect(willBeFlagged, isFalse);
      expect(storage.isItemFlagged('item_1'), isFalse);
      expect(storage.getFlaggedItemIds(), isEmpty);
    });
  });
}
