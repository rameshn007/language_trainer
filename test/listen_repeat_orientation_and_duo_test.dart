import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_screen.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:language_trainer/utils/iphone_duo_helper.dart';
import 'helpers/carplay_test_helpers.dart';

class _TestLRViewModel extends ListenRepeatViewModel {
  final LanguageItem _item;
  int startSessionCalls = 0;

  _TestLRViewModel(this._item, {required super.audioPlayer});

  @override
  ListenRepeatState build() {
    return ListenRepeatState(
      isPlaying: true,
      currentItem: _item,
      totalWordsSeen: 1,
      playbackSpeed: 1.0,
      mode: ListenRepeatMode.all,
    );
  }

  @override
  Future<void> startSession({ListenRepeatMode? mode}) async {
    startSessionCalls++;
  }

  @override
  Future<int> stopSession({bool recordProgress = true}) async {
    state = ListenRepeatState(
      isPlaying: false,
      currentItem: null,
      totalWordsSeen: state.totalWordsSeen,
      playbackSpeed: state.playbackSpeed,
      mode: state.mode,
    );
    return 10;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('IPhoneDuoHelper tests', () {
    test('identifies iPhone Duo outside screen portrait and landscape dimensions', () {
      // Outside screen portrait: 466 x 678
      expect(
        IPhoneDuoHelper.isDuoOutsidePortraitSize(const Size(466, 678)),
        isTrue,
      );
      expect(
        IPhoneDuoHelper.isDuoOutsidePortraitSize(const Size(393, 852)),
        isFalse,
      );

      // Outside screen landscape: 678 x 466
      expect(
        IPhoneDuoHelper.isDuoOutsideLandscapeSize(const Size(678, 466)),
        isTrue,
      );
      expect(
        IPhoneDuoHelper.isDuoOutsideLandscapeSize(const Size(852, 393)),
        isFalse,
      );

      // Inside screen is not outside screen
      expect(
        IPhoneDuoHelper.isDuoOutsidePortraitSize(const Size(669, 951)),
        isFalse,
      );
      expect(
        IPhoneDuoHelper.isDuoOutsideLandscapeSize(const Size(951, 669)),
        isFalse,
      );
    });

    test('identifies iPhone Duo inside screen portrait and landscape dimensions', () {
      // Inside screen portrait: 669 x 951
      expect(
        IPhoneDuoHelper.isDuoInsidePortraitSize(const Size(669, 951)),
        isTrue,
      );
      expect(
        IPhoneDuoHelper.isDuoInsidePortraitSize(const Size(393, 852)),
        isFalse,
      );

      // Inside screen landscape: 951 x 669
      expect(
        IPhoneDuoHelper.isDuoInsideLandscapeSize(const Size(951, 669)),
        isTrue,
      );
      expect(
        IPhoneDuoHelper.isDuoInsideLandscapeSize(const Size(852, 393)),
        isFalse,
      );

      // isDuoInsideSize
      expect(
        IPhoneDuoHelper.isDuoInsideSize(const Size(951, 669)),
        isTrue,
      );
      expect(
        IPhoneDuoHelper.isDuoInsideSize(const Size(669, 951)),
        isTrue,
      );
      expect(
        IPhoneDuoHelper.isDuoInsideSize(const Size(466, 678)),
        isFalse,
      );

      // isDuoSize covers both screens in both orientations
      expect(IPhoneDuoHelper.isDuoSize(const Size(466, 678)), isTrue);
      expect(IPhoneDuoHelper.isDuoSize(const Size(678, 466)), isTrue);
      expect(IPhoneDuoHelper.isDuoSize(const Size(669, 951)), isTrue);
      expect(IPhoneDuoHelper.isDuoSize(const Size(951, 669)), isTrue);
      expect(IPhoneDuoHelper.isDuoSize(const Size(393, 852)), isFalse);
    });

    test('DuoAlignedFabLocation centers FAB horizontally at screenWidth - 38 on outside screen', () {
      const location = DuoAlignedFabLocation(fabCenterFromRight: 38.0);
      final geometry = ScaffoldPrelayoutGeometry(
        bottomSheetSize: Size.zero,
        contentBottom: 678,
        contentTop: 0,
        floatingActionButtonSize: const Size(56, 56),
        materialBannerSize: Size.zero,
        minInsets: EdgeInsets.zero,
        minViewPadding: EdgeInsets.zero,
        scaffoldSize: const Size(466, 678),
        snackBarSize: Size.zero,
        textDirection: TextDirection.ltr,
      );

      final offset = location.getOffset(geometry);
      expect(offset.dx, equals(400.0));
      expect(offset.dx + 28.0, equals(466.0 - 38.0)); // Center aligns with wifi icon
    });

    test('DuoAlignedFabLocation centers FAB horizontally at screenWidth - 38 on inside landscape screen', () {
      const location = DuoAlignedFabLocation(fabCenterFromRight: 38.0);
      final geometry = ScaffoldPrelayoutGeometry(
        bottomSheetSize: Size.zero,
        contentBottom: 669,
        contentTop: 0,
        floatingActionButtonSize: const Size(56, 56),
        materialBannerSize: Size.zero,
        minInsets: EdgeInsets.zero,
        minViewPadding: EdgeInsets.zero,
        scaffoldSize: const Size(951, 669),
        snackBarSize: Size.zero,
        textDirection: TextDirection.ltr,
      );

      final offset = location.getOffset(geometry);
      expect(offset.dx, equals(951.0 - 38.0 - 28.0)); // 885.0
      expect(offset.dx + 28.0, equals(951.0 - 38.0)); // Center aligns with wifi icon
    });

    testWidgets('isPhoneOrDuo identifies phone, Duo, and tablet screens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const Scaffold(body: SizedBox.shrink(key: Key('test_box'))),
        ),
      );

      BuildContext getContext() => tester.element(find.byKey(const Key('test_box')));

      // Phone portrait (393 x 852)
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pump();
      expect(IPhoneDuoHelper.isPhoneOrDuo(getContext()), isTrue);

      // Phone landscape (852 x 393) - shortestSide 393 < 600
      tester.view.physicalSize = const Size(852, 393);
      await tester.pump();
      expect(IPhoneDuoHelper.isPhoneOrDuo(getContext()), isTrue);

      // Duo outside portrait (466 x 678)
      tester.view.physicalSize = const Size(466, 678);
      await tester.pump();
      expect(IPhoneDuoHelper.isPhoneOrDuo(getContext()), isTrue);

      // Duo outside landscape (678 x 466)
      tester.view.physicalSize = const Size(678, 466);
      await tester.pump();
      expect(IPhoneDuoHelper.isPhoneOrDuo(getContext()), isTrue);

      // Duo inside landscape (951 x 669) - shortestSide 669 >= 600, but Duo -> true
      tester.view.physicalSize = const Size(951, 669);
      await tester.pump();
      expect(IPhoneDuoHelper.isPhoneOrDuo(getContext()), isTrue);

      // iPad portrait (768 x 1024) - shortestSide 768 >= 600, not Duo -> false
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pump();
      expect(IPhoneDuoHelper.isPhoneOrDuo(getContext()), isFalse);

      // iPad landscape (1024 x 768) - shortestSide 768 >= 600, not Duo -> false
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pump();
      expect(IPhoneDuoHelper.isPhoneOrDuo(getContext()), isFalse);
    });
  });

  group('ListenRepeatScreen Orientation Switching', () {
    final testItem = LanguageItem(
      id: 'item1',
      portuguese: 'Olá amigo',
      english: 'Hello friend',
    );

    Widget createWidgetUnderTest({
      required FakeStorageService storage,
      required _TestLRViewModel vm,
    }) {
      final counts = {
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
        child: MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: const ListenRepeatScreen(),
        ),
      );
    }

    testWidgets('renders simple view on iPad/tablet in landscape (1024 x 768)', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      final vm = _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer);

      // Set iPad landscape: 1024 x 768 (shortestSide = 768 >= 600, not Duo)
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pumpAndSettle();

      // On iPad/tablet in landscape, regular study view is maintained
      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('listen_repeat_star_button')), findsOneWidget);
      expect(find.text('Balanced Mix'), findsOneWidget);
      expect(find.text('Olá amigo'), findsOneWidget);
      expect(find.text('Hello friend'), findsOneWidget);

      // Car View should NOT be auto-mounted on iPad/tablet
      expect(find.byKey(const Key('carplay_dash_back_button')), findsNothing);
      expect(find.text('PRACTICE SET'), findsNothing);
    });

    testWidgets('rotating to landscape after session stopped does not auto-restart session', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      final vm = _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer);

      // Start in Portrait on phone
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pumpAndSettle();

      // Initial session started once on mount
      expect(vm.startSessionCalls, equals(1));

      // User stops session
      await vm.stopSession();
      await tester.pumpAndSettle();

      expect(vm.state.isPlaying, isFalse);
      expect(vm.state.currentItem, isNull);

      // Rotate to Landscape
      tester.view.physicalSize = const Size(678, 466);
      await tester.pumpAndSettle();

      // Embedded InCarDashboardScreen should NOT trigger another startSession()
      expect(vm.startSessionCalls, equals(1));
    });

    testWidgets('renders simple view when in portrait', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      final vm = _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer);

      // Set Portrait (e.g. 466 x 678 Duo outside portrait)
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pumpAndSettle();

      // Simple View indicators
      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('listen_repeat_star_button')), findsOneWidget);
      expect(find.text('Balanced Mix'), findsOneWidget);
      expect(find.text('Olá amigo'), findsOneWidget);
      expect(find.text('Hello friend'), findsOneWidget);

      // Car View elements should NOT be present in portrait
      expect(find.byKey(const Key('carplay_dash_back_button')), findsNothing);
      expect(find.text('PRACTICE SET'), findsNothing);
    });

    testWidgets('renders car view when in landscape', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      final vm = _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer);

      // Set Landscape (e.g. 678 x 466 Duo outside landscape)
      tester.view.physicalSize = const Size(678, 466);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pumpAndSettle();

      // In-Car Dashboard view elements should be present
      expect(find.byKey(const Key('carplay_dash_back_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_stop_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_star_button')), findsOneWidget);
      expect(find.text('PRACTICE SET'), findsOneWidget);
      expect(find.text('PLAYBACK'), findsOneWidget);
      expect(find.text('Olá amigo'), findsOneWidget);
      expect(find.text('Hello friend'), findsOneWidget);

      // Simple view specific button should NOT be present
      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsNothing);
    });

    testWidgets('dynamically transitions between simple view and car view on rotation', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      final vm = _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer);

      // Start in Portrait
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_back_button')), findsNothing);

      // Rotate to Landscape
      tester.view.physicalSize = const Size(678, 466);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('carplay_dash_back_button')), findsOneWidget);
      expect(find.text('PRACTICE SET'), findsOneWidget);
      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsNothing);

      // Rotate back to Portrait
      tester.view.physicalSize = const Size(466, 678);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_back_button')), findsNothing);
    });

    testWidgets('renders car view when in landscape on inside screen (951 x 669)', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      final vm = _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer);

      // Set inside screen landscape: 951 x 669
      tester.view.physicalSize = const Size(951, 669);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pumpAndSettle();

      // In-Car Dashboard view elements should be present
      expect(find.byKey(const Key('carplay_dash_back_button')), findsOneWidget);
      expect(find.byKey(const Key('carplay_dash_stop_button')), findsOneWidget);
      expect(find.text('PRACTICE SET'), findsOneWidget);
      expect(find.text('Olá amigo'), findsOneWidget);
      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsNothing);
    });
  });
}
