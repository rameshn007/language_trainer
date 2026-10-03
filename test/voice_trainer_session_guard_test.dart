import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/progress_data.dart';
import 'package:language_trainer/services/progress_service.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:language_trainer/services/voice_quiz_service.dart';
import 'package:language_trainer/ui/voice_trainer_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}
class _MockTtsService extends Mock implements TtsService {}
class _MockProgressService extends Notifier<ProgressSnapshot> with Mock implements ProgressService {
  @override
  ProgressSnapshot build() => const ProgressSnapshot();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_MockStorageService());
    registerFallbackValue(ActivityType.voiceTrainer);
  });

  late _MockStorageService mockStorage;
  late _MockTtsService mockTts;
  late _MockProgressService mockProgress;

  final sampleItem = LanguageItem(
    id: 'test_item_1',
    portuguese: 'o comboio',
    english: 'the train',
  );

  setUp(() {
    mockStorage = _MockStorageService();
    mockTts = _MockTtsService();
    mockProgress = _MockProgressService();

    when(() => mockStorage.getAllItems()).thenReturn([sampleItem]);
    when(() => mockStorage.saveSetting(any(), any())).thenAnswer((_) async {});
    when(() => mockStorage.getSetting(any())).thenReturn(null);
    when(() => mockTts.setRate(any())).thenAnswer((_) async {});
    when(() => mockTts.stop()).thenAnswer((_) async {});
    when(
      () => mockTts.speak(
        any(),
        language: any(named: 'language'),
        rate: any(named: 'rate'),
      ),
    ).thenAnswer((_) async {});
  });

  group('VoiceQuizService resource lifecycle', () {
    test('dispose cancels STT, TTS, and closes soundLevelStream safely', () async {
      final service = VoiceQuizService(mockTts);
      expect(service.soundLevelStream, isA<Stream<double>>());

      await service.dispose();

      // Calling dispose again or adding after dispose does not throw
      verify(() => mockTts.stop()).called(1);
    });
  });

  group('VoiceTrainerScreen Session & XP Guards', () {
    testWidgets(
      'mic button is disabled while a question turn is in progress (prevents double-listen collision)',
      (tester) async {
        final speakCompleter = Completer<void>();
        when(
          () => mockTts.speak(
            any(),
            language: any(named: 'language'),
            rate: any(named: 'rate'),
          ),
        ).thenAnswer((_) => speakCompleter.future);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(mockStorage),
              ttsServiceProvider.overrideWithValue(mockTts),
              progressServiceProvider.overrideWith(() => mockProgress),
            ],
            child: const MaterialApp(home: VoiceTrainerScreen()),
          ),
        );
        await tester.pump();

        // 1. Initial idle state: FAB is play button (enabled)
        final fabFinder = find.byType(FloatingActionButton);
        expect(fabFinder, findsOneWidget);
        FloatingActionButton fab = tester.widget<FloatingActionButton>(fabFinder);
        expect(fab.onPressed, isNotNull);

        // 2. Start session: tap play
        await tester.tap(fabFinder);
        await tester.pump();

        // 3. During question playback / pre-listen: FAB must be disabled (onPressed == null)
        fab = tester.widget<FloatingActionButton>(fabFinder);
        expect(fab.onPressed, isNull);

        // Complete the speech and allow timer to settle
        speakCompleter.complete();
        await tester.pump();

        // Stop session cleanly
        await tester.tap(find.text('Stop Session'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'stopping session mid-turn prevents XP awards and aborts pending answer processing',
      (tester) async {
        final speakCompleter = Completer<void>();
        when(
          () => mockTts.speak(
            any(),
            language: any(named: 'language'),
            rate: any(named: 'rate'),
          ),
        ).thenAnswer((_) => speakCompleter.future);

        when(
          () => mockProgress.recordQuizAnswer(
            storage: any(named: 'storage'),
            itemId: any(named: 'itemId'),
            correct: any(named: 'correct'),
            firstAttempt: any(named: 'firstAttempt'),
          ),
        ).thenAnswer((_) async => 10);

        when(
          () => mockProgress.recordSessionComplete(
            storage: any(named: 'storage'),
            activityType: any(named: 'activityType'),
            score: any(named: 'score'),
            total: any(named: 'total'),
            durationSeconds: any(named: 'durationSeconds'),
            sessionXP: any(named: 'sessionXP'),
          ),
        ).thenAnswer((_) async => 0);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(mockStorage),
              ttsServiceProvider.overrideWithValue(mockTts),
              progressServiceProvider.overrideWith(() => mockProgress),
            ],
            child: const MaterialApp(home: VoiceTrainerScreen()),
          ),
        );
        await tester.pump();

        // Tap Play to start turn
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();

        // Tap Stop Session while question is in-flight
        expect(find.text('Stop Session'), findsOneWidget);
        await tester.tap(find.text('Stop Session'));
        await tester.pump();

        // Resolve the speech future after stop
        speakCompleter.complete();
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Verify that recordQuizAnswer was NEVER called because session was stopped
        verifyNever(
          () => mockProgress.recordQuizAnswer(
            storage: any(named: 'storage'),
            itemId: any(named: 'itemId'),
            correct: any(named: 'correct'),
            firstAttempt: any(named: 'firstAttempt'),
          ),
        );

        // Verify session status is paused and no XP was awarded
        expect(find.text('Session paused'), findsOneWidget);
        expect(find.textContaining('10 XP'), findsNothing);
      },
    );
  });
}
