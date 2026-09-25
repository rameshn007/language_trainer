import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/notification_service.dart';
import 'package:language_trainer/services/progress_service.dart';
import 'package:language_trainer/services/verb_service.dart';
import 'package:language_trainer/ui/home_screen.dart';
import 'package:language_trainer/ui/vocabulary/vocabulary_list_screen.dart';
import 'package:language_trainer/utils/iphone_duo_helper.dart';
import 'helpers/carplay_test_helpers.dart';

class _MockNotificationService extends Mock implements NotificationService {}
class _MockVerbService extends Mock implements VerbService {}

void main() {
  group('iPhone 17 Landscape and Dynamic Island Layout Tests', () {
    testWidgets('Landscape with Dynamic Island on left: content cleared and FABs at rightmost', (tester) async {
      // iPhone 17 Landscape Left (932 x 430) with Dynamic Island on left (59 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63); // 59 pt left, 21 pt bottom
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        MaterialApp(
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
    });

    testWidgets('Landscape with Dynamic Island on right: content cleared and FABs inside safe area', (tester) async {
      // iPhone 17 Landscape Right (932 x 430) with Dynamic Island on right (59 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 0, right: 177, bottom: 63); // 59 pt right
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        MaterialApp(
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

      // Right inset must clear both the Dynamic Island (59 pt) and the FAB gutter (84 pt)
      expect(contentPadding.right, greaterThanOrEqualTo(143.0));

      final contentRect = tester.getRect(find.byKey(const Key('test_content_card_right')));
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      // FAB must be strictly to the right of the content (no overlap)
      expect(fabRect.left, greaterThan(contentRect.right));

      // FAB right edge must clear the Dynamic Island (59.0 pt from screen right) with 16 pt margin
      expect(932.0 - fabRect.right, closeTo(75.0, 2.0));
    });

    testWidgets('Portrait preserves standard 20 pt insets and endFloat location', (tester) async {
      // iPhone 17 Portrait (430 x 932)
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 0, top: 177, right: 0, bottom: 102);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      late EdgeInsets contentPadding;
      late FloatingActionButtonLocation fabLocation;

      await tester.pumpWidget(
        MaterialApp(
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
        MaterialApp(
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
    testWidgets('VocabularyListScreen applies correct left clearance and right gutter in landscape', (tester) async {
      // iPhone 17 Landscape Left (932 x 430) with Dynamic Island on left (59 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
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
          child: const MaterialApp(
            home: VocabularyListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify ListView padding has left clearance >= 75.0 (well clear of 59.0pt Dynamic Island)
      final listView = tester.widget<ListView>(find.byType(ListView));
      final EdgeInsets listPadding = listView.padding as EdgeInsets;
      expect(listPadding.left, greaterThanOrEqualTo(75.0));
      expect(listPadding.right, greaterThanOrEqualTo(84.0));

      // 2. Verify search bar TextField left is clear of Dynamic Island
      final searchRect = tester.getRect(find.byType(TextField));
      expect(searchRect.left, greaterThanOrEqualTo(75.0));

      // 3. Verify FAB rightmost placement does not overlap the list content area
      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      expect(932.0 - fabRect.right, closeTo(16.0, 2.0));
    });

    testWidgets('HomeScreen applies correct left clearance and right FAB gutter in landscape', (tester) async {
      // iPhone 17 Landscape Left (932 x 430) with Dynamic Island on left (59 pt)
      tester.view.physicalSize = const Size(2796, 1290);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(left: 177, top: 0, right: 0, bottom: 63);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
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
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify CustomScrollView and Card placement respect contentPadding
      expect(find.byType(CustomScrollView), findsOneWidget);

      // Verify HomeScreen cards are clear of the Dynamic Island (>= 75.0 pt)
      final cardRect = tester.getRect(find.byType(Card).first);
      expect(cardRect.left, greaterThanOrEqualTo(75.0));
      // Verify right edge leaves gutter for FABs
      expect(932.0 - cardRect.right, greaterThanOrEqualTo(84.0));
    });
  });

  group('IPhoneDuoHelper Debug Override Tests', () {
    tearDown(() {
      IPhoneDuoHelper.debugOverride = null;
    });

    testWidgets('debugOverride simulates outside portrait mode', (tester) async {
      IPhoneDuoHelper.debugOverride = DuoScreenOverride.outsidePortrait;

      await tester.pumpWidget(
        MaterialApp(
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
        MaterialApp(
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
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(IPhoneDuoHelper.isDuo(context), isFalse);
              return Container();
            },
          ),
        ),
      );
    });
  });
}
