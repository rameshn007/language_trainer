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
import 'package:language_trainer/utils/iphone_duo_helper.dart';
import 'helpers/carplay_test_helpers.dart';

class _MockNotificationService extends Mock implements NotificationService {}
class _MockVerbService extends Mock implements VerbService {}

class _TestStorageService extends FakeStorageService {
  _TestStorageService({super.initialItems});

  @override
  List<int> getXPHistory([int days = 7]) => List.filled(days, 0);

  @override
  List<String> getXPHistoryLabels([int days = 7]) => List.filled(days, '');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleItems = [
    LanguageItem(id: 'item1', portuguese: 'obrigado', english: 'thank you', masteryLevel: 1),
    LanguageItem(id: 'item2', portuguese: 'por favor', english: 'please', masteryLevel: 2),
    LanguageItem(id: 'item3', portuguese: 'bom dia', english: 'good morning', masteryLevel: 3),
  ];

  Widget buildTestApp({
    Size logicalSize = const Size(375, 812),
    double textScale = 1.0,
  }) {
    final fakeStorage = _TestStorageService(initialItems: sampleItems);
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

    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(fakeStorage),
        notificationServiceProvider.overrideWithValue(mockNotif),
        ttsServiceProvider.overrideWithValue(mockTts),
        verbServiceProvider.overrideWithValue(mockVerb),
        progressServiceProvider.overrideWith(() => MockProgressService()),
      ],
      child: MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: MediaQuery(
          data: MediaQueryData(
            size: logicalSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const HomeScreen(),
        ),
      ),
    );
  }

  tearDown(() {
    IPhoneDuoHelper.resetForTesting();
  });

  group('HomeScreen Navigation & Dynamic Filter Tabs', () {
    testWidgets('tapping category filter pills changes rendered sections and matches pill counts', (tester) async {
      tester.view.physicalSize = const Size(375 * 2, 812 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);

      // Default 'All' tab: verify the section content renders.
      // 'Fast Practice' is also a filter pill label now, so the Flashcards tile
      // is the marker that the section itself rendered.
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Practice & Exercises'), findsOneWidget);
      expect(find.text('Explore Topics'), findsOneWidget);

      // 1. Tap 'Exercises' pill
      final exercisesPill = find.widgetWithText(InkWell, 'Exercises');
      expect(exercisesPill, findsOneWidget);
      expect(find.descendant(of: exercisesPill, matching: find.text('20')), findsOneWidget,
          reason: 'Exercises pill should compute 20 tiles dynamically');
      await tester.tap(exercisesPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Sentence & Structure (7 Units)'), findsOneWidget);
      expect(find.text('Verb Mastery (5 Units)'), findsOneWidget);
      expect(find.text('Thematic Vocabulary Units (7 Units)'), findsOneWidget);
      // Fast Practice and Explore Topics should no longer be rendered
      expect(find.text('Flashcards'), findsNothing);
      expect(find.text('Explore Topics'), findsNothing);

      // 2. Tap 'Topics' pill
      final topicsPill = find.widgetWithText(InkWell, 'Topics');
      expect(topicsPill, findsOneWidget);
      expect(find.descendant(of: topicsPill, matching: find.text('14')), findsOneWidget,
          reason: 'Topics pill should compute 14 tiles dynamically');
      await tester.tap(topicsPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Explore by Topic (13 Topics)'), findsOneWidget);
      expect(find.text('Sentence & Structure (7 Units)'), findsNothing);

      // 3. Tap 'Vocabulary' pill
      final vocabPill = find.widgetWithText(InkWell, 'Vocabulary');
      expect(vocabPill, findsOneWidget);
      expect(find.descendant(of: vocabPill, matching: find.text('6')), findsOneWidget,
          reason: 'Vocabulary pill should compute 6 tiles dynamically');
      await tester.tap(vocabPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Vocabulary & Flashcards'), findsOneWidget);

      // 4. Tap 'Grammar' pill
      final grammarPill = find.widgetWithText(InkWell, 'Grammar');
      expect(grammarPill, findsOneWidget);
      expect(find.descendant(of: grammarPill, matching: find.text('6')), findsOneWidget,
          reason: 'Grammar pill should compute 6 tiles dynamically');
      await tester.tap(grammarPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Grammar & Verbs'), findsOneWidget);

      // 5. Tap 'Speaking' pill
      final speakingPill = find.widgetWithText(InkWell, 'Speaking');
      expect(speakingPill, findsOneWidget);
      expect(find.descendant(of: speakingPill, matching: find.text('4')), findsOneWidget,
          reason: 'Speaking pill should compute 4 tiles dynamically');
      await tester.tap(speakingPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Speaking & Phrases'), findsOneWidget);

      // 6. Tap 'Fast Practice' pill
      final fastPill = find.widgetWithText(InkWell, 'Fast Practice');
      expect(fastPill, findsOneWidget);
      expect(find.descendant(of: fastPill, matching: find.text('3')), findsOneWidget,
          reason: 'Fast Practice pill should compute 3 tiles dynamically');
      await tester.tap(fastPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Vocab Quiz'), findsOneWidget);
      expect(find.text('Voice Trainer'), findsOneWidget);
      expect(find.text('Practice & Exercises'), findsNothing);
      expect(find.text('Speaking & Phrases'), findsNothing);

      // 7. Return to 'All'
      final allPill = find.widgetWithText(InkWell, 'All');
      expect(allPill, findsOneWidget);
      expect(find.descendant(of: allPill, matching: find.text('17')), findsOneWidget,
          reason: 'All pill should compute 17 tiles dynamically');
      await tester.tap(allPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Practice & Exercises'), findsOneWidget);
    });

    testWidgets('tapping "View All" on Practice & Exercises section switches to Exercises tab', (tester) async {
      tester.view.physicalSize = const Size(375 * 2, 812 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp());
      await tester.pump(const Duration(milliseconds: 200));

      // Scroll down until the Practice & Exercises "View All" action button is visible
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
      await tester.pump(const Duration(milliseconds: 100));

      final viewAllButtons = find.widgetWithText(InkWell, 'View All');
      expect(viewAllButtons, findsWidgets);

      // The first View All button is on Practice & Exercises
      await tester.tap(viewAllButtons.first);
      await tester.pump(const Duration(milliseconds: 200));

      // Should now render the full Exercises sub-curricula
      expect(find.text('Sentence & Structure (7 Units)'), findsOneWidget);
      expect(find.text('Verb Mastery (5 Units)'), findsOneWidget);
      expect(find.text('Thematic Vocabulary Units (7 Units)'), findsOneWidget);
    });

    testWidgets('gracefully renders 20-tile Exercises tab at compact iPhone SE (320x568) with 1.35x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(
        logicalSize: const Size(320, 568),
        textScale: 1.35,
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // Switch to Exercises tab (20 tiles)
      final exercisesPill = find.widgetWithText(InkWell, 'Exercises');
      expect(exercisesPill, findsOneWidget);
      await tester.tap(exercisesPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);

      final cards = find.byType(Card);
      expect(cards, findsWidgets);
      for (final card in tester.widgetList<Card>(cards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
        expect(cardRect.right, lessThanOrEqualTo(320.0 + 0.5));
      }
    });

    testWidgets('gracefully renders 14-tile Topics tab at compact iPhone SE (320x568) with 1.35x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 568 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestApp(
        logicalSize: const Size(320, 568),
        textScale: 1.35,
      ));
      await tester.pump(const Duration(milliseconds: 200));

      // Scroll slightly so the second row of pills is visible on compact screen
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Topics tab (14 tiles)
      final topicsPill = find.widgetWithText(InkWell, 'Topics');
      expect(topicsPill, findsOneWidget);
      await tester.tap(topicsPill);
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);

      final cards = find.byType(Card);
      expect(cards, findsWidgets);
      for (final card in tester.widgetList<Card>(cards)) {
        final cardRect = tester.getRect(find.byWidget(card));
        expect(cardRect.left, greaterThanOrEqualTo(0.0));
        expect(cardRect.right, lessThanOrEqualTo(320.0 + 0.5));
      }
    });
  });
}
