import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/ui/listen_repeat/in_car_dashboard_screen.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'helpers/carplay_test_helpers.dart';

class _MockDashboardLRViewModel extends ListenRepeatViewModel {
  final LanguageItem _initialItem;
  bool togglePlayPauseCalled = false;
  bool previousWordCalled = false;
  bool nextWordCalled = false;
  bool shufflePoolCalled = false;
  bool cycleSpeedCalled = false;
  ListenRepeatMode? switchedMode;

  final List<LanguageItem>? _initialPool;
  final int _initialWordsSeen;

  _MockDashboardLRViewModel(
    this._initialItem, {
    required super.audioPlayer,
    List<LanguageItem>? initialPool,
    int initialWordsSeen = 8,
  })  : _initialPool = initialPool,
        _initialWordsSeen = initialWordsSeen;

  @override
  ListenRepeatState build() {
    return ListenRepeatState(
      currentItem: _initialItem,
      pool: _initialPool ?? [_initialItem],
      isPlaying: false,
      totalWordsSeen: _initialWordsSeen,
      mode: ListenRepeatMode.verbs,
    );
  }

  @override
  Future<void> startSession({ListenRepeatMode? mode}) async {}

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCalled = true;
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  @override
  Future<void> previousWord() async {
    previousWordCalled = true;
  }

  @override
  Future<void> nextWord() async {
    nextWordCalled = true;
  }

  @override
  Future<void> shufflePool() async {
    shufflePoolCalled = true;
  }

  @override
  double cycleSpeed() {
    cycleSpeedCalled = true;
    final next = state.playbackSpeed == 1.0 ? 1.25 : 1.0;
    state = state.copyWith(playbackSpeed: next);
    return next;
  }

  @override
  Future<void> setMode(ListenRepeatMode mode) async {
    switchedMode = mode;
    state = state.copyWith(mode: mode);
  }

  @override
  Future<int> stopSession({bool recordProgress = true}) async => 10;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('in_car_dash_test');
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

  final testItem = LanguageItem(
    id: 'dash_item_1',
    portuguese: 'Nós vamos ouvir',
    english: 'We are going to hear',
    notes: 'Futuro (vamos) • nós',
  );

  Widget createWidgetUnderTest({
    required FakeStorageService storage,
    required _MockDashboardLRViewModel vm,
    Map<ListenRepeatMode, int>? modeCounts,
  }) {
    final counts = modeCounts ?? {
      ListenRepeatMode.all: 20,
      ListenRepeatMode.verbs: 10,
      ListenRepeatMode.prepositions: 5,
      ListenRepeatMode.phrases: 8,
      ListenRepeatMode.vocabulary: 15,
    };
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storage),
        listenRepeatViewModelProvider.overrideWith(() => vm),
        listenRepeatModeCountsProvider.overrideWith((ref) => Future.value(counts)),
      ],
      child: const MaterialApp(
        home: InCarDashboardScreen(),
      ),
    );
  }

  group('InCarDashboardScreen Widget Tests', () {
    testWidgets('renders all 3 columns with tokens and data', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final audioPlayer = MockAudioPlayer();
      final vm = _MockDashboardLRViewModel(testItem, audioPlayer: audioPlayer);

      // Set landscape automotive viewport (e.g. 1024x600)
      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pump();

      // Top Bar
      expect(find.text('Listen & Repeat'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_stop_button')), findsOneWidget);
      expect(find.text('Stop'), findsNWidgets(2)); // Top action and bottom pill button

      // Left Column: Practice Sets with precomputed word count badges (never hardcoded 12)
      expect(find.text('PRACTICE SET'), findsOneWidget);
      expect(find.text('Balanced Mix'), findsOneWidget);
      expect(find.text('20 words'), findsOneWidget);
      expect(find.text('Verbs & Tenses'), findsOneWidget);
      expect(find.text('10 words'), findsOneWidget);
      expect(find.text('Prepositions'), findsOneWidget);
      expect(find.text('5 words'), findsOneWidget);
      expect(find.text('12 words'), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget); // Selected Verbs mode checkmark

      // Center Column: Flashcard & Status (infinite deck wrapping: word 8 of 1 -> Word 1 of 1)
      expect(find.text('Futuro (vamos) • nós'), findsOneWidget);
      expect(find.text('Nós vamos ouvir'), findsOneWidget);
      expect(find.text('We are going to hear'), findsOneWidget);
      expect(find.text('... Ready'), findsOneWidget);
      expect(find.text('Word 1 of 1'), findsOneWidget);
      expect(find.text('Word 8 of 1'), findsNothing);
      expect(find.byKey(const Key('carplay_dash_star_button')), findsOneWidget);

      // Right Column: Playback Controls
      expect(find.text('PLAYBACK'), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_prev_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_play_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_next_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_shuffle_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_bottom_stop_button')), findsOneWidget);
    });

    testWidgets('infinite deck wrapping displays correct Word X of Y position', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final audioPlayer = MockAudioPlayer();
      final pool = List.generate(
        30,
        (i) => LanguageItem(
          id: 'item_$i',
          portuguese: 'Palavra $i',
          english: 'Word $i',
        ),
      );
      final vm = _MockDashboardLRViewModel(
        testItem,
        audioPlayer: audioPlayer,
        initialPool: pool,
        initialWordsSeen: 45,
      );

      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pump();

      // ((45 - 1) % 30) + 1 = 15 -> Word 15 of 30 (not Word 45 of 30)
      expect(find.text('Word 15 of 30'), findsOneWidget);
      expect(find.text('Word 45 of 30'), findsNothing);
    });

    testWidgets('star button toggles item flag in storage and updates icon', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final audioPlayer = MockAudioPlayer();
      final vm = _MockDashboardLRViewModel(testItem, audioPlayer: audioPlayer);

      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pump();

      expect(storage.isItemFlagged(testItem.id), isFalse);
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);

      // Tap Star button
      await tester.tap(find.byKey(const Key('carplay_dash_star_button')));
      await tester.pump();

      expect(storage.isItemFlagged(testItem.id), isTrue);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      // Tap again to unflag
      await tester.tap(find.byKey(const Key('carplay_dash_star_button')));
      await tester.pump();

      expect(storage.isItemFlagged(testItem.id), isFalse);
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    });

    testWidgets('playback controls invoke view model actions', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final audioPlayer = MockAudioPlayer();
      final vm = _MockDashboardLRViewModel(testItem, audioPlayer: audioPlayer);

      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pump();

      // Tap Play/Pause
      await tester.tap(find.byKey(const Key('carplay_dash_play_button')));
      await tester.pump();
      expect(vm.togglePlayPauseCalled, isTrue);

      // Tap Next
      await tester.tap(find.byKey(const Key('carplay_dash_next_button')));
      await tester.pump();
      expect(vm.nextWordCalled, isTrue);

      // Tap Prev
      await tester.tap(find.byKey(const Key('carplay_dash_prev_button')));
      await tester.pump();
      expect(vm.previousWordCalled, isTrue);

      // Tap Shuffle
      await tester.tap(find.byKey(const Key('carplay_dash_shuffle_button')));
      await tester.pump();
      expect(vm.shufflePoolCalled, isTrue);

      // Tap Speed
      await tester.tap(find.byKey(const Key('carplay_dash_speed_button')));
      await tester.pump();
      expect(vm.cycleSpeedCalled, isTrue);
    });

    testWidgets('practice set tapping switches mode', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final audioPlayer = MockAudioPlayer();
      final vm = _MockDashboardLRViewModel(testItem, audioPlayer: audioPlayer);

      tester.view.physicalSize = const Size(1024, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pump();

      // Tap Prepositions
      await tester.tap(find.byKey(const Key('carplay_dash_mode_prepositions')));
      await tester.pump();
      expect(vm.switchedMode, ListenRepeatMode.prepositions);
    });
  });
}
