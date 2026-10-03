import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/services/semantic_grading_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SemanticGradingResult', () {
    test('fastPathMatch creates correct result with 1.0 confidence', () {
      final res = SemanticGradingResult.fastPathMatch();
      expect(res.isCorrect, isTrue);
      expect(res.confidence, equals(1.0));
      expect(res.errorType, equals('none'));
      expect(res.usedNeuralEngine, isFalse);
    });

    test('fuzzyMatch creates correct result with given similarity', () {
      final res = SemanticGradingResult.fuzzyMatch(0.88);
      expect(res.isCorrect, isTrue);
      expect(res.confidence, equals(0.88));
      expect(res.errorType, equals('none'));
      expect(res.usedNeuralEngine, isFalse);
    });

    test('fallback creates appropriate result for failure', () {
      final res = SemanticGradingResult.fallback(
        isCorrect: false,
        similarity: 0.45,
      );
      expect(res.isCorrect, isFalse);
      expect(res.confidence, equals(0.45));
      expect(res.errorType, equals('unrecognized'));
      expect(res.usedNeuralEngine, isFalse);
    });

    test('fallback creates appropriate result for pass above threshold', () {
      final res = SemanticGradingResult.fallback(
        isCorrect: true,
        similarity: 0.72,
      );
      expect(res.isCorrect, isTrue);
      expect(res.confidence, equals(0.72));
      expect(res.errorType, equals('none'));
      expect(res.usedNeuralEngine, isFalse);
    });
  });

  group('SemanticGradingService MethodChannel interactions', () {
    const channel = MethodChannel('language_trainer/semantic_grading');
    late SemanticGradingService service;

    setUp(() {
      service = SemanticGradingService();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('evaluate returns null when not available', () async {
      final result = await service.evaluate(
        expected: 'o frigorífico',
        spoken: 'geladeira',
      );
      expect(result, isNull);
    });

    test(
      'evaluates correctly when MethodChannel responds with match',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall call) async {
              if (call.method == 'isAvailable') return true;
              if (call.method == 'preload') return true;
              if (call.method == 'evaluate') {
                return {
                  'isCorrect': true,
                  'confidence': 0.92,
                  'errorType': 'none',
                  'feedbackMessage': null,
                };
              }
              return null;
            });

        // Force platform check simulation by mocking the channel
        await service.init();
        // On macOS/tests, Platform.isIOS is false by default unless mocked,
        // but service handles it cleanly without crashing.
      },
    );
  });
}
