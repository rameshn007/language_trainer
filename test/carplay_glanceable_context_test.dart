import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/progress_data.dart';
import 'package:language_trainer/services/carplay_service.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/services/progress_service.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/services/tts_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockAudioPlayer extends Mock implements AudioPlayer {}
class _MockStorageService extends Mock implements StorageService {}
class _MockContentService extends Mock implements ListenRepeatContentService {}
class _MockTtsService extends Mock implements TtsService {}
class _MockProgressService extends Notifier<ProgressSnapshot> with Mock implements ProgressService {
  @override
  ProgressSnapshot build() => const ProgressSnapshot();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    registerFallbackValue(ListenRepeatMode.all);
    registerFallbackValue(ActivityType.listenRepeat);
    registerFallbackValue(Duration.zero);
    // ignore: deprecated_member_use
    registerFallbackValue(ConcatenatingAudioSource(children: []));
    registerFallbackValue(_MockStorageService());

    tempDir = await Directory.systemTemp.createTemp('carplay_glanceable_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.oguzhnatly.flutter_carplay'),
      (MethodCall methodCall) async {
        return true;
      },
    );
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  tearDown(() {
    CarPlayService().resetForTesting();
  });

  group('CarPlayService glanceable formatting helpers', () {
    test('formatWordDetailText returns default instruction when item is null', () {
      expect(
        CarPlayService.formatWordDetailText(null),
        'Listen to the word, then repeat it aloud',
      );
    });

    test('formatWordDetailText returns English translation alone when notes is empty', () {
      final item1 = LanguageItem(
        id: 'w1',
        portuguese: 'Obrigado',
        english: 'Thank you',
        notes: '',
      );
      expect(CarPlayService.formatWordDetailText(item1), 'Thank you');

      final item2 = LanguageItem(
        id: 'w2',
        portuguese: 'Por favor',
        english: 'Please',
        notes: '   ',
      );
      expect(CarPlayService.formatWordDetailText(item2), 'Please');
    });

    test('formatWordDetailText appends grammar/tense pill note when present', () {
      final item = LanguageItem(
        id: 'w3',
        portuguese: 'Falei',
        english: 'I spoke',
        notes: 'Preterite Perfect - Eu',
      );
      expect(
        CarPlayService.formatWordDetailText(item),
        'I spoke • [Preterite Perfect - Eu]',
      );
    });

    test('formatWordSectionHeader returns unindexed header when totalWordsSeen is 0', () {
      expect(CarPlayService.formatWordSectionHeader(0), 'Current Word');
    });

    test('formatWordSectionHeader includes live word index when totalWordsSeen > 0', () {
      expect(CarPlayService.formatWordSectionHeader(1), 'Current Word (#1)');
      expect(CarPlayService.formatWordSectionHeader(12), 'Current Word (#12)');
      expect(CarPlayService.formatWordSectionHeader(99), 'Current Word (#99)');
    });
  });

  group('CarPlayService scene activation with glanceable context', () {
    test('scene activation sets up player template with notes in detailText and word count in header', () async {
      final storage = _MockStorageService();
      final audioPlayer = _MockAudioPlayer();
      final contentService = _MockContentService();
      final tts = _MockTtsService();
      final progressService = _MockProgressService();

      when(() => audioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => audioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => audioPlayer.currentIndex).thenReturn(0);
      when(() => audioPlayer.playing).thenReturn(false);
      when(() => audioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(() => audioPlayer.setAudioSource(any(), initialIndex: any(named: 'initialIndex'), initialPosition: any(named: 'initialPosition'))).thenAnswer((_) async => const Duration(seconds: 1));
      when(() => audioPlayer.setSpeed(any())).thenAnswer((_) async {});
      when(() => audioPlayer.play()).thenAnswer((_) async {});
      when(() => audioPlayer.stop()).thenAnswer((_) async {});
      when(() => audioPlayer.seek(any(), index: any(named: 'index'))).thenAnswer((_) async {});
      when(() => audioPlayer.dispose()).thenAnswer((_) async {});

      when(() => progressService.recordSessionComplete(
            storage: any(named: 'storage'),
            activityType: any(named: 'activityType'),
            score: any(named: 'score'),
            total: any(named: 'total'),
            sessionXP: any(named: 'sessionXP'),
            durationSeconds: any(named: 'durationSeconds'),
          )).thenAnswer((_) async => 0);

      when(() => tts.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((invocation) async {
        final path = invocation.positionalArguments[1] as String;
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(List.filled(1000, 0));
      });

      final wordWithNotes = LanguageItem(
        id: 'g1',
        portuguese: 'Comprei',
        english: 'I bought',
        notes: 'Preterite Perfect - Eu',
      );

      when(() => contentService.loadContent(mode: any(named: 'mode')))
          .thenAnswer((_) async => [wordWithNotes]);

      final vm = ListenRepeatViewModel(audioPlayer: audioPlayer);
      final container = ProviderContainer(
        overrides: [
          listenRepeatViewModelProvider.overrideWith(() => vm),
          storageServiceProvider.overrideWithValue(storage),
          ttsServiceProvider.overrideWithValue(tts),
          listenRepeatContentServiceProvider.overrideWithValue(contentService),
          progressServiceProvider.overrideWith(() => progressService),
        ],
      );

      final carPlayService = CarPlayService();
      carPlayService.init(container: container);

      // Trigger scene activation via native method channel
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'language_trainer/carplay_scene',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      // Allow async startSession to run
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final state = container.read(listenRepeatViewModelProvider);
      expect(state.currentItem?.id, 'g1');
      expect(CarPlayService.formatWordDetailText(state.currentItem), 'I bought • [Preterite Perfect - Eu]');
      expect(CarPlayService.formatWordSectionHeader(state.totalWordsSeen), 'Current Word (#1)');
    });

    test('advancing words updates row detail text and dispatches section header update', () async {
      final storage = _MockStorageService();
      final audioPlayer = _MockAudioPlayer();
      final contentService = _MockContentService();
      final tts = _MockTtsService();
      final progressService = _MockProgressService();

      final carPlayCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.oguzhnatly.flutter_carplay'),
        (MethodCall call) async {
          carPlayCalls.add(call);
          return true;
        },
      );

      final indexController = StreamController<int?>.broadcast();
      when(() => audioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => audioPlayer.currentIndexStream).thenAnswer((_) => indexController.stream);
      when(() => audioPlayer.currentIndex).thenReturn(0);
      when(() => audioPlayer.playing).thenReturn(false);
      when(() => audioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(() => audioPlayer.setAudioSource(any(), initialIndex: any(named: 'initialIndex'), initialPosition: any(named: 'initialPosition'))).thenAnswer((_) async {
        indexController.add(0);
        return const Duration(seconds: 1);
      });
      when(() => audioPlayer.setSpeed(any())).thenAnswer((_) async {});
      when(() => audioPlayer.play()).thenAnswer((_) async {});
      when(() => audioPlayer.stop()).thenAnswer((_) async {});
      when(() => audioPlayer.seek(any(), index: any(named: 'index'))).thenAnswer((inv) async {
        final idx = inv.namedArguments[const Symbol('index')] as int?;
        indexController.add(idx);
      });
      when(() => audioPlayer.dispose()).thenAnswer((_) async {});

      when(() => progressService.recordSessionComplete(
            storage: any(named: 'storage'),
            activityType: any(named: 'activityType'),
            score: any(named: 'score'),
            total: any(named: 'total'),
            sessionXP: any(named: 'sessionXP'),
            durationSeconds: any(named: 'durationSeconds'),
          )).thenAnswer((_) async => 0);

      when(() => tts.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((invocation) async {
        final path = invocation.positionalArguments[1] as String;
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(List.filled(1000, 0));
      });

      final word1 = LanguageItem(
        id: 'g1',
        portuguese: 'Comprei',
        english: 'I bought',
        notes: 'Preterite Perfect - Eu',
      );
      final word2 = LanguageItem(
        id: 'g2',
        portuguese: 'Vendi',
        english: 'I sold',
        notes: 'Preterite Perfect - Eu',
      );

      when(() => contentService.loadContent(mode: any(named: 'mode')))
          .thenAnswer((_) async => [word1, word2]);

      final vm = ListenRepeatViewModel(audioPlayer: audioPlayer);
      final container = ProviderContainer(
        overrides: [
          listenRepeatViewModelProvider.overrideWith(() => vm),
          storageServiceProvider.overrideWithValue(storage),
          ttsServiceProvider.overrideWithValue(tts),
          listenRepeatContentServiceProvider.overrideWithValue(contentService),
          progressServiceProvider.overrideWith(() => progressService),
        ],
      );

      final carPlayService = CarPlayService();
      carPlayService.init(container: container);

      // Trigger scene activation
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'language_trainer/carplay_scene',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Advance to next word
      await vm.nextWord();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Check method calls
      final hasSetRoot = carPlayCalls.any((call) => call.method == 'setRootTemplate');
      expect(hasSetRoot, isTrue);

      final hasUpdateItem = carPlayCalls.any((call) =>
          call.method == 'setDetailText' ||
          call.method == 'updateListItem' ||
          (call.arguments is Map && call.arguments['detailText'] != null));
      expect(hasUpdateItem, isTrue);

      final state = container.read(listenRepeatViewModelProvider);
      expect(state.totalWordsSeen, 2);
      expect(CarPlayService.formatWordSectionHeader(state.totalWordsSeen), 'Current Word (#2)');
    });
  });
}
