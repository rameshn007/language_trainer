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
import 'package:language_trainer/ui/widgets/home_screen_background.dart';
import 'package:language_trainer/ui/widgets/word_star_field.dart';
import 'helpers/carplay_test_helpers.dart';

class _MockNotificationService extends Mock implements NotificationService {}

class _MockVerbService extends Mock implements VerbService {}

void main() {
  group('WordStarField stability', () {
    testWidgets(
      'does not clear stars when widget is rebuilt with new list reference of same words',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: WordStarField(
                words: ['olá', 'obrigado', 'bom dia'],
                wordCount: 5,
              ),
            ),
          ),
        );

        // Find initial Text widgets rendered for stars
        final initialTexts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(WordStarField),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data)
            .toList();

        expect(initialTexts.length, equals(5));

        // Rebuild with a brand new list reference containing the same words
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: WordStarField(
                words: List<String>.from(['olá', 'obrigado', 'bom dia']),
                wordCount: 5,
              ),
            ),
          ),
        );

        final afterRebuildTexts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(WordStarField),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data)
            .toList();

        // Words should remain identical because didUpdateWidget preserves existing stars
        expect(afterRebuildTexts, equals(initialTexts));
      },
    );

    testWidgets('re-seeds stars when resetToken is incremented', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordStarField(words: ['olá'], wordCount: 3, resetToken: 0),
          ),
        ),
      );

      final stateBefore = tester.state(find.byType(WordStarField));

      // Rebuild with new resetToken and new word pool
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WordStarField(
              words: ['obrigado'],
              wordCount: 3,
              resetToken: 1,
            ),
          ),
        ),
      );

      final stateAfter = tester.state(find.byType(WordStarField));
      expect(identical(stateBefore, stateAfter), isTrue);

      final afterResetTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(WordStarField),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .toList();

      // All stars should now draw from the newly seeded word
      expect(afterResetTexts, equals(['obrigado', 'obrigado', 'obrigado']));
    });
  });

  group('HomeScreenBackground decoupling', () {
    testWidgets(
      'changing category filter pills on HomeScreen does not reset background WordStarField stars',
      (tester) async {
        final items = [
          LanguageItem(
            id: 'item1',
            portuguese: 'obrigado',
            english: 'thank you',
            masteryLevel: 1,
          ),
          LanguageItem(
            id: 'item2',
            portuguese: 'por favor',
            english: 'please',
            masteryLevel: 1,
          ),
          LanguageItem(
            id: 'item3',
            portuguese: 'bom dia',
            english: 'good morning',
            masteryLevel: 1,
          ),
        ];

        final fakeStorage = FakeStorageService(initialItems: items);
        fakeStorage.saveSetting('vocab_only_mode', true);
        fakeStorage.saveSetting('has_seen_enhanced_voice_prompt', true);

        final mockNotif = _MockNotificationService();
        when(
          () => mockNotif.requestPermissionsIfFirstTime(),
        ).thenAnswer((_) async {});
        when(
          () => mockNotif.handlePendingNotification(),
        ).thenAnswer((_) async {});

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
            child: const MaterialApp(home: HomeScreen()),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(HomeScreenBackground), findsOneWidget);
        expect(find.byType(WordStarField), findsOneWidget);

        final starFieldStateBefore = tester.state(find.byType(WordStarField));

        // Record text and positions of background stars
        final initialStarTexts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(WordStarField),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data)
            .toList();

        expect(initialStarTexts, isNotEmpty);

        // Tap the "Vocabulary" filter pill (pinned expectation)
        final vocabPill = find.textContaining('Vocabulary');
        expect(
          vocabPill,
          findsWidgets,
          reason: 'filter pill missing — decoupling is untested',
        );

        await tester.tap(vocabPill.first);
        await tester.pump(const Duration(milliseconds: 250));

        // Verify WordStarField state instance is preserved across filter changes
        final starFieldStateAfter = tester.state(find.byType(WordStarField));
        expect(
          identical(starFieldStateBefore, starFieldStateAfter),
          isTrue,
          reason: 'WordStarField state must be preserved across filter changes',
        );

        // Verify star texts in WordStarField did not change
        final afterFilterStarTexts = tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(WordStarField),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data)
            .toList();

        expect(afterFilterStarTexts, equals(initialStarTexts));
      },
    );

    testWidgets(
      'bumping refreshToken invalidates cache and updates background words',
      (tester) async {
        final items = [
          LanguageItem(
            id: 'item1',
            portuguese: 'obrigado',
            english: 'thank you',
            masteryLevel: 1,
          ),
        ];

        final fakeStorage = FakeStorageService(initialItems: items);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(fakeStorage)],
            child: const MaterialApp(
              home: Scaffold(body: HomeScreenBackground(refreshToken: 0)),
            ),
          ),
        );

        await tester.pump();
        expect(find.byType(WordStarField), findsOneWidget);

        // Add a new item to storage
        await fakeStorage.saveItems([
          LanguageItem(
            id: 'item2',
            portuguese: 'novo_item',
            english: 'new item',
            masteryLevel: 1,
          ),
        ]);

        // Rebuild with bumped refreshToken
        await tester.pumpWidget(
          ProviderScope(
            overrides: [storageServiceProvider.overrideWithValue(fakeStorage)],
            child: const MaterialApp(
              home: Scaffold(body: HomeScreenBackground(refreshToken: 1)),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 50));

        final starField = tester.widget<WordStarField>(
          find.byType(WordStarField),
        );
        expect(
          starField.words.contains('novo_item'),
          isTrue,
          reason:
              'HomeScreenBackground must refresh its word pool when refreshToken is bumped',
        );
      },
    );
  });
}
