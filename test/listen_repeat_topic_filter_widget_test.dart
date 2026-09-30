import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_screen.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/carplay_test_helpers.dart';

class _TopicFilterMockVM extends ListenRepeatViewModel {
  final LanguageItem _item;
  String? lastSelectedSubCategory;
  bool startSessionCalled = false;

  final bool _isAutoPlayActiveInitial;

  _TopicFilterMockVM(
    this._item, {
    required super.audioPlayer,
    bool initialAutoPlay = false,
  }) : _isAutoPlayActiveInitial = initialAutoPlay;

  @override
  ListenRepeatState build() {
    return ListenRepeatState(
      currentItem: _item,
      pool: [_item],
      isPlaying: true,
      isAutoPlayActive: _isAutoPlayActiveInitial,
      mode: ListenRepeatMode.topics,
      subCategory: null,
    );
  }

  @override
  Future<void> startSession({
    ListenRepeatMode? mode,
    String? subCategory,
    bool clearSubCategory = false,
  }) async {
    startSessionCalled = true;
    final effSub = clearSubCategory || subCategory == 'All Topics' ? null : subCategory;
    state = state.copyWith(
      subCategory: effSub,
      clearSubCategory: effSub == null,
    );
  }

  @override
  Future<void> setSubCategory(String? subCategory) async {
    lastSelectedSubCategory = subCategory;
    await startSession(
      mode: state.mode,
      subCategory: subCategory,
      clearSubCategory: subCategory == null || subCategory == 'All Topics',
    );
  }

  @override
  Future<int> stopSession({bool recordProgress = true}) async => 0;

  void setAutoPlayActive(bool active) {
    state = state.copyWith(isAutoPlayActive: active);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('topic_filter_widget_test');
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
    id: 'test_1',
    portuguese: 'a sala de estar',
    english: 'the living room',
    notes: 'House & Rooms',
  );

  Widget createWidgetUnderTest({
    required StorageService storage,
    required _TopicFilterMockVM vm,
  }) {
    final counts = {
      ListenRepeatMode.all: 20,
      ListenRepeatMode.topics: 10,
      ListenRepeatMode.verbs: 5,
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
        home: ListenRepeatScreen(),
      ),
    );
  }

  testWidgets('renders topic filter chips when in Topics mode and drives selection', (tester) async {
    final storage = FakeStorageService(initialItems: [testItem]);
    final mockAudioPlayer = MockAudioPlayer();
    when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(true));
    when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
    when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
    final vm = _TopicFilterMockVM(testItem, audioPlayer: mockAudioPlayer, initialAutoPlay: true);

    await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
    await tester.pumpAndSettle();

    // Verify all 5 topic chips are present
    final allTopicsChip = find.byKey(const Key('topic_filter_all_topics'));
    final houseRoomsChip = find.byKey(const Key('topic_filter_house___rooms'));
    final householdChip = find.byKey(const Key('topic_filter_household_items'));
    final bodyHealthChip = find.byKey(const Key('topic_filter_body___health'));
    final everydayChip = find.byKey(const Key('topic_filter_everyday_items'));

    expect(allTopicsChip, findsOneWidget);
    expect(houseRoomsChip, findsOneWidget);
    expect(householdChip, findsOneWidget);
    expect(bodyHealthChip, findsOneWidget);
    expect(everydayChip, findsOneWidget);

    // Initial selected chip should be 'All Topics'
    final initialAllChoice = tester.widget<ChoiceChip>(allTopicsChip);
    expect(initialAllChoice.selected, isTrue);

    // Tap 'House & Rooms'
    await tester.tap(houseRoomsChip);
    await tester.pumpAndSettle();

    expect(vm.lastSelectedSubCategory, equals('House & Rooms'));
    final houseRoomsChoice = tester.widget<ChoiceChip>(houseRoomsChip);
    expect(houseRoomsChoice.selected, isTrue);

    // Tap 'All Topics' to clear
    await tester.tap(allTopicsChip);
    await tester.pumpAndSettle();

    expect(vm.lastSelectedSubCategory, equals('All Topics'));
    final finalAllChoice = tester.widget<ChoiceChip>(allTopicsChip);
    expect(finalAllChoice.selected, isTrue);
  });

  testWidgets('shields Prev, Next, and Shuffle controls when isAutoPlayActive is false', (tester) async {
    final storage = FakeStorageService(initialItems: [testItem]);
    final mockAudioPlayer = MockAudioPlayer();
    when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
    when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
    when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
    // Start with isAutoPlayActive = false (simulating deck reload / build)
    final vm = _TopicFilterMockVM(testItem, audioPlayer: mockAudioPlayer, initialAutoPlay: false);

    await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
    await tester.pumpAndSettle();

    // Verify Prev button is disabled
    final prevButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Prev'),
    );
    expect(prevButton.onPressed, isNull);

    // Verify Next button is disabled
    final nextButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Next'),
    );
    expect(nextButton.onPressed, isNull);

    // Verify Shuffle button is disabled
    final shuffleButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Shuffle'),
    );
    expect(shuffleButton.onPressed, isNull);

    // Re-enable autoplay (session starts)
    vm.setAutoPlayActive(true);
    await tester.pumpAndSettle();

    final prevEnabled = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Prev'),
    );
    expect(prevEnabled.onPressed, isNotNull);

    final nextEnabled = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Next'),
    );
    expect(nextEnabled.onPressed, isNotNull);

    final shuffleEnabled = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Shuffle'),
    );
    expect(shuffleEnabled.onPressed, isNotNull);
  });
}
