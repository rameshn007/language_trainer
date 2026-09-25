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
  Future<void> startSession({ListenRepeatMode? mode}) async {}

  @override
  Future<int> stopSession({bool recordProgress = true}) async => 10;
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
        child: const MaterialApp(
          home: ListenRepeatScreen(),
        ),
      );
    }

    testWidgets('renders simple view in portrait', (tester) async {
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
    });

    testWidgets('preserves simple view in landscape without auto-swapping UI', (tester) async {
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

      // Simple View controls should remain available
      expect(find.byKey(const Key('listen_repeat_car_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('listen_repeat_star_button')), findsOneWidget);
      expect(find.text('Balanced Mix'), findsOneWidget);
      expect(find.text('Olá amigo'), findsOneWidget);
      expect(find.text('Hello friend'), findsOneWidget);

      // In-Car Dashboard should not auto-embed
      expect(find.byKey(const Key('carplay_dash_back_button')), findsNothing);
    });

    testWidgets('tapping car mode button in landscape opens InCarDashboardScreen', (tester) async {
      final storage = FakeStorageService(initialItems: [testItem]);
      final mockAudioPlayer = MockAudioPlayer();
      when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});
      final vm = _TestLRViewModel(testItem, audioPlayer: mockAudioPlayer);

      tester.view.physicalSize = const Size(678, 466);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(storage: storage, vm: vm));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('listen_repeat_car_mode_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('carplay_dash_back_button')), findsOneWidget);
      expect(find.text('PRACTICE SET'), findsOneWidget);
    });
  });
}
