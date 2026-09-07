import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_screen.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:language_trainer/ui/vocabulary/vocabulary_list_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/carplay_test_helpers.dart';

class _TestLRViewModel extends ListenRepeatViewModel {
  final LanguageItem _initialItem;

  _TestLRViewModel(this._initialItem, {required super.audioPlayer});

  @override
  ListenRepeatState build() {
    return ListenRepeatState(
      currentItem: _initialItem,
      pool: [_initialItem],
      isPlaying: false,
    );
  }

  @override
  Future<void> startSession({ListenRepeatMode? mode}) async {}

  @override
  Future<int> stopSession({bool recordProgress = true}) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('widget_flag_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return tempDir.path;
      },
    );
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Phone UI - Flag for Review Controls', () {
    testWidgets('ListenRepeatScreen star button toggles flag state and updates icon', (tester) async {
      final testItem = LanguageItem(id: 'w1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            listenRepeatViewModelProvider.overrideWith(
              () => _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer),
            ),
          ],
          child: const MaterialApp(
            home: ListenRepeatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final starFinder = find.byKey(const Key('listen_repeat_star_button'));
      expect(starFinder, findsOneWidget);

      // Initially unflagged
      expect(fakeStorage.isItemFlagged('w1'), isFalse);
      var icon = tester.widget<Icon>(find.descendant(of: starFinder, matching: find.byType(Icon)));
      expect(icon.icon, Icons.star_border_rounded);

      // Tap to flag
      await tester.tap(starFinder);
      await tester.pumpAndSettle();

      expect(fakeStorage.isItemFlagged('w1'), isTrue);
      icon = tester.widget<Icon>(find.descendant(of: starFinder, matching: find.byType(Icon)));
      expect(icon.icon, Icons.star_rounded);

      // Tap to unflag
      await tester.tap(starFinder);
      await tester.pumpAndSettle();

      expect(fakeStorage.isItemFlagged('w1'), isFalse);
      icon = tester.widget<Icon>(find.descendant(of: starFinder, matching: find.byType(Icon)));
      expect(icon.icon, Icons.star_border_rounded);
    });

    testWidgets('VocabularyListScreen row star button and AppBar filter button work correctly', (tester) async {
      final item1 = LanguageItem(id: 'v1', portuguese: 'bom dia', english: 'good morning');
      final item2 = LanguageItem(id: 'v2', portuguese: 'boa noite', english: 'good night');
      // v2 is initially flagged
      final fakeStorage = FakeStorageService(
        initialItems: [item1, item2],
        initialFlaggedIds: {'v2'},
      );

      final mockTts = MockTtsService();
      when(() => mockTts.setRate(any())).thenAnswer((_) async {});
      when(() => mockTts.stop()).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
          child: const MaterialApp(
            home: VocabularyListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both items are in the list initially
      expect(find.text('bom dia'), findsOneWidget);
      expect(find.text('boa noite'), findsOneWidget);

      // Row star button for v1 (currently unflagged)
      final v1StarFinder = find.byKey(const Key('vocab_star_button_v1'));
      expect(v1StarFinder, findsOneWidget);
      var v1Icon = tester.widget<Icon>(find.descendant(of: v1StarFinder, matching: find.byType(Icon)));
      expect(v1Icon.icon, Icons.star_border_rounded);

      // Row star button for v2 (currently flagged)
      final v2StarFinder = find.byKey(const Key('vocab_star_button_v2'));
      expect(v2StarFinder, findsOneWidget);
      var v2Icon = tester.widget<Icon>(find.descendant(of: v2StarFinder, matching: find.byType(Icon)));
      expect(v2Icon.icon, Icons.star_rounded);

      // Tap v1 star button -> flags v1
      await tester.tap(v1StarFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(fakeStorage.isItemFlagged('v1'), isTrue);
      v1Icon = tester.widget<Icon>(find.descendant(of: v1StarFinder, matching: find.byType(Icon)));
      expect(v1Icon.icon, Icons.star_rounded);

      // Tap AppBar star filter button -> filters to only flagged words
      final filterButtonFinder = find.byKey(const Key('vocab_filter_flagged_button'));
      expect(filterButtonFinder, findsOneWidget);

      // Unflag v1 first so only v2 is flagged
      await tester.tap(v1StarFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(fakeStorage.isItemFlagged('v1'), isFalse);

      // Filter to only flagged
      await tester.tap(filterButtonFinder);
      await tester.pumpAndSettle();

      // Only v2 should be visible
      expect(find.text('bom dia'), findsNothing);
      expect(find.text('boa noite'), findsOneWidget);

      // Tap filter button again to restore all items
      await tester.tap(filterButtonFinder);
      await tester.pumpAndSettle();

      expect(find.text('bom dia'), findsOneWidget);
      expect(find.text('boa noite'), findsOneWidget);
    });
  });
}
