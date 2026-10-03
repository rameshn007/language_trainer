import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:language_trainer/services/voice_quiz_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:language_trainer/services/semantic_grading_service.dart';

class _MockTtsService extends Mock implements TtsService {}

class _MockSemanticGradingService extends Mock
    implements SemanticGradingService {}

void main() {
  late VoiceQuizService service;
  late _MockTtsService mockTts;
  late _MockSemanticGradingService mockSemantic;

  setUp(() {
    mockTts = _MockTtsService();
    mockSemantic = _MockSemanticGradingService();
    when(() => mockSemantic.isAvailable).thenReturn(false);
    service = VoiceQuizService(mockTts, mockSemantic);
  });

  group('VoiceQuizService.checkAnswerAsync — Tier 1 & 2 Fast Path', () {
    test('exact match returns immediately with 1.0 confidence', () async {
      final res = await service.checkAnswerAsync('olá', 'olá');
      expect(res.isCorrect, isTrue);
      expect(res.confidence, equals(1.0));
      expect(res.usedNeuralEngine, isFalse);
      verifyNever(
        () => mockSemantic.evaluate(
          expected: any(named: 'expected'),
          spoken: any(named: 'spoken'),
          context: any(named: 'context'),
          locale: any(named: 'locale'),
        ),
      );
    });

    test(
      'substring match returns immediately without calling Core ML',
      () async {
        final res = await service.checkAnswerAsync(
          'o comboio rápido',
          'comboio',
        );
        expect(res.isCorrect, isTrue);
        expect(res.confidence, equals(1.0));
        expect(res.usedNeuralEngine, isFalse);
        verifyNever(
          () => mockSemantic.evaluate(
            expected: any(named: 'expected'),
            spoken: any(named: 'spoken'),
            context: any(named: 'context'),
            locale: any(named: 'locale'),
          ),
        );
      },
    );
  });

  group(
    'VoiceQuizService.checkAnswerAsync — Tier 3 High-Confidence Levenshtein',
    () {
      test(
        'minor typo with >0.85 similarity passes without Core ML invocation',
        () async {
          // 'computador' vs 'computadores' -> 2 diffs in 12 chars -> 1 - 2/12 = 0.833
          // 'computador' vs 'computadore' -> 1 diff in 11 chars -> 1 - 1/11 = 0.909 (> 0.85)
          final res = await service.checkAnswerAsync(
            'computador',
            'computadore',
          );
          expect(res.isCorrect, isTrue);
          expect(res.confidence, greaterThan(0.85));
          expect(res.usedNeuralEngine, isFalse);
          verifyNever(
            () => mockSemantic.evaluate(
              expected: any(named: 'expected'),
              spoken: any(named: 'spoken'),
              context: any(named: 'context'),
              locale: any(named: 'locale'),
            ),
          );
        },
      );
    },
  );

  group('VoiceQuizService.checkAnswerAsync — Tier 4 Semantic Core ML', () {
    test(
      'calls SemanticGradingService when fast-path and high Levenshtein fail',
      () async {
        when(() => mockSemantic.isAvailable).thenReturn(true);
        when(
          () => mockSemantic.evaluate(
            expected: any(named: 'expected'),
            spoken: any(named: 'spoken'),
            context: any(named: 'context'),
            locale: any(named: 'locale'),
          ),
        ).thenAnswer(
          (_) async => const SemanticGradingResult(
            isCorrect: true,
            confidence: 0.91,
            errorType: 'none',
            usedNeuralEngine: true,
          ),
        );

        // 'claro que sim' vs 'com certeza' (completely different letters, Levenshtein is low)
        final res = await service.checkAnswerAsync(
          'claro que sim',
          'com certeza',
          context: 'Of course',
          locale: 'pt-PT',
        );

        expect(res.isCorrect, isTrue);
        expect(res.confidence, equals(0.91));
        expect(res.usedNeuralEngine, isTrue);
        verify(
          () => mockSemantic.evaluate(
            expected: 'com certeza',
            spoken: 'claro que sim',
            context: 'Of course',
            locale: 'pt-PT',
          ),
        ).called(1);
      },
    );

    test(
      'rejects if Core ML marks correct but confidence is below 0.80 and falls back to Levenshtein',
      () async {
        when(() => mockSemantic.isAvailable).thenReturn(true);
        when(
          () => mockSemantic.evaluate(
            expected: any(named: 'expected'),
            spoken: any(named: 'spoken'),
            context: any(named: 'context'),
            locale: any(named: 'locale'),
          ),
        ).thenAnswer(
          (_) async => const SemanticGradingResult(
            isCorrect: true,
            confidence: 0.65, // Below 0.80 gate
            errorType: 'borderline',
            usedNeuralEngine: true,
          ),
        );

        // 'gato' vs 'automóvel' (completely different)
        final res = await service.checkAnswerAsync('gato', 'automóvel');

        expect(res.isCorrect, isFalse);
      },
    );

    test(
      'falls back to Levenshtein > 0.65 when Core ML is unavailable',
      () async {
        when(() => mockSemantic.isAvailable).thenReturn(false);

        // 'abacax' vs 'abacaxi' -> 1 - (1/7) = 0.857 (above 0.85 tier)
        // 'portuges' vs 'português' -> 1 - (2/9) = ~0.77 (between 0.65 and 0.85)
        final res = await service.checkAnswerAsync('portuges', 'português');

        expect(res.isCorrect, isTrue);
        expect(res.usedNeuralEngine, isFalse);
      },
    );
  });

  group('VoiceQuizService.isCorrect — Synchronous Contract Preservation', () {
    test('synchronous isCorrect contract is preserved unchanged', () {
      expect(service.isCorrect('Olá', 'Olá'), isTrue);
      expect(service.isCorrect('ola', 'olá'), isTrue);
      expect(service.isCorrect('gato', 'cão'), isFalse);
    });
  });
}
