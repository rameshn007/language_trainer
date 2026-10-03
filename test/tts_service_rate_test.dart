import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockStorageService storage;
  late TtsService ttsService;
  late List<MethodCall> methodCalls;

  setUp(() async {
    methodCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
      methodCalls.add(call);
      switch (call.method) {
        case 'getVoices':
          return [
            {
              'name': 'Joana',
              'locale': 'pt-PT',
              'identifier': 'test_pt_voice',
              'quality': 'enhanced',
            },
            {
              'name': 'Daniel',
              'locale': 'en-US',
              'identifier': 'test_en_voice',
              'quality': 'enhanced',
            },
          ];
        default:
          return 1;
      }
    });

    storage = _MockStorageService();
    when(() => storage.getSetting(any())).thenReturn(null);
    when(() => storage.saveSetting(any(), any())).thenAnswer((_) async {});
    ttsService = TtsService(storage);
    if (ttsService.initFuture != null) {
      await ttsService.initFuture;
    }
    methodCalls.clear();
  });

  tearDown(() async {
    await ttsService.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  group('TtsService - Speech Rate Deduplication & Isolation', () {
    test('setRate deduplicates redundant round-trips to the engine', () async {
      // Default rate is 1.0
      expect(ttsService.configuredRate, equals(1.0));

      // 1. Changing to 0.8 should invoke setSpeechRate
      await ttsService.setRate(0.8);
      expect(ttsService.configuredRate, equals(0.8));
      final rateCalls = methodCalls.where((c) => c.method == 'setSpeechRate').toList();
      expect(rateCalls.length, equals(1));
      expect(rateCalls.first.arguments, equals(0.4)); // 0.5 * 0.8 = 0.4

      // 2. Calling setRate with the same value (0.8) must NOT invoke setSpeechRate again
      methodCalls.clear();
      await ttsService.setRate(0.8);
      expect(methodCalls.where((c) => c.method == 'setSpeechRate'), isEmpty);
    });

    test('speak at current configuredRate incurs 0 extra setSpeechRate round-trips', () async {
      // configuredRate is 1.0 by default. Speaking at 1.0 should have 0 setSpeechRate calls.
      await ttsService.speak('Olá mundo', rate: 1.0);
      final rateCalls = methodCalls.where((c) => c.method == 'setSpeechRate').toList();
      expect(rateCalls, isEmpty);
    });

    test('speak with temporary rate restores previous screen configuredRate', () async {
      // Suppose QuizScreen configured rate to 0.6x
      await ttsService.setRate(0.6);
      expect(ttsService.configuredRate, equals(0.6));
      methodCalls.clear();

      // VoiceTrainer speaks with temporary rate 1.0x
      await ttsService.speak('Test', rate: 1.0);

      final rateCalls = methodCalls.where((c) => c.method == 'setSpeechRate').toList();
      // Should set rate to 0.5 (1.0x), then restore back to 0.3 (0.6x)
      expect(rateCalls.length, equals(2));
      expect(rateCalls[0].arguments, equals(0.5)); // temporary 1.0x (0.5 * 1.0)
      expect(rateCalls[1].arguments, equals(0.3)); // restored 0.6x (0.5 * 0.6)
      expect(ttsService.configuredRate, equals(0.6));
    });

    test('synthesizeToFile enforces base rate and restores screen configuredRate', () async {
      // Suppose PhraseTrainer configured rate to 0.8x
      await ttsService.setRate(0.8);
      expect(ttsService.configuredRate, equals(0.8));
      methodCalls.clear();

      // Listen & Repeat synthesizes a file without specifying rate (defaults to 1.0 base)
      await ttsService.synthesizeToFile('palavra', 'test.caf');

      final rateCalls = methodCalls.where((c) => c.method == 'setSpeechRate').toList();
      // Should set to base 0.5 (1.0x), then restore back to 0.4 (0.8x)
      expect(rateCalls.length, equals(2));
      expect(rateCalls[0].arguments, equals(0.5));
      expect(rateCalls[1].arguments, equals(0.4));
      expect(ttsService.configuredRate, equals(0.8));
    });
  });
}
