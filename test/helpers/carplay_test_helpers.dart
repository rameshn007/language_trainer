import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/progress_data.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/services/progress_service.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAudioPlayer extends Mock implements AudioPlayer {}
class MockListenRepeatContentService extends Mock implements ListenRepeatContentService {}
class MockTtsService extends Mock implements TtsService {}
class MockProgressService extends Notifier<ProgressSnapshot> with Mock implements ProgressService {
  @override
  ProgressSnapshot build() => const ProgressSnapshot();
}

/// In-memory fake StorageService providing realistic flag persistence and item storage.
class FakeStorageService extends Fake implements StorageService {
  final Set<String> _flaggedIds;
  final Map<String, LanguageItem> _items;

  FakeStorageService({
    Set<String>? initialFlaggedIds,
    List<LanguageItem>? initialItems,
  })  : _flaggedIds = initialFlaggedIds != null ? Set<String>.from(initialFlaggedIds) : <String>{},
        _items = initialItems != null ? {for (final item in initialItems) item.id: item} : <String, LanguageItem>{};

  @override
  bool isItemFlagged(String itemId) => _flaggedIds.contains(itemId);

  @override
  Set<String> getFlaggedItemIds() => Set<String>.unmodifiable(_flaggedIds);

  @override
  Future<bool> toggleItemFlagged(String itemId) async {
    final bool willBeFlagged;
    if (_flaggedIds.contains(itemId)) {
      _flaggedIds.remove(itemId);
      willBeFlagged = false;
    } else {
      _flaggedIds.add(itemId);
      willBeFlagged = true;
    }
    return willBeFlagged;
  }

  @override
  List<LanguageItem> getAllItems() => _items.values.toList();

  @override
  Future<void> saveItems(List<LanguageItem> items) async {
    for (final item in items) {
      _items[item.id] = item;
    }
  }

  @override
  Future<void> updateItem(LanguageItem item) async {
    _items[item.id] = item;
  }

  @override
  Future<void> deleteItem(String id) async {
    _items.remove(id);
  }

  @override
  Future<void> clearItems() async {
    _items.clear();
  }

  final Map<String, dynamic> _settings = {};

  @override
  dynamic getSetting(String key, {dynamic defaultValue}) => _settings[key] ?? defaultValue;

  @override
  Future<void> saveSetting(String key, dynamic value) async {
    _settings[key] = value;
  }

  @override
  bool get hasData => _items.isNotEmpty;
}

void registerCarPlayFallbackValues() {
  registerFallbackValue(ListenRepeatMode.all);
  registerFallbackValue(ActivityType.listenRepeat);
  registerFallbackValue(Duration.zero);
  // ignore: deprecated_member_use
  registerFallbackValue(ConcatenatingAudioSource(children: []));
  registerFallbackValue(LanguageItem(id: 'dummy', portuguese: 'ola', english: 'hello'));
  registerFallbackValue(FakeStorageService());
}

void setupCarPlayPlatformChannels(Directory tempDir) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return tempDir.path;
      }
      return null;
    },
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.oguzhnatly.flutter_carplay'),
    (MethodCall methodCall) async {
      return true;
    },
  );
}

Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  if (condition()) return;
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(Duration.zero);
  }
}
