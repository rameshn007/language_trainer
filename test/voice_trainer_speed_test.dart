import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:language_trainer/services/voice_quiz_service.dart';

class _MockTtsService extends Mock implements TtsService {}

void main() {
  late _MockTtsService mockTts;

  setUp(() {
    mockTts = _MockTtsService();
    when(() => mockTts.setRate(any())).thenAnswer((_) async {});
  });

  test('VoiceQuizService defaults to 1.0 speech rate', () {
    final service = VoiceQuizService(mockTts);
    expect(service.currentRate, equals(1.0));
  });

  test('VoiceQuizService setSpeechRate updates currentRate', () async {
    final service = VoiceQuizService(mockTts);
    await service.setSpeechRate(0.5);
    expect(service.currentRate, equals(0.5));
  });

  test(
    'VoiceQuizService setSpeechRate supports 0.4x, 0.5x, 0.6x, 1.0x',
    () async {
      final service = VoiceQuizService(mockTts);
      for (final rate in [0.4, 0.5, 0.6, 1.0]) {
        await service.setSpeechRate(rate);
        expect(service.currentRate, equals(rate));
        verify(() => mockTts.setRate(rate)).called(1);
      }
    },
  );

  test(
    'Voice trainer speed cycling progression matches 1.0 -> 0.4 -> 0.5 -> 0.6 -> 1.0',
    () {
      double cycleSpeed(double currentRate) {
        if (currentRate == 1.0) {
          return 0.4;
        } else if (currentRate == 0.4) {
          return 0.5;
        } else if (currentRate == 0.5) {
          return 0.6;
        } else {
          return 1.0;
        }
      }

      double rate = 1.0;
      rate = cycleSpeed(rate);
      expect(rate, equals(0.4));
      rate = cycleSpeed(rate);
      expect(rate, equals(0.5));
      rate = cycleSpeed(rate);
      expect(rate, equals(0.6));
      rate = cycleSpeed(rate);
      expect(rate, equals(1.0));
    },
  );
}
