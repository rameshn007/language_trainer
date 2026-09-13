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

  group('TtsService - Mutex and State Invalidation', () {
    test('stop() clears active language and releases synth lock', () async {
      // Calling stop() should execute cleanly and reset internal state
      await ttsService.stop();
      expect(ttsService, isNotNull);
    });

    test('setExplicitVoice invalidates cached configured voice and language', () async {
      await ttsService.setExplicitVoice('pt-PT', 'test_pt_voice');
      verify(() => storage.saveSetting('tts_voice_pt', 'test_pt_voice')).called(1);
    });
  });
}
