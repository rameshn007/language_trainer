import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/flashcard_item.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:language_trainer/ui/flashcards/flashcards_screen.dart';

class _MockStorageService extends Mock implements StorageService {}
class _MockTtsService extends Mock implements TtsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      languageItemId: 'grammar_G1',
    ),
  ];

  setUp(() {
    mockTts = _MockTtsService();
    mockStorage = _MockStorageService();

    when(() => mockStorage.getAllItems()).thenReturn([]);
    when(() => mockStorage.isItemFlagged(any())).thenReturn(false);
    when(() => mockStorage.toggleItemFlagged(any())).thenAnswer((_) async => true);
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

  Future<void> pumpScreen(WidgetTester tester, {List<FlashcardItem>? cards}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          ttsServiceProvider.overrideWithValue(mockTts),
        ],
        child: MaterialApp(
          home: FlashcardsScreen(initialCards: cards ?? sampleCards),
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

      // Ensure no truncated ellipsis variants exist in the widget tree
      expect(find.text('aprend...'), findsNothing);
    });
  });
}
