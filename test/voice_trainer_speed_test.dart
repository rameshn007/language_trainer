import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:language_trainer/services/voice_quiz_service.dart';
import 'package:language_trainer/ui/voice_trainer_screen.dart';

class _MockStorageService extends Mock implements StorageService {}

class _MockTtsService extends Mock implements TtsService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockTtsService mockTts;
  late _MockStorageService mockStorage;

  setUp(() {
    mockTts = _MockTtsService();
    mockStorage = _MockStorageService();

    when(() => mockStorage.getAllItems()).thenReturn([]);
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

  group('VoiceQuizService speech rate', () {
    test('defaults to 1.0 speech rate', () {
      final service = VoiceQuizService(mockTts);
      expect(service.currentRate, equals(1.0));
    });

    test('setSpeechRate updates currentRate without global mutation', () async {
      final service = VoiceQuizService(mockTts);
      await service.setSpeechRate(0.5);
      expect(service.currentRate, equals(0.5));
    });

    test('supports 0.4x, 0.5x, 0.6x, 1.0x rates', () async {
      final service = VoiceQuizService(mockTts);
      for (final rate in [0.4, 0.5, 0.6, 1.0]) {
        await service.setSpeechRate(rate);
        expect(service.currentRate, equals(rate));
      }
    });
  });

  group('VoiceTrainerScreen speed cycling widget test', () {
    testWidgets(
      'defaults to 1.0x speed and cycles 1.0x -> 0.4x -> 0.5x -> 0.6x -> 1.0x on user tap',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(mockStorage),
              ttsServiceProvider.overrideWithValue(mockTts),
            ],
            child: const MaterialApp(home: VoiceTrainerScreen()),
          ),
        );
        await tester.pump();

        // 1. Initial default speed must be 1.0x
        expect(find.text('1.0x'), findsOneWidget);
        expect(find.text('0.4x'), findsNothing);

        // 2. Tap 1.0x -> should advance to 0.4x
        await tester.tap(find.text('1.0x'));
        await tester.pump();
        expect(find.text('0.4x'), findsOneWidget);
        expect(find.text('1.0x'), findsNothing);

        // 3. Tap 0.4x -> should advance to 0.5x
        await tester.tap(find.text('0.4x'));
        await tester.pump();
        expect(find.text('0.5x'), findsOneWidget);
        expect(find.text('0.4x'), findsNothing);

        // 4. Tap 0.5x -> should advance to 0.6x
        await tester.tap(find.text('0.5x'));
        await tester.pump();
        expect(find.text('0.6x'), findsOneWidget);
        expect(find.text('0.5x'), findsNothing);

        // 5. Tap 0.6x -> should cycle back to 1.0x
        await tester.tap(find.text('0.6x'));
        await tester.pump();
        expect(find.text('1.0x'), findsOneWidget);
        expect(find.text('0.6x'), findsNothing);
      },
    );
  });
}
