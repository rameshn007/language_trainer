import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/services/notification_service.dart';
import 'package:language_trainer/services/progress_service.dart';
import 'package:language_trainer/services/verb_service.dart';
import 'package:language_trainer/ui/home_screen.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_screen.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:language_trainer/ui/vocabulary/vocabulary_list_screen.dart';
import 'package:language_trainer/utils/iphone_duo_helper.dart';
import 'helpers/carplay_test_helpers.dart';

class _MockNotificationService extends Mock implements NotificationService {}
class _MockVerbService extends Mock implements VerbService {}

class RealDeviceConfig {
  final String name;
  final Size logicalSize;
  final EdgeInsets insets;
  final double pixelRatio;

  const RealDeviceConfig({
    required this.name,
    required this.logicalSize,
    this.insets = EdgeInsets.zero,
    this.pixelRatio = 3.0,
  });
}

const realisticSnapshot = ProgressSnapshot(
  totalXP: 1450,
  todayXP: 130,
  dailyGoal: 100,
  currentStreak: 12,
  todaySessions: 4,
  masteryDistribution: {0: 10, 1: 8, 2: 5, 3: 12, 4: 15},
);

class _RealisticProgressService extends Notifier<ProgressSnapshot> with Mock implements ProgressService {
  final ProgressSnapshot _snapshot;
  _RealisticProgressService([this._snapshot = realisticSnapshot]);

  @override
  ProgressSnapshot build() => _snapshot;
}

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

Widget testApp({required Widget home}) {
  return MaterialApp(
    theme: ThemeData(platform: TargetPlatform.iOS),
    home: home,
  );
}

void main() {
  tearDown(() {
    IPhoneDuoHelper.resetForTesting();
  });

  group('Canary Layout & Overflow Harness Verification Tests (Falsifiability Proofs)', () {
    testWidgets('CANARY: Test harness detects horizontal RenderFlex overflow via tester.takeException()', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: Row(
                children: [
                  Container(width: 500, height: 50, color: Colors.red),
                ],
              ),
            ),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isNotNull, reason: 'Harness must not swallow horizontal RenderFlex overflow');
      expect(error.toString(), contains('overflowed by 300 pixels'));
    });

    testWidgets('CANARY: Test harness detects vertical RenderFlex overflow via tester.takeException()', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: Column(
                children: [
                  Container(width: 50, height: 500, color: Colors.blue),
                ],
              ),
            ),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isNotNull, reason: 'Harness must not swallow vertical RenderFlex overflow');
      expect(error.toString(), contains('overflowed by 300 pixels'));
    });

    testWidgets('CANARY: Delayed animation content (FadeInUp) overflows ARE detected when pumped past delay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Row(
                  children: [
                    Container(width: 600, height: 50, color: Colors.green),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      // Pumping past 200ms delay triggers child painting and detects the 280px overflow
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      final error = tester.takeException();
      expect(error, isNotNull, reason: 'Pumping past animation delay must reveal paint-time overflows');
      expect(error.toString(), contains('overflowed by 280 pixels'));
    });

    testWidgets('CANARY: Geometry assertion detects width constraint violation independently of exception', (tester) async {
      const screenWidth = 320.0;
      tester.view.physicalSize = const Size(screenWidth, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  width: screenWidth + 50,
                  height: 40,
                  child: Container(key: const Key('oversized_box'), color: Colors.purple),
                ),
              ],
            ),
          ),
        ),
      );

      final contentRect = tester.getRect(find.byKey(const Key('oversized_box')));
      expect(contentRect.right, greaterThan(screenWidth), reason: 'Geometry measurement detects content extending beyond screen edge');
    });
  });

  group('Dynamic Island & Landscape Geometry Unit Tests (Synthetic Scaffold)', () {
    testWidgets('Synthetic Scaffold: Landscape with Dynamic Island on left clears left inset and places FAB at rightmost with bottom home indicator offset', (tester) async {
      // iPhone 17 Landscape Left (932 x 430) with Dynamic Island on left (59 pt) and home indicator (21 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63); // 59 pt left, 21 pt bottom
      tester.view.viewPadding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) {
              contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
              fabLocation = IPhoneDuoHelper.getFabLocation(context);

              return Scaffold(
                floatingActionButtonLocation: fabLocation,
                floatingActionButton: FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.star),
                ),
                body: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding.left,
                    10,
                    contentPadding.right,
                    80,
                  ),
                  child: Container(
                    key: const Key('test_content_card'),
                    color: Colors.blue,
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Left inset must clear the Dynamic Island (59.0 pt) with margin
      expect(contentPadding.left, greaterThanOrEqualTo(75.0));

      // Right inset must leave a gutter for the FABs
      expect(contentPadding.right, greaterThanOrEqualTo(84.0));

      final contentRect = tester.getRect(find.byKey(const Key('test_content_card')));
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      // FAB must be strictly to the right of the content (no overlap)
      expect(fabRect.left, greaterThan(contentRect.right));

      // FAB right edge should be near the right screen edge (16 pt margin)
      expect(932.0 - fabRect.right, closeTo(16.0, 2.0));

      // FAB bottom edge must clear the 21.0 pt home indicator (minViewPadding.bottom > 0 branch: 21 pt + 16 pt = 37 pt)
      expect(430.0 - fabRect.bottom, closeTo(37.0, 2.0));

      // Fab location is standard landscape location
      expect(fabLocation, equals(IPhoneDuoHelper.standardLandscapeFabLocation));
    });

    testWidgets('Synthetic Scaffold: Landscape with Dynamic Island on right clears right inset and positions FAB inside safe area', (tester) async {
      // iPhone 17 Landscape Right (932 x 430) with Dynamic Island on right (59 pt) and home indicator (21 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63); // 59 pt right, 21 pt bottom
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) {
              contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
              fabLocation = IPhoneDuoHelper.getFabLocation(context);

              return Scaffold(
                floatingActionButtonLocation: fabLocation,
                floatingActionButton: FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.star),
                ),
                body: Padding(
                  padding: EdgeInsets.fromLTRB(
                    contentPadding.left,
                    10,
                    contentPadding.right,
                    80,
                  ),
                  child: Container(
                    key: const Key('test_content_card_right'),
                    color: Colors.blue,
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Left inset is standard margin (20.0 pt)
      expect(contentPadding.left, equals(20.0));

      // Right inset must clear both the Dynamic Island (59 pt) and the FAB gutter (84 pt) -> 143 pt
      expect(contentPadding.right, greaterThanOrEqualTo(143.0));

      final contentRect = tester.getRect(find.byKey(const Key('test_content_card_right')));
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      // FAB must be strictly to the right of the content (no overlap)
      expect(fabRect.left, greaterThan(contentRect.right));

      // FAB right edge must clear the Dynamic Island (59.0 pt from screen right) with 16 pt margin = 75 pt
      expect(932.0 - fabRect.right, closeTo(75.0, 2.0));

      // FAB bottom edge must clear the 21.0 pt home indicator (37.0 pt from bottom)
      expect(430.0 - fabRect.bottom, closeTo(37.0, 2.0));

      // FAB location is LandscapeRightFabLocation with rightMargin == 75.0
      expect(fabLocation, isA<LandscapeRightFabLocation>());
      expect((fabLocation as LandscapeRightFabLocation).rightMargin, equals(75.0));
    });

    testWidgets('Synthetic Scaffold: Landscape with zero insets uses standard 16 pt margins', (tester) async {
      tester.view.physicalSize = const Size(1334, 750);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = FakeViewPadding.zero;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) {
              contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
              fabLocation = IPhoneDuoHelper.getFabLocation(context);

              return Scaffold(
                floatingActionButtonLocation: fabLocation,
                floatingActionButton: FloatingActionButton(
                  onPressed: () {},
                  child: const Icon(Icons.star),
                ),
                body: Container(),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(contentPadding.left, equals(20.0));
      expect(contentPadding.right, equals(84.0));
      expect(fabLocation, equals(IPhoneDuoHelper.standardLandscapeFabLocation));

      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      expect(667.0 - fabRect.right, closeTo(16.0, 2.0));
      // With minViewPadding.bottom == 0, bottom margin is 16.0 pt
      expect(375.0 - fabRect.bottom, closeTo(16.0, 2.0));
    });

    testWidgets('Portrait preserves standard 20 pt insets and endFloat location', (tester) async {
      // iPhone 17 Portrait (430 x 932)
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 177, right: 0, bottom: 102);
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 177, right: 0, bottom: 102);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) {
              contentPadding = IPhoneDuoHelper.getContentHorizontalPadding(context);
              fabLocation = IPhoneDuoHelper.getFabLocation(context);
              return Container();
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(contentPadding.left, equals(20.0));
      expect(contentPadding.right, equals(20.0));
      expect(fabLocation, equals(FloatingActionButtonLocation.endFloat));
    });
  });

  group('FAB Location Value Equality Tests (Prevent Animation Restart)', () {
    test('LandscapeRightFabLocation implements value equality and hashCode', () {
      const loc1 = LandscapeRightFabLocation(rightMargin: 75.0, bottomMargin: 16.0);
      const loc2 = LandscapeRightFabLocation(rightMargin: 75.0, bottomMargin: 16.0);
      const loc3 = LandscapeRightFabLocation(rightMargin: 16.0, bottomMargin: 16.0);

      expect(loc1, equals(loc2));
      expect(loc1.hashCode, equals(loc2.hashCode));
      expect(loc1 == loc2, isTrue);
      expect(loc1 == loc3, isFalse);
    });

    test('DuoAlignedFabLocation implements value equality and hashCode', () {
      const loc1 = DuoAlignedFabLocation(fabCenterFromRight: 38.0, bottomMargin: 16.0);
      const loc2 = DuoAlignedFabLocation(fabCenterFromRight: 38.0, bottomMargin: 16.0);
      const loc3 = DuoAlignedFabLocation(fabCenterFromRight: 50.0, bottomMargin: 16.0);

      expect(loc1, equals(loc2));
      expect(loc1.hashCode, equals(loc2.hashCode));
      expect(loc1 == loc2, isTrue);
      expect(loc1 == loc3, isFalse);
    });

    testWidgets('IPhoneDuoHelper.getFabLocation returns equal instances across rebuilds', (tester) async {
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      late FloatingActionButtonLocation locBuild1;
      late FloatingActionButtonLocation locBuild2;
      int buildCount = 0;

      await tester.pumpWidget(
        testApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              buildCount++;
              if (buildCount == 1) {
                locBuild1 = IPhoneDuoHelper.getFabLocation(context);
              } else {
                locBuild2 = IPhoneDuoHelper.getFabLocation(context);
              }
              return Scaffold(
                floatingActionButtonLocation: IPhoneDuoHelper.getFabLocation(context),
                floatingActionButton: FloatingActionButton(
                  onPressed: () => setState(() {}),
                  child: const Icon(Icons.refresh),
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger rebuild
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(buildCount, equals(2));
      // Value equality prevents Scaffold from restarting _moveFab animation
      expect(locBuild1, equals(locBuild2));
      expect(locBuild1 == locBuild2, isTrue);
    });
  });

  group('Real Screen Landscape Layout Tests', () {
    testWidgets('VocabularyListScreen applies correct left clearance and right gutter in landscape left (Dynamic Island left = 59pt, home indicator bottom = 21pt)', (tester) async {
      // iPhone 17 Landscape Left (932 x 430) with Dynamic Island on left (59 pt) and home indicator (21 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      tester.view.viewPadding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      final mockTts = MockTtsService();
      when(() => mockTts.setRate(any())).thenAnswer((_) async {});
      when(() => mockTts.stop()).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
          child: testApp(
            home: const VocabularyListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify ListView padding has left clearance >= 75.0 (59.0pt Dynamic Island + 16pt margin) and right >= 84.0
      final listView = tester.widget<ListView>(find.byType(ListView));
      final EdgeInsets listPadding = listView.padding as EdgeInsets;
      expect(listPadding.left, greaterThanOrEqualTo(75.0));
      expect(listPadding.right, greaterThanOrEqualTo(84.0));

      // 2. Verify search bar TextField left is clear of Dynamic Island
      final searchRect = tester.getRect(find.byType(TextField));
      expect(searchRect.left, greaterThanOrEqualTo(75.0));

      // 3. Verify FAB rightmost placement and bottom home indicator clearance (37 pt = 21 pt indicator + 16 pt margin)
      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      expect(932.0 - fabRect.right, closeTo(16.0, 2.0));
      expect(430.0 - fabRect.bottom, closeTo(37.0, 2.0));
    });

    testWidgets('VocabularyListScreen applies correct right clearance (padding.right + 84) and FAB offset (rightMargin 75) in landscape right (Dynamic Island right = 59pt, home indicator bottom = 21pt)', (tester) async {
      // iPhone 17 Landscape Right (932 x 430) with Dynamic Island on right (59 pt) and home indicator (21 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63);
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      final mockTts = MockTtsService();
      when(() => mockTts.setRate(any())).thenAnswer((_) async {});
      when(() => mockTts.stop()).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
          child: testApp(
            home: const VocabularyListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify ListView padding has right clearance >= 143.0 (59.0 pt Dynamic Island + 84.0 pt FAB gutter)
      final listView = tester.widget<ListView>(find.byType(ListView));
      final EdgeInsets listPadding = listView.padding as EdgeInsets;
      expect(listPadding.left, equals(20.0));
      expect(listPadding.right, greaterThanOrEqualTo(143.0));

      // 2. Verify search bar TextField right edge is clear of Dynamic Island and FAB gutter
      final searchRect = tester.getRect(find.byType(TextField));
      expect(searchRect.left, equals(20.0));
      expect(932.0 - searchRect.right, greaterThanOrEqualTo(143.0));

      // 3. Verify FAB right edge clears Dynamic Island (75 pt from screen right) and bottom clears home indicator (37 pt)
      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      expect(932.0 - fabRect.right, closeTo(75.0, 2.0));
      expect(430.0 - fabRect.bottom, closeTo(37.0, 2.0));

      // 4. Verify FAB does not overlap search bar or list view items
      expect(fabRect.left, greaterThan(searchRect.right));
    });

    testWidgets('HomeScreen applies correct left clearance and right FAB gutter in landscape left (Dynamic Island left = 59pt, home indicator bottom = 21pt)', (tester) async {
      // iPhone 17 Landscape Left (932 x 430) with Dynamic Island on left (59 pt) and home indicator (21 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      tester.view.viewPadding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', true);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => MockProgressService()),
          ],
          child: testApp(
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify CustomScrollView is present
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify HomeScreen cards are clear of the Dynamic Island (>= 75.0 pt on left)
      final cardRect = tester.getRect(find.byType(Card).first);
      expect(cardRect.left, greaterThanOrEqualTo(75.0));
      // Verify right edge leaves gutter for FABs (>= 84.0 pt)
      expect(932.0 - cardRect.right, greaterThanOrEqualTo(84.0));

      // Verify FAB right edge and bottom clearance (37 pt from bottom for bottom FAB)
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsWidgets);
      final bottomFabRect = tester.getRect(fabFinder.last);
      expect(932.0 - bottomFabRect.right, closeTo(16.0, 2.0));
      expect(430.0 - bottomFabRect.bottom, closeTo(37.0, 2.0));

      // Verify FAB is strictly to the right of content
      expect(bottomFabRect.left, greaterThanOrEqualTo(cardRect.right));
    });

    testWidgets('HomeScreen applies correct right clearance (padding.right + 84) and FAB offset (rightMargin 75) in landscape right (Dynamic Island right = 59pt, home indicator bottom = 21pt)', (tester) async {
      // iPhone 17 Landscape Right (932 x 430) with Dynamic Island on right (59 pt) and home indicator (21 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63);
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', true);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => MockProgressService()),
          ],
          child: testApp(
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify HomeScreen cards are clear of the Dynamic Island and FAB gutter (>= 143.0 pt from right)
      final cardRect = tester.getRect(find.byType(Card).first);
      expect(cardRect.left, equals(20.0));
      expect(932.0 - cardRect.right, greaterThanOrEqualTo(143.0));

      // Verify FAB right edge clears Dynamic Island (75.0 pt from right) and bottom clears home indicator (37.0 pt from bottom)
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsWidgets);
      final bottomFabRect = tester.getRect(fabFinder.last);
      expect(932.0 - bottomFabRect.right, closeTo(75.0, 2.0));
      expect(430.0 - bottomFabRect.bottom, closeTo(37.0, 2.0));

      // Verify FAB is strictly to the right of content
      expect(bottomFabRect.left, greaterThanOrEqualTo(cardRect.right));
    });

    testWidgets('HomeScreen on Duo outside landscape (678x466) with home indicator: FAB aligned at screenWidth - 38 and above home indicator', (tester) async {
      tester.view.physicalSize = const Size(2034, 1398);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 0, right: 0, bottom: 63); // 21 pt bottom
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 0, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', true);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => MockProgressService()),
          ],
          child: testApp(
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify card right edge leaves 76 pt rail for Wi-Fi icon and FAB column
      final cardRect = tester.getRect(find.byType(Card).first);
      expect(678.0 - cardRect.right, greaterThanOrEqualTo(76.0));

      // Verify FAB is centered at screenWidth - 38.0 pt
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsWidgets);
      final bottomFabRect = tester.getRect(fabFinder.last);
      final fabCenter = bottomFabRect.left + (bottomFabRect.width / 2);
      expect(fabCenter, closeTo(678.0 - 38.0, 1.0));

      // Verify FAB bottom clears the 21 pt home indicator (37.0 pt from bottom for bottom FAB)
      expect(466.0 - bottomFabRect.bottom, closeTo(37.0, 2.0));

      // Verify FAB is strictly to the right of content
      expect(bottomFabRect.left, greaterThanOrEqualTo(cardRect.right));
    });

    testWidgets('HomeScreen on Duo outside portrait (466x678) with status bar and home indicator: FAB aligned at screenWidth - 38 and above home indicator', (tester) async {
      tester.view.physicalSize = const Size(1398, 2034);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 72, right: 0, bottom: 63); // 24 pt top, 21 pt bottom
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 72, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', true);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => _RealisticProgressService(realisticSnapshot)),
          ],
          child: testApp(
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify card right edge leaves 76 pt rail
      final cardRect = tester.getRect(find.byType(Card).first);
      expect(466.0 - cardRect.right, greaterThanOrEqualTo(76.0));

      // Verify FAB is centered at screenWidth - 38.0 pt
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsWidgets);
      final bottomFabRect = tester.getRect(fabFinder.last);
      final fabCenter = bottomFabRect.left + (bottomFabRect.width / 2);
      expect(fabCenter, closeTo(466.0 - 38.0, 1.0));

      // Verify FAB bottom clears the 21 pt home indicator (37.0 pt from bottom for bottom FAB)
      expect(678.0 - bottomFabRect.bottom, closeTo(37.0, 2.0));

      // Verify FAB is strictly to the right of content
      expect(bottomFabRect.left, greaterThanOrEqualTo(cardRect.right));
    });
  });

  group('Real Screen Multi-Device & Orientation Layout Tests (Zero Overflow Assertions)', () {
    final realDevices = <RealDeviceConfig>[
      const RealDeviceConfig(
        name: 'Duo outside portrait (466x678)',
        logicalSize: Size(466, 678),
        insets: EdgeInsets.only(top: 24, bottom: 21),
      ),
      const RealDeviceConfig(
        name: 'Duo outside landscape (678x466)',
        logicalSize: Size(678, 466),
        insets: EdgeInsets.only(bottom: 21),
      ),
      const RealDeviceConfig(
        name: 'Duo inside landscape (951x669)',
        logicalSize: Size(951, 669),
        insets: EdgeInsets.only(top: 24, bottom: 21),
      ),
      const RealDeviceConfig(
        name: 'Duo inside portrait (669x951)',
        logicalSize: Size(669, 951),
        insets: EdgeInsets.only(top: 24, bottom: 21),
      ),
      const RealDeviceConfig(
        name: 'iPhone 17 Pro landscape left (932x430, island left)',
        logicalSize: Size(932, 430),
        insets: EdgeInsets.only(left: 59, bottom: 21),
      ),
      const RealDeviceConfig(
        name: 'iPhone 17 Pro landscape right (932x430, island right)',
        logicalSize: Size(932, 430),
        insets: EdgeInsets.only(right: 59, bottom: 21),
      ),
      const RealDeviceConfig(
        name: 'iPhone 17 Pro portrait (430x932)',
        logicalSize: Size(430, 932),
        insets: EdgeInsets.only(top: 59, bottom: 34),
      ),
      const RealDeviceConfig(
        name: 'iPhone X/mini landscape right (812x375, notch right)',
        logicalSize: Size(812, 375),
        insets: EdgeInsets.only(right: 44, bottom: 21),
      ),
      const RealDeviceConfig(
        name: 'iPhone X/mini portrait (375x812)',
        logicalSize: Size(375, 812),
        insets: EdgeInsets.only(top: 44, bottom: 34),
      ),
      const RealDeviceConfig(
        name: 'iPhone 8/SE landscape (667x375, zero insets)',
        logicalSize: Size(667, 375),
        insets: EdgeInsets.zero,
        pixelRatio: 2.0,
      ),
      const RealDeviceConfig(
        name: 'iPhone 8/SE portrait (375x667)',
        logicalSize: Size(375, 667),
        insets: EdgeInsets.only(top: 20),
        pixelRatio: 2.0,
      ),
      const RealDeviceConfig(
        name: 'iPhone SE 1st gen portrait (320x568)',
        logicalSize: Size(320, 568),
        insets: EdgeInsets.only(top: 20),
        pixelRatio: 2.0,
      ),
    ];

    void configureDevice(WidgetTester tester, RealDeviceConfig device) {
      tester.view.physicalSize = Size(
        device.logicalSize.width * device.pixelRatio,
        device.logicalSize.height * device.pixelRatio,
      );
      tester.view.devicePixelRatio = device.pixelRatio;
      tester.view.padding = FakeViewPadding(
        left: device.insets.left * device.pixelRatio,
        top: device.insets.top * device.pixelRatio,
        right: device.insets.right * device.pixelRatio,
        bottom: device.insets.bottom * device.pixelRatio,
      );
      tester.view.viewPadding = FakeViewPadding(
        left: device.insets.left * device.pixelRatio,
        top: device.insets.top * device.pixelRatio,
        right: device.insets.right * device.pixelRatio,
        bottom: device.insets.bottom * device.pixelRatio,
      );
    }
 
    final testProgressStates = <String, ProgressSnapshot>{
      'empty': const ProgressSnapshot(),
      'mid-session': const ProgressSnapshot(
        totalXP: 350,
        todayXP: 45,
        dailyGoal: 100,
        currentStreak: 3,
        todaySessions: 1,
        masteryDistribution: {0: 5, 1: 3, 2: 2},
      ),
      'realistic': realisticSnapshot,
    };

    for (final device in realDevices) {
      for (final vocabOnly in [false, true]) {
        for (final pEntry in testProgressStates.entries) {
          testWidgets(
            'HomeScreen renders at ${device.name} [vocabOnly=$vocabOnly, progress=${pEntry.key}] without overflow',
            (tester) async {
              configureDevice(tester, device);
              addTearDown(() {
                tester.view.resetPhysicalSize();
                tester.view.resetDevicePixelRatio();
                tester.view.resetPadding();
                tester.view.resetViewPadding();
              });

              final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
              final fakeStorage = FakeStorageService(initialItems: [item]);
              fakeStorage.saveSetting('vocab_only_mode', vocabOnly);
              fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

              final mockNotif = _MockNotificationService();
              when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
              when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

              final mockTts = MockTtsService();
              when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
              when(() => mockTts.initFuture).thenAnswer((_) async {});

              final mockVerb = _MockVerbService();
              when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    storageServiceProvider.overrideWithValue(fakeStorage),
                    notificationServiceProvider.overrideWithValue(mockNotif),
                    ttsServiceProvider.overrideWithValue(mockTts),
                    verbServiceProvider.overrideWithValue(mockVerb),
                    progressServiceProvider.overrideWith(() => _RealisticProgressService(pEntry.value)),
                  ],
                  child: testApp(
                    home: const HomeScreen(),
                  ),
                ),
              );

              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump(const Duration(milliseconds: 500));

              expect(tester.takeException(), isNull);

              // 1. Positive geometry assertions for visible Cards
              final cardFinders = find.byType(Card);
              expect(cardFinders, findsWidgets, reason: 'HomeScreen must render visible cards');

              final bool isDuoOutside = (device.logicalSize.width == 466.0 && device.logicalSize.height == 678.0) ||
                  (device.logicalSize.width == 678.0 && device.logicalSize.height == 466.0);
              final double expectedRightRail = isDuoOutside ? 76.0 : (device.insets.right > 0 ? (device.insets.right + 84.0) : 0.0);

              for (final card in tester.widgetList<Card>(cardFinders)) {
                final cardRect = tester.getRect(find.byWidget(card));
                expect(cardRect.right, lessThanOrEqualTo(device.logicalSize.width + 0.5),
                    reason: 'Card must not overflow right edge of viewport');
                expect(cardRect.left, greaterThanOrEqualTo(0.0),
                    reason: 'Card must not overflow left edge of viewport');
                if (expectedRightRail > 0) {
                  expect(device.logicalSize.width - cardRect.right, greaterThanOrEqualTo(expectedRightRail - 1.0),
                      reason: 'Card right margin must clear reservation margin ($expectedRightRail pt)');
                }
              }

              // 2. Scroll through CustomScrollView to verify lazily built section cards
              await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              await tester.pump(const Duration(milliseconds: 500));

              expect(tester.takeException(), isNull);

              // 4. Re-verify geometry after scroll
              for (final card in tester.widgetList<Card>(find.byType(Card))) {
                final cardRect = tester.getRect(find.byWidget(card));
                expect(cardRect.right, lessThanOrEqualTo(device.logicalSize.width + 0.5),
                    reason: 'Card after scroll must not overflow viewport right edge');
              }
            },
          );
        }
      }
    }

    testWidgets('HomeScreen degrades gracefully at 466x678 with accessibility text scale 1.35x and 2.0x', (tester) async {
      tester.view.physicalSize = const Size(1398, 2034);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 72, right: 0, bottom: 63);
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 72, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', true);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      for (final scale in [1.35, 2.0]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(fakeStorage),
              notificationServiceProvider.overrideWithValue(mockNotif),
              ttsServiceProvider.overrideWithValue(mockTts),
              verbServiceProvider.overrideWithValue(mockVerb),
              progressServiceProvider.overrideWith(() => _RealisticProgressService(realisticSnapshot)),
            ],
            child: testApp(
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const HomeScreen(),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);

        for (final card in tester.widgetList<Card>(find.byType(Card))) {
          final cardRect = tester.getRect(find.byWidget(card));
          expect(cardRect.right, lessThanOrEqualTo(466.0 + 0.5));
        }
      }
    });

    testWidgets('HomeScreen degrades gracefully on small iPhone (320x568) at accessibility scale 2.0x', (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 40, right: 0, bottom: 0);
      tester.view.viewPadding = const FakeViewPadding(left: 0, top: 40, right: 0, bottom: 0);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', true);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => _RealisticProgressService(realisticSnapshot)),
          ],
          child: testApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: const HomeScreen(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);

      for (final card in tester.widgetList<Card>(find.byType(Card))) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(320.0 + 0.5),
            reason: 'Cards must fit within 320pt width at 2.0x accessibility scale');
      }
    });

    for (final device in realDevices) {
      testWidgets('VocabularyListScreen renders at ${device.name} without overflow', (tester) async {
        configureDevice(tester, device);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
        });

        final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
        final fakeStorage = FakeStorageService(initialItems: [item]);
        final mockTts = MockTtsService();
        when(() => mockTts.setRate(any())).thenAnswer((_) async {});
        when(() => mockTts.stop()).thenAnswer((_) async {});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(fakeStorage),
              ttsServiceProvider.overrideWithValue(mockTts),
            ],
            child: testApp(
              home: const VocabularyListScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Positive geometry assertions: list and search field must remain within viewport
        final listFinder = find.byType(ListView);
        expect(listFinder, findsOneWidget);
        final listRect = tester.getRect(listFinder);
        expect(listRect.right, lessThanOrEqualTo(device.logicalSize.width + 0.5));
        expect(listRect.left, greaterThanOrEqualTo(0.0));

        final searchFinder = find.byType(TextField);
        if (searchFinder.evaluate().isNotEmpty) {
          final searchRect = tester.getRect(searchFinder);
          expect(searchRect.right, lessThanOrEqualTo(device.logicalSize.width + 0.5));
          expect(searchRect.left, greaterThanOrEqualTo(0.0));
        }
      });
    }

    for (final device in realDevices) {
      testWidgets('ListenRepeatScreen renders at ${device.name} without overflow', (tester) async {
        configureDevice(tester, device);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
        });

        final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
        final fakeStorage = FakeStorageService(initialItems: [item]);
        final mockAudioPlayer = MockAudioPlayer();
        when(() => mockAudioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
        when(() => mockAudioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
        when(() => mockAudioPlayer.dispose()).thenAnswer((_) async {});

        final vm = _TestLRViewModel(item, audioPlayer: mockAudioPlayer);
        final counts = {
          ListenRepeatMode.all: 20,
          ListenRepeatMode.verbs: 10,
          ListenRepeatMode.prepositions: 5,
          ListenRepeatMode.phrases: 8,
          ListenRepeatMode.vocabulary: 15,
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(fakeStorage),
              listenRepeatViewModelProvider.overrideWith(() => vm),
              listenRepeatModeCountsProvider.overrideWith((ref) => Future.value(counts)),
            ],
            child: testApp(
              home: const ListenRepeatScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Positive geometry assertions: scaffold width and cards stay within viewport
        final scaffoldFinder = find.byType(Scaffold);
        expect(scaffoldFinder, findsOneWidget);
        final scaffoldRect = tester.getRect(scaffoldFinder);
        expect(scaffoldRect.width, equals(device.logicalSize.width));

        for (final card in tester.widgetList<Card>(find.byType(Card))) {
          final cardRect = tester.getRect(find.byWidget(card));
          expect(cardRect.right, lessThanOrEqualTo(device.logicalSize.width + 0.5));
          expect(cardRect.left, greaterThanOrEqualTo(0.0));
        }
      });
    }
  });

  group('IPhoneDuoHelper Debug Override Tests', () {
    tearDown(() {
      IPhoneDuoHelper.debugOverride = null;
    });

    testWidgets('debugOverride simulates outside portrait mode', (tester) async {
      IPhoneDuoHelper.debugOverride = DuoScreenOverride.outsidePortrait;

      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) {
              expect(IPhoneDuoHelper.isDuo(context), isTrue);
              expect(IPhoneDuoHelper.isDuoOutside(context), isTrue);
              expect(IPhoneDuoHelper.isDuoOutsidePortrait(context), isTrue);
              expect(IPhoneDuoHelper.isDuoOutsideLandscape(context), isFalse);
              expect(IPhoneDuoHelper.isDuoInside(context), isFalse);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('debugOverride simulates outside landscape mode', (tester) async {
      IPhoneDuoHelper.debugOverride = DuoScreenOverride.outsideLandscape;

      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) {
              expect(IPhoneDuoHelper.isDuo(context), isTrue);
              expect(IPhoneDuoHelper.isDuoOutside(context), isTrue);
              expect(IPhoneDuoHelper.isDuoOutsideLandscape(context), isTrue);
              expect(IPhoneDuoHelper.isDuoOutsidePortrait(context), isFalse);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('debugOverride = none forces non-duo even with Duo screen dimensions', (tester) async {
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      IPhoneDuoHelper.debugOverride = DuoScreenOverride.none;

      await tester.pumpWidget(
        testApp(
          home: Builder(
            builder: (context) {
              expect(IPhoneDuoHelper.isDuo(context), isFalse);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('debugOverride is ignored on non-iOS platforms', (tester) async {
      IPhoneDuoHelper.debugOverride = DuoScreenOverride.outsidePortrait;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Builder(
            builder: (context) {
              expect(IPhoneDuoHelper.isDuo(context), isFalse);
              expect(IPhoneDuoHelper.isDuoOutside(context), isFalse);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('HomeScreen rotates dynamically between portrait and landscape without exceptions', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', false);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => _RealisticProgressService(realisticSnapshot)),
          ],
          child: testApp(home: const HomeScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final portraitCards = find.byType(Card);
      expect(portraitCards, findsWidgets, reason: 'Portrait mode must display cards');
      for (final card in tester.widgetList<Card>(portraitCards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(430.0 + 0.5));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
      }

      // Rotate to landscape
      tester.view.physicalSize = const Size(2796, 1290);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final landscapeCards = find.byType(Card);
      expect(landscapeCards, findsWidgets, reason: 'Landscape mode must display cards');
      for (final card in tester.widgetList<Card>(landscapeCards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(932.0 + 0.5));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
      }

      // Rotate back to portrait
      tester.view.physicalSize = const Size(1290, 2796);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final restoredCards = find.byType(Card);
      expect(restoredCards, findsWidgets, reason: 'Restored portrait mode must display cards');
      for (final card in tester.widgetList<Card>(restoredCards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(430.0 + 0.5));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
      }
    });

    testWidgets('HomeScreen rotates dynamically on narrow iPhone (320x568 <-> 568x320) without exceptions or clipping', (tester) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', false);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => _RealisticProgressService(realisticSnapshot)),
          ],
          child: testApp(home: const HomeScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final portraitCards = find.byType(Card);
      expect(portraitCards, findsWidgets);
      for (final card in tester.widgetList<Card>(portraitCards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(320.0 + 0.5));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
      }

      // Rotate to narrow landscape (568x320)
      tester.view.physicalSize = const Size(1136, 640);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final landscapeCards = find.byType(Card);
      expect(landscapeCards, findsWidgets);
      for (final card in tester.widgetList<Card>(landscapeCards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(568.0 + 0.5));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
      }

      // Rotate back to narrow portrait (320x568)
      tester.view.physicalSize = const Size(640, 1136);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final restoredCards = find.byType(Card);
      expect(restoredCards, findsWidgets);
      for (final card in tester.widgetList<Card>(restoredCards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(320.0 + 0.5));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
      }
    });

    testWidgets('HomeScreen rotates dynamically with accessibility text scale 1.35x without overflow', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you');
      final fakeStorage = FakeStorageService(initialItems: [item]);
      fakeStorage.saveSetting('vocab_only_mode', false);
      fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

      final mockNotif = _MockNotificationService();
      when(() => mockNotif.requestPermissionsIfFirstTime()).thenAnswer((_) async {});
      when(() => mockNotif.handlePendingNotification()).thenAnswer((_) async {});

      final mockTts = MockTtsService();
      when(() => mockTts.isEnhancedPtVoiceAvailable).thenReturn(true);
      when(() => mockTts.initFuture).thenAnswer((_) async {});

      final mockVerb = _MockVerbService();
      when(() => mockVerb.loadVerbs()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(fakeStorage),
            notificationServiceProvider.overrideWithValue(mockNotif),
            ttsServiceProvider.overrideWithValue(mockTts),
            verbServiceProvider.overrideWithValue(mockVerb),
            progressServiceProvider.overrideWith(() => _RealisticProgressService(realisticSnapshot)),
          ],
          child: testApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.35),
                ),
                child: const HomeScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Rotate to landscape
      tester.view.physicalSize = const Size(2796, 1290);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      final landscapeCards = find.byType(Card);
      expect(landscapeCards, findsWidgets);
      for (final card in tester.widgetList<Card>(landscapeCards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.right, lessThanOrEqualTo(932.0 + 0.5));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
      }
    });
  });
}
