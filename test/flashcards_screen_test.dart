import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/flashcard_item.dart';
import 'package:language_trainer/models/progress_data.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:language_trainer/ui/flashcards/flashcards_screen.dart';

class _MockStorageService extends Mock implements StorageService {}
class _MockTtsService extends Mock implements TtsService {}
class _FakeSessionRecord extends Fake implements SessionRecord {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeSessionRecord());
  });

  late _MockTtsService mockTts;
  late _MockStorageService mockStorage;

  final sampleCards = [
    const FlashcardItem(
      id: '1',
      cardNumber: '#1',
      portuguese: 'ser',
      english: 'to be (permanent)',
      category: 'VERBS',
      pronunciation: 'SAIR',
      wordType: 'verb',
      cefrLevel: 'A1',
      presentTense: {
        'eu': 'sou',
        'tu': 'és',
        'ele_ela_voce': 'é',
        'nos': 'somos',
        'voces_eles': 'são',
      },
      languageItemId: 'vocab_1',
    ),
    const FlashcardItem(
      id: '2',
      cardNumber: '#2',
      portuguese: 'estar',
      english: 'to be (temporary)',
      category: 'VERBS',
      pronunciation: 'esh-TAR',
      wordType: 'verb',
      cefrLevel: 'A1',
      presentTense: {
        'eu': 'estou',
        'tu': 'estás',
        'ele_ela_voce': 'está',
        'nos': 'estamos',
        'voces_eles': 'estão',
      },
      languageItemId: 'vocab_2',
    ),
    const FlashcardItem(
      id: 'G1',
      cardNumber: '#G1',
      portuguese: 'Verbos Reflexivos (-se)',
      english: 'Reflexive Verbs',
      category: 'EXPLANATION',
      cefrLevel: 'A1',
      grammarExplanation: 'Used when subject and object are the same.',
      isGrammarCard: true,
      languageItemId: null,
    ),
  ];

  setUp(() {
    mockTts = _MockTtsService();
    mockStorage = _MockStorageService();

    when(() => mockStorage.getAllItems()).thenReturn([]);
    when(() => mockStorage.getItem(any())).thenReturn(null);
    when(() => mockStorage.isItemFlagged(any())).thenReturn(false);
    when(() => mockStorage.toggleItemFlagged(any())).thenAnswer((_) async => true);
    when(() => mockStorage.getTodayXP()).thenReturn(0);
    when(() => mockStorage.getDailyXPGoal()).thenReturn(50);
    when(() => mockStorage.getCurrentStreak()).thenReturn(0);
    when(() => mockStorage.getBestStreak()).thenReturn(0);
    when(() => mockStorage.getTotalXP()).thenReturn(0);
    when(() => mockStorage.getTodaySessions()).thenReturn(0);
    when(() => mockStorage.getMasteryDistribution()).thenReturn({});
    when(() => mockStorage.updateWordProgress(any(), any(), firstAttempt: any(named: 'firstAttempt')))
        .thenAnswer((_) async => 10);
    when(() => mockStorage.addXP(any())).thenAnswer((_) async {});
    when(() => mockStorage.incrementWordsReviewed(any())).thenAnswer((_) async {});
    when(() => mockStorage.incrementDailySessions()).thenAnswer((_) async {});
    when(() => mockStorage.saveSession(any())).thenAnswer((_) async {});
    when(() => mockTts.setRate(any())).thenAnswer((_) async {});
    when(
      () => mockTts.speak(
        any(),
        language: any(named: 'language'),
        rate: any(named: 'rate'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockTts.stop()).thenAnswer((_) async {});
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<FlashcardItem>? cards,
    bool initialShuffle = false,
    bool initialAutoAdvance = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          ttsServiceProvider.overrideWithValue(mockTts),
        ],
        child: MaterialApp(
          home: FlashcardsScreen(
            initialCards: cards ?? sampleCards,
            initialShuffle: initialShuffle,
            initialAutoAdvance: initialAutoAdvance,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('FlashcardsScreen Widget Tests', () {
    testWidgets('renders FlashcardsScreen and initializes card counter and speed', (tester) async {
      await pumpScreen(tester);

      // App bar title
      expect(find.text('Flashcards'), findsOneWidget);
      expect(find.text('Card 1 of 3'), findsOneWidget);

      // Initial speed is 0.8x
      expect(find.text('0.8x'), findsOneWidget);

      // Flip card button is present
      expect(find.text('Flip Card'), findsOneWidget);

      // Previous button should be disabled initially (on first card)
      final prevFinder = find.widgetWithIcon(IconButton, Icons.chevron_left_rounded);
      expect(prevFinder, findsOneWidget);
      final prevButton = tester.widget<IconButton>(prevFinder);
      expect(prevButton.onPressed, isNull);
    });

    testWidgets('cycles speech speed: 0.8x -> 1.0x -> 0.5x -> 0.8x', (tester) async {
      await pumpScreen(tester);

      expect(find.text('0.8x'), findsOneWidget);

      // Tap speed -> 1.0x
      await tester.tap(find.text('0.8x'));
      await tester.pump();
      expect(find.text('1.0x'), findsOneWidget);

      // Tap speed -> 0.5x
      await tester.tap(find.text('1.0x'));
      await tester.pump();
      expect(find.text('0.5x'), findsOneWidget);

      // Tap speed -> 0.8x
      await tester.tap(find.text('0.5x'));
      await tester.pump();
      expect(find.text('0.8x'), findsOneWidget);
    });

    testWidgets('flips card to show English translation when Flip button is tapped', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Flip Card'), findsOneWidget);

      // Tap Flip button
      await tester.tap(find.text('Flip Card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Now button text should be "Show Front"
      expect(find.text('Show Front'), findsOneWidget);

      // Tap again to flip back
      await tester.tap(find.text('Show Front'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Flip Card'), findsOneWidget);
    });

    testWidgets('speaks English text in en-US when card is flipped and when English speaker is tapped', (tester) async {
      await pumpScreen(tester);

      // Verify Portuguese was spoken on load (card #G1 is first in natural deck order)
      verify(() => mockTts.speak('Verbos Reflexivos (-se)', language: 'pt-PT', rate: any(named: 'rate'))).called(1);

      // Tap Flip button
      await tester.tap(find.text('Flip Card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify English was spoken on flip
      verify(() => mockTts.speak('Reflexive Verbs', language: 'en-US', rate: any(named: 'rate'))).called(1);

      // Back face has English speaker button
      final enSpeakerFinder = find.byTooltip('Listen in English');
      expect(enSpeakerFinder, findsOneWidget);

      // Tap English speaker button
      await tester.tap(enSpeakerFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify English was spoken again
      verify(() => mockTts.speak('Reflexive Verbs', language: 'en-US', rate: any(named: 'rate'))).called(1);
    });

    testWidgets('speaks only the Portuguese word in white text and never the pronunciation guide underneath', (tester) async {
      const testCard = FlashcardItem(
        id: '351',
        cardNumber: '#351',
        portuguese: 'tanto... como...',
        english: 'both... and...',
        pronunciation: 'TAHN-too... KOH-moo',
        category: 'GRAMMAR',
        wordType: 'conjunction',
        cefrLevel: 'B1',
      );

      await pumpScreen(tester, cards: [testCard]);

      // Only the white text 'tanto como' is spoken in pt-PT
      verify(() => mockTts.speak('tanto como', language: 'pt-PT', rate: any(named: 'rate'))).called(1);

      // Verify that the phonetic pronunciation guide 'TAHN-too... KOH-moo' was NEVER spoken
      verifyNever(() => mockTts.speak(
        any(that: contains('TAHN-too')),
        language: any(named: 'language'),
        rate: any(named: 'rate'),
      ));
      verifyNever(() => mockTts.speak(
        any(that: contains('KOH-moo')),
        language: any(named: 'language'),
        rate: any(named: 'rate'),
      ));
    });

    testWidgets('navigates to next card using Next button', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Card 1 of 3'), findsOneWidget);

      // Tap Next button
      final nextFinder = find.widgetWithIcon(IconButton, Icons.chevron_right_rounded);
      expect(nextFinder, findsOneWidget);
      await tester.tap(nextFinder);
      await tester.pump();

      // Now counter should say Card 2 of 3
      expect(find.text('Card 2 of 3'), findsOneWidget);

      // Previous button should now be enabled
      final prevFinder = find.widgetWithIcon(IconButton, Icons.chevron_left_rounded);
      final prevButton = tester.widget<IconButton>(prevFinder);
      expect(prevButton.onPressed, isNotNull);
    });

    testWidgets('toggles auto-advance play and pause', (tester) async {
      await pumpScreen(tester);

      final playFinder = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
      expect(playFinder, findsOneWidget);

      // Tap play
      await tester.tap(playFinder);
      await tester.pump();

      // Now should show pause icon
      final pauseFinder = find.widgetWithIcon(IconButton, Icons.pause_rounded);
      expect(pauseFinder, findsOneWidget);

      // Tap pause
      await tester.tap(pauseFinder);
      await tester.pump();

      expect(find.widgetWithIcon(IconButton, Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('filters deck when category chip is selected', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Card 1 of 3'), findsOneWidget);

      // Select VERBS category chip
      final verbsChip = find.widgetWithText(FilterChip, 'VERBS');
      expect(verbsChip, findsOneWidget);
      await tester.tap(verbsChip);
      await tester.pump();

      // Filtered to 2 cards
      expect(find.text('Card 1 of 2'), findsOneWidget);
    });

    testWidgets('renders all verb conjugation forms fully on flipped card without ellipsizing', (tester) async {
      const verbCard = FlashcardItem(
        id: '17',
        cardNumber: '#17',
        portuguese: 'aprender',
        english: 'to learn',
        category: 'VERBS',
        wordType: 'verb',
        cefrLevel: 'A1',
        presentTense: {
          'eu': 'aprendo',
          'tu': 'aprendes',
          'ele_ela_voce': 'aprende',
          'nos': 'aprendemos',
          'voces_eles': 'aprendem',
        },
      );

      await pumpScreen(tester, cards: [verbCard]);

      // Flip card to reveal back face
      await tester.tap(find.text('Flip Card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // English title is shown
      expect(find.text('to learn'), findsOneWidget);

      // Present indicative section header
      expect(find.text('Presente do Indicativo'), findsOneWidget);

      // Verify each pronoun and full conjugated verb form is present
      expect(find.text('Eu'), findsOneWidget);
      expect(find.text('aprendo'), findsOneWidget);

      expect(find.text('Tu'), findsOneWidget);
      expect(find.text('aprendes'), findsOneWidget);

      expect(find.text('Ele/Ela'), findsOneWidget);
      expect(find.text('aprende'), findsOneWidget);

      expect(find.text('Nós'), findsOneWidget);
      expect(find.text('aprendemos'), findsOneWidget);

      expect(find.text('Eles/Vocês'), findsOneWidget);
      expect(find.text('aprendem'), findsOneWidget);

      // Verify that all conjugated verb Text widgets explicitly do not use TextOverflow.ellipsis
      final formTexts = ['aprendo', 'aprendes', 'aprende', 'aprendemos', 'aprendem'];
      for (final form in formTexts) {
        final textFinder = find.text(form);
        expect(textFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(textFinder);
        expect(textWidget.overflow, isNot(TextOverflow.ellipsis));
      }
    });

    testWidgets('toggles flag/bookmark on grammar card using fallback key and vocab card using languageItemId', (tester) async {
      await pumpScreen(tester);

      // Card 1 is G1 (grammar card with languageItemId: null)
      expect(find.text('#G1'), findsOneWidget);
      final flagBtn = find.byTooltip('Bookmark Card');
      expect(flagBtn, findsOneWidget);

      // Tap flag on grammar card -> toggleItemFlagged('G1')
      await tester.tap(flagBtn);
      await tester.pump();
      verify(() => mockStorage.toggleItemFlagged('G1')).called(1);

      // Advance to vocab card #1
      final nextFinder = find.widgetWithIcon(IconButton, Icons.chevron_right_rounded);
      await tester.tap(nextFinder);
      await tester.pump();
      expect(find.text('#1'), findsOneWidget);

      // Tap flag on vocab card -> toggleItemFlagged('vocab_1')
      await tester.tap(flagBtn);
      await tester.pump();
      verify(() => mockStorage.toggleItemFlagged('vocab_1')).called(1);
    });

    testWidgets('records quiz answer and awards real XP on rating, prevents repeat-tap XP farming, and disables for grammar cards', (tester) async {
      await pumpScreen(tester);

      // Card 1 is G1 (grammar card) - Flip to back
      await tester.tap(find.text('Flip Card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Grammar card should NOT display mastery rating buttons
      expect(find.text('How well do you know this card?'), findsNothing);
      expect(find.text('Mastered'), findsNothing);

      // Flip back and navigate to vocab card #1
      await tester.tap(find.text('Show Front'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final nextFinder = find.widgetWithIcon(IconButton, Icons.chevron_right_rounded);
      await tester.tap(nextFinder);
      await tester.pump();
      expect(find.text('#1'), findsOneWidget);

      // Flip vocab card to back
      await tester.tap(find.text('Flip Card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Rating buttons should be visible
      expect(find.text('How well do you know this card?'), findsOneWidget);
      final masteredBtn = find.text('Mastered');
      expect(masteredBtn, findsOneWidget);

      // Tap "Mastered"
      await tester.tap(masteredBtn);
      await tester.pump();

      // Verify updateWordProgress and addXP were called via ProgressService
      verify(() => mockStorage.updateWordProgress('vocab_1', true, firstAttempt: true)).called(1);
      verify(() => mockStorage.addXP(10)).called(1);
      expect(find.text('Progress saved! +10 XP awarded'), findsOneWidget);

      // Clear invocations to test duplicate tap guard
      clearInteractions(mockStorage);

      // Tap "Mastered" AGAIN on the same card -> should NOT call updateWordProgress or addXP again
      await tester.tap(masteredBtn);
      await tester.pump();

      verifyNever(() => mockStorage.updateWordProgress(any(), any(), firstAttempt: any(named: 'firstAttempt')));
      verifyNever(() => mockStorage.addXP(any()));
      expect(find.text('Card already reviewed this session'), findsOneWidget);
    });

    testWidgets('auto-advance is cleanly cancelled on manual Next navigation without stale card jumps', (tester) async {
      await pumpScreen(tester);

      // Start auto-advance
      final playFinder = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
      await tester.tap(playFinder);
      await tester.pump();

      // Pause icon is visible -> auto-advancing
      expect(find.widgetWithIcon(IconButton, Icons.pause_rounded), findsOneWidget);

      // Manually tap Next while auto-advance is waiting
      final nextFinder = find.widgetWithIcon(IconButton, Icons.chevron_right_rounded);
      await tester.tap(nextFinder);
      await tester.pump();

      // Card moved to 2 of 3 and auto-advance is cancelled
      expect(find.text('Card 2 of 3'), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.play_arrow_rounded), findsOneWidget);

      // Advance clock by 3 seconds - verify card does NOT jump to Card 3 from a stale timer
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Card 2 of 3'), findsOneWidget);
    });

    testWidgets('applying empty filter during run shows empty state without popping bogus Deck Completed dialog', (tester) async {
      await pumpScreen(tester);

      // Auto-advance
      final playFinder = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
      await tester.tap(playFinder);
      await tester.pump();

      // Toggle flagged filter when no cards are flagged
      final flaggedChip = find.widgetWithText(FilterChip, 'Bookmarked');
      expect(flaggedChip, findsOneWidget);
      await tester.tap(flaggedChip);
      await tester.pump();

      // Empty state should be visible
      expect(find.text('No cards found'), findsOneWidget);
      // No completion dialog
      expect(find.text('Deck Completed!'), findsNothing);
    });

    testWidgets('guards session completion XP: awards once per pass only if cards were studied, and blocks repeat-swipe XP farming', (tester) async {
      await pumpScreen(tester);

      // Start on card 1 (#G1)
      // Navigate to last card without studying/flipping any cards
      final nextFinder = find.widgetWithIcon(IconButton, Icons.chevron_right_rounded);
      await tester.tap(nextFinder);
      await tester.pump();
      await tester.tap(nextFinder);
      await tester.pump();
      expect(find.text('#2'), findsOneWidget); // last card

      // Clear any setup calls
      clearInteractions(mockStorage);

      // Swipe left on last card with ZERO cards studied
      await tester.fling(find.text('estar'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      // Completion dialog should show, but recordSessionComplete should NOT have awarded XP or saved a session
      expect(find.text('Deck Completed!'), findsOneWidget);
      verifyNever(() => mockStorage.saveSession(any()));
      verifyNever(() => mockStorage.incrementDailySessions());

      // Dismiss dialog by tapping Restart Deck
      await tester.tap(find.text('Restart Deck'));
      await tester.pumpAndSettle();

      // Deck restarted to card 0 (#G1)
      expect(find.text('#G1'), findsOneWidget);

      // Advance to card #1 and study it by flipping
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(find.text('#1'), findsOneWidget);

      // Flip card to reveal back face (study it)
      await tester.tap(find.text('Flip Card'));
      await tester.pumpAndSettle();
      expect(find.text('Show Front'), findsOneWidget);

      // Navigate to the last card (#2)
      await tester.tap(nextFinder);
      await tester.pumpAndSettle();
      expect(find.text('#2'), findsOneWidget);

      clearInteractions(mockStorage);

      // Swipe left on last card to complete deck
      await tester.fling(find.text('estar'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      // Verify completion dialog is shown AND session was saved with ActivityType.flashcards
      expect(find.text('Deck Completed!'), findsOneWidget);
      verify(() => mockStorage.saveSession(any(
        that: isA<SessionRecord>().having((s) => s.activityType, 'activityType', ActivityType.flashcards),
      ))).called(1);
      verify(() => mockStorage.incrementDailySessions()).called(1);

      // Dismiss dialog via Navigator pop (simulating barrier dismissal)
      Navigator.of(tester.element(find.text('Deck Completed!'))).pop();
      await tester.pumpAndSettle();

      clearInteractions(mockStorage);

      // Attempt repeat swipe-left on the same pass to farm XP
      await tester.fling(find.text('estar'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      // Verify recordSessionComplete was NOT called again (once-per-pass invariant preserved)
      verifyNever(() => mockStorage.saveSession(any()));
      verifyNever(() => mockStorage.incrementDailySessions());
    });

    testWidgets('defaults to shuffled deck on startup and toggles to sequential', (tester) async {
      await pumpScreen(tester, initialShuffle: true);

      // App bar shuffle button tooltip indicates shuffled mode
      expect(find.byTooltip('Shuffled (tap for sequential)'), findsOneWidget);

      // Tap to toggle to sequential
      await tester.tap(find.byTooltip('Shuffled (tap for sequential)'));
      await tester.pump();
      expect(find.byTooltip('Sequential (tap to shuffle)'), findsOneWidget);
    });

    testWidgets('on flipped side, reads example sentence in both pt-PT and en-US after English definition', (tester) async {
      const exampleCard = FlashcardItem(
        id: '10',
        cardNumber: '#10',
        portuguese: 'aprender',
        english: 'to learn',
        category: 'VERBS',
        examplePt: 'Eu aprendo português todos os dias.',
        exampleEn: 'I learn Portuguese every day.',
      );

      await pumpScreen(tester, cards: [exampleCard]);

      clearInteractions(mockTts);

      // Flip card to back
      await tester.tap(find.text('Flip Card'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // flip animation

      // Advance delay for Portuguese sentence
      await tester.pump(const Duration(milliseconds: 350));

      // Advance delay for English sentence
      await tester.pump(const Duration(milliseconds: 300));

      // Verify sequence of calls in exact order
      verifyInOrder([
        () => mockTts.speak('to learn', language: 'en-US', rate: 1.0),
        () => mockTts.speak('Eu aprendo português todos os dias.', language: 'pt-PT', rate: any(named: 'rate')),
        () => mockTts.speak('I learn Portuguese every day.', language: 'en-US', rate: 1.0),
      ]);

      // Also verify example sentence audio replay button
      clearInteractions(mockTts);
      final exampleSpeakerFinder = find.byTooltip('Listen to example sentence');
      expect(exampleSpeakerFinder, findsOneWidget);
      await tester.tap(exampleSpeakerFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 300));

      verifyInOrder([
        () => mockTts.speak('to learn', language: 'en-US', rate: 1.0),
        () => mockTts.speak('Eu aprendo português todos os dias.', language: 'pt-PT', rate: any(named: 'rate')),
        () => mockTts.speak('I learn Portuguese every day.', language: 'en-US', rate: 1.0),
      ]);
    });

    testWidgets('auto-advance waits for example sentence speech and gives generous reading time before advancing', (tester) async {
      final ttsCompleter = Completer<void>();
      when(() => mockTts.speak(
        'Eu aprendo português todos os dias.',
        language: 'pt-PT',
        rate: any(named: 'rate'),
      )).thenAnswer((_) => ttsCompleter.future);

      const card1 = FlashcardItem(
        id: '10',
        cardNumber: '#10',
        portuguese: 'aprender',
        english: 'to learn',
        category: 'VERBS',
        examplePt: 'Eu aprendo português todos os dias.',
        exampleEn: 'I learn Portuguese every day.',
      );
      const card2 = FlashcardItem(
        id: '11',
        cardNumber: '#11',
        portuguese: 'falar',
        english: 'to speak',
        category: 'VERBS',
      );

      await pumpScreen(tester, cards: [card1, card2]);

      // Start auto-advance
      final playFinder = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
      await tester.tap(playFinder);
      await tester.pump();

      // Step 2 (speak PT) completes immediately. Step 3 recall timer is 2000ms.
      await tester.pump(const Duration(milliseconds: 2050));
      // Flip to back face occurs (380ms)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // English speaks, then 350ms delay
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Now Portuguese sentence is speaking and held by ttsCompleter
      expect(find.text('to learn'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);

      // Even after 5 seconds while TTS is speaking, it MUST NOT advance
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('to learn'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);

      // Complete TTS
      ttsCompleter.complete();
      await tester.pump();

      // English sentence delay (300ms)
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump();

      // Now post-reading timer (2000ms) begins. Halfway through (1000ms), still on Card 1
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('to learn'), findsOneWidget);
      expect(find.text('Card 1 of 2'), findsOneWidget);

      // After completing post-reading window (remaining 1050ms)
      await tester.pump(const Duration(milliseconds: 1050));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // NOW it advances to Card 2!
      expect(find.text('Card 2 of 2'), findsOneWidget);
      expect(find.text('#11'), findsOneWidget);
      expect(find.text('falar'), findsOneWidget);
    });

    testWidgets('auto-advance displays timer on front face, awaits Portuguese speech, and waits for timer before flipping', (tester) async {
      final ptSpeechCompleter = Completer<void>();
      when(() => mockTts.speak(
        'falar',
        language: 'pt-PT',
        rate: any(named: 'rate'),
      )).thenAnswer((_) => ptSpeechCompleter.future);

      const card = FlashcardItem(
        id: '1',
        cardNumber: '#1',
        portuguese: 'falar',
        english: 'to speak',
        category: 'VERBS',
      );

      await pumpScreen(tester, cards: [card]);

      // Start auto-advance
      final playFinder = find.widgetWithIcon(IconButton, Icons.play_arrow_rounded);
      await tester.tap(playFinder);
      await tester.pump();

      // Step 2: Portuguese is speaking and held by ptSpeechCompleter
      // Even after 3 seconds, card MUST NOT flip while Portuguese is still being read
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('falar'), findsOneWidget);
      expect(find.text('Flip Card'), findsOneWidget);

      // Now complete Portuguese speech
      ptSpeechCompleter.complete();
      await tester.pump();
      await tester.pump();

      // Step 3: Now the front-face countdown timer begins.
      // Halfway through (1000ms), card is still on the front face, showing timer hint
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('falar'), findsOneWidget);
      expect(find.text('Flip Card'), findsOneWidget);
      expect(find.text('Flipping card soon...'), findsOneWidget);

      // After the full 2000ms countdown elapses:
      await tester.pump(const Duration(milliseconds: 1050));
      await tester.pumpAndSettle();

      // NOW the card has flipped to the back side!
      expect(find.text('to speak'), findsOneWidget);
      expect(find.text('Show Front'), findsOneWidget);
    });

    testWidgets('starts auto-advance immediately on first launch with initialAutoAdvance true (default)', (tester) async {
      const card = FlashcardItem(
        id: '1',
        cardNumber: '#1',
        portuguese: 'olá',
        english: 'hello',
        category: 'GENERAL',
      );

      // Default pump with initialAutoAdvance: true
      await pumpScreen(tester, cards: [card], initialAutoAdvance: true);

      // Verify it immediately shows Pause button (active auto-advance)
      expect(find.widgetWithIcon(IconButton, Icons.pause_rounded), findsOneWidget);

      // First word spoken
      verify(() => mockTts.speak('olá', language: 'pt-PT', rate: any(named: 'rate'))).called(1);

      // Timer runs on front face (halfway)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('olá'), findsOneWidget);
      expect(find.text('Flipping card soon...'), findsOneWidget);

      // Complete timer
      await tester.pump(const Duration(milliseconds: 1050));
      await tester.pumpAndSettle();

      // Card flips to backside automatically!
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('Show Front'), findsOneWidget);
    });

    testWidgets('empty deck with initialCards: [] and default initialAutoAdvance renders No cards found without throwing RangeError', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            ttsServiceProvider.overrideWithValue(mockTts),
          ],
          child: const MaterialApp(
            home: FlashcardsScreen(
              initialCards: [],
            ),
          ),
        ),
      );
      await tester.pump();

      // Empty state renders cleanly
      expect(find.text('No cards found'), findsOneWidget);
      expect(find.text('Try clearing your active filters or bookmarks.'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      // Countdown bar and sibling deck progress bar do not render
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('grammar card explanation is spoken aloud by TTS rather than read silently and advances via AnimationController', (tester) async {
      const grammarCard = FlashcardItem(
        id: 'G1',
        cardNumber: '#G1',
        category: 'EXPLANATION',
        portuguese: 'Verbos Reflexivos',
        english: 'Reflexive Verbs',
        wordType: 'grammar',
        grammarExplanation: 'Used when subject and object are the same.',
        isGrammarCard: true,
      );
      const nextCard = FlashcardItem(
        id: '1',
        cardNumber: '#1',
        category: 'VERBS',
        portuguese: 'falar',
        english: 'to speak',
      );

      await pumpScreen(tester, cards: [grammarCard, nextCard], initialShuffle: false, initialAutoAdvance: true);
      await tester.pump();

      // Front face countdown for grammar card (2600ms) + flip animation (400ms)
      await tester.pump(const Duration(milliseconds: 2650));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Flipped to back face
      expect(find.text('Reflexive Verbs'), findsOneWidget);
      expect(find.text('Show Front'), findsOneWidget);

      // Verify that the grammar explanation is SPOKEN aloud by TTS in English
      verify(() => mockTts.speak('Reflexive Verbs', language: 'en-US', rate: any(named: 'rate'))).called(1);
      // Wait for delay between title and explanation speech (350ms)
      await tester.pump(const Duration(milliseconds: 400));
      verify(() => mockTts.speak(any(that: contains('Used when subject and object are the same')), language: 'en-US', rate: any(named: 'rate'))).called(1);
      await tester.pump();

      // Back face reading countdown starts with AnimationController (3000ms). Halfway through (1500ms):
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Reflexive Verbs'), findsOneWidget);
      expect(find.text('Advancing to next card...'), findsOneWidget);

      // Advance through remainder of countdown (1600ms) + flip animation reset (400ms)
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now advanced to next card
      expect(find.text('falar'), findsOneWidget);
    });

    testWidgets('displays Listening... indicator while back-face audio is playing', (tester) async {
      final completer = Completer<void>();
      when(
        () => mockTts.speak('hello', language: 'en-US', rate: any(named: 'rate')),
      ).thenAnswer((_) => completer.future);

      const card1 = FlashcardItem(
        id: '1',
        cardNumber: '#1',
        portuguese: 'olá',
        english: 'hello',
        category: 'GENERAL',
      );
      const card2 = FlashcardItem(
        id: '2',
        cardNumber: '#2',
        portuguese: 'tchau',
        english: 'bye',
        category: 'GENERAL',
      );

      await pumpScreen(tester, cards: [card1, card2], initialShuffle: false, initialAutoAdvance: true);
      await tester.pump();
      await tester.pump();

      // Front countdown (2050ms) + flip animation (400ms)
      await tester.pump(const Duration(milliseconds: 2050));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
      expect(find.text('Listening...'), findsOneWidget);

      // Complete TTS
      completer.complete();
      await tester.pump();
      await tester.pump();

      // Once TTS finishes and step 6 reading ticker starts:
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Advancing to next card...'), findsOneWidget);
    });

    testWidgets('pausing during speech delay unblocks completer immediately and cancels subsequent speech', (tester) async {
      const card1 = FlashcardItem(
        id: '1',
        cardNumber: '#1',
        portuguese: 'olá',
        english: 'hello',
        category: 'GENERAL',
        examplePt: 'Olá, como está?',
        exampleEn: 'Hello, how are you?',
      );
      const card2 = FlashcardItem(
        id: '2',
        cardNumber: '#2',
        portuguese: 'obrigado',
        english: 'thank you',
        category: 'GENERAL',
      );

      await pumpScreen(tester, cards: [card1, card2], initialShuffle: false, initialAutoAdvance: true);
      await tester.pump();
      await tester.pump();

      // Front countdown (2050ms) + flip animation (400ms)
      await tester.pump(const Duration(milliseconds: 2050));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // Card is flipped to back face. English "hello" has been spoken.
      verify(() => mockTts.speak('hello', language: 'en-US', rate: any(named: 'rate'))).called(1);

      // Now execution is waiting in _speechDelay(350ms) before speaking examplePt.
      // Pause auto-advance mid-delay.
      final pauseFinder = find.widgetWithIcon(IconButton, Icons.pause_rounded);
      await tester.tap(pauseFinder);
      await tester.pump();

      // Advance time past the delay duration (500ms)
      await tester.pump(const Duration(milliseconds: 500));

      // Verify that the example sentences were NEVER spoken because the chain token cancelled it
      verifyNever(() => mockTts.speak(
        'Olá, como está?',
        language: 'pt-PT',
        rate: any(named: 'rate'),
      ));
      verifyNever(() => mockTts.speak(
        'Hello, how are you?',
        language: 'en-US',
        rate: any(named: 'rate'),
      ));

      // There must be no pending timers left
    });
  });
}

