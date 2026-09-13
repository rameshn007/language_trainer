import 'dart:async';
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

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
      switch (call.method) {
        case 'getVoices':
          return [
            {'name': 'Joana', 'locale': 'pt-PT', 'identifier': 'test_pt_voice', 'quality': 'enhanced'},
            {'name': 'Daniel', 'locale': 'en-US', 'identifier': 'test_en_voice', 'quality': 'enhanced'},
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
  });

  tearDown(() async {
    await ttsService.stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  group('TtsService - Mutex and Concurrency', () {
    test('serializes concurrent speak and synthesizeToFile calls', () async {
      final synthCompleter = Completer<int>();
      bool speakEntered = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        if (call.method == 'synthesizeToFile') {
          return synthCompleter.future;
        } else if (call.method == 'speak') {
          speakEntered = true;
          return 1;
        }
        return 1;
      });

      final synthFuture = ttsService.synthesizeToFile('Olá', '/path/to/pt.caf', language: 'pt-PT');
      // Allow microtasks to run so synthesizeToFile acquires the mutex and enters channel
      await Future.delayed(Duration.zero);

      final speakFuture = ttsService.speak('Hello', language: 'en-US');
      await Future.delayed(Duration.zero);

      // speak should not have entered the channel yet while synth is in-flight
      expect(speakEntered, isFalse);

      synthCompleter.complete(1);
      await synthFuture;
      await speakFuture;

      // After synth finishes, speak enters and completes
      expect(speakEntered, isTrue);
    });

    test('timeout path breaks lock with _flutterTts.stop() when previous call stalls', () async {
      ttsService.lockWaitTimeout = const Duration(milliseconds: 50);
      final hangingCompleter = Completer<int>();
      int stopCallCount = 0;
      bool secondCallExecuted = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        if (call.method == 'synthesizeToFile') {
          return hangingCompleter.future; // Stalls
        } else if (call.method == 'stop') {
          stopCallCount++;
          return 1;
        } else if (call.method == 'speak') {
          secondCallExecuted = true;
          return 1;
        }
        return 1;
      });

      // Call 1 hangs on synthesizeToFile
      unawaited(ttsService.synthesizeToFile('hanging', '/path/hang.caf', language: 'pt-PT'));
      await Future.delayed(Duration.zero);

      // Call 2 tries to speak, waits for lock, times out after 50ms, breaks lock with stop()
      await ttsService.speak('second call', language: 'en-US');

      expect(stopCallCount, greaterThanOrEqualTo(1));
      expect(secondCallExecuted, isTrue);
    });

    test('stale timed-out holder release does not clear lock owned by another call', () async {
      ttsService.lockWaitTimeout = const Duration(milliseconds: 40);
      final call1Completer = Completer<int>();
      final call2Completer = Completer<int>();
      bool call3Entered = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        if (call.method == 'synthesizeToFile') {
          return call1Completer.future;
        } else if (call.method == 'speak') {
          final text = call.arguments is String
              ? call.arguments as String
              : (call.arguments as dynamic)?['text'] as String?;
          if (text == 'call2') {
            return call2Completer.future;
          } else if (text == 'call3') {
            call3Entered = true;
            return 1;
          }
        }
        return 1;
      });

      // Call 1 acquires lock and hangs
      unawaited(ttsService.synthesizeToFile('call1', '/path/1.caf'));
      await Future.delayed(Duration.zero);

      // Call 2 waits for lock, times out, breaks lock, and acquires ownership
      final call2Future = ttsService.speak('call2');
      await Future.delayed(const Duration(milliseconds: 80));

      // Now Call 1 finally finishes late
      call1Completer.complete(1);
      await Future.delayed(Duration.zero);

      // Call 3 tries to speak: Call 2 still holds the lock! Call 3 must wait for Call 2
      final call3Future = ttsService.speak('call3');
      await Future.delayed(Duration.zero);
      expect(call3Entered, isFalse, reason: 'Call 3 must not enter while Call 2 holds lock');

      // Finish Call 2
      call2Completer.complete(1);
      await call2Future;
      await call3Future;
      expect(call3Entered, isTrue);
    });

    test('actionTimeout aborts hanging action with _flutterTts.stop() and throws TimeoutException', () async {
      ttsService.actionTimeout = const Duration(milliseconds: 50);
      int stopCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter_tts'), (call) async {
        if (call.method == 'speak') {
          return Completer<int>().future; // hangs forever
        } else if (call.method == 'stop') {
          stopCount++;
          return 1;
        }
        return 1;
      });

      expect(
        () => ttsService.speak('never finishes'),
        throwsA(isA<TimeoutException>()),
      );

      await Future.delayed(const Duration(milliseconds: 80));
      expect(stopCount, greaterThanOrEqualTo(1));
    });

    test('stop() clears cached voice configuration', () async {
      await ttsService.stop();
      expect(ttsService, isNotNull);
    });

    test('setExplicitVoice invalidates cached configured voice and language', () async {
      await ttsService.setExplicitVoice('pt-PT', 'test_pt_voice');
      verify(() => storage.saveSetting('tts_voice_pt', 'test_pt_voice')).called(1);
    });
  });
}
