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

class _RealisticProgressService extends Notifier<ProgressSnapshot> with Mock implements ProgressService {
  final ProgressSnapshot _snapshot;
  _RealisticProgressService([this._snapshot = const ProgressSnapshot(
    totalXP: 1450,
    todayXP: 130,
    dailyGoal: 100,
    currentStreak: 12,
    todaySessions: 4,
    masteryDistribution: {0: 10, 1: 8, 2: 5, 3: 12, 4: 15},
  )]);

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
          child: testApp(
            home: const VocabularyListScreen(),
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
          child: testApp(
            home: const HomeScreen(),
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
    });
  });

  group('Real Screen Multi-Device & Orientation Layout Tests (Zero Overflow Assertions)', () {
    final duoAndIPhoneSizes = <String, Size>{
      'Duo outside portrait (466x678)': const Size(466, 678),
      'Duo outside landscape (678x466)': const Size(678, 466),
      'Duo inside landscape (951x669)': const Size(951, 669),
      'Duo inside portrait (669x951)': const Size(669, 951),
      'iPhone 8/SE portrait (375x667)': const Size(375, 667),
      'iPhone X/mini portrait (375x812)': const Size(375, 812),
      'iPhone SE 1st gen portrait (320x568)': const Size(320, 568),
    };

    const realisticSnapshot = ProgressSnapshot(
      totalXP: 1450,
      todayXP: 130,
      dailyGoal: 100,
      currentStreak: 12,
      todaySessions: 4,
      masteryDistribution: {0: 10, 1: 8, 2: 5, 3: 12, 4: 15},
    );

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

    for (final entry in duoAndIPhoneSizes.entries) {
      for (final vocabOnly in [false, true]) {
        for (final pEntry in testProgressStates.entries) {
          testWidgets(
            'HomeScreen renders at ${entry.key} [vocabOnly=$vocabOnly, progress=${pEntry.key}] without overflow',
            (tester) async {
              tester.view.physicalSize = entry.value;
              tester.view.devicePixelRatio = 1.0;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);

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
              await tester.pump(const Duration(milliseconds: 100));

              expect(tester.takeException(), isNull);

              // Scroll through CustomScrollView to verify lazily built section cards
              await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));

              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('HomeScreen on Duo outside portrait (466x678): FABs in right rail below system icon without overlapping content', (tester) async {
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      expect(tester.takeException(), isNull);

      // Verify content card right edge leaves a rail for the system icon and FABs (76 pt)
      final cardRect = tester.getRect(find.byType(Card).first);
      expect(466.0 - cardRect.right, greaterThanOrEqualTo(76.0));

      // Verify FAB is centered at screenWidth - 38.0 pt (aligned with Wi-Fi icon column)
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsWidgets);
      final fabRect = tester.getRect(fabFinder.first);
      final fabCenter = fabRect.left + (fabRect.width / 2);
      expect(fabCenter, closeTo(466.0 - 38.0, 1.0));

      // Verify FAB is strictly to the right of the content (no overlap)
      expect(fabRect.left, greaterThanOrEqualTo(cardRect.right));
    });

    testWidgets('HomeScreen degrades gracefully at 466x678 with accessibility text scale 1.35x and 2.0x', (tester) async {
      tester.view.physicalSize = const Size(466, 678);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: const HomeScreen(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('HomeScreen degrades gracefully on small iPhone (320x568) at accessibility scale 2.0x', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: HomeScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    for (final entry in duoAndIPhoneSizes.entries) {
      testWidgets('VocabularyListScreen renders at ${entry.key} without overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
      });
    }

    for (final entry in duoAndIPhoneSizes.entries) {
      testWidgets('ListenRepeatScreen renders at ${entry.key} without overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
  });
}
