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
    registerFallbackValue(LanguageItem(id: 'dummy', portuguese: 'ola', english: 'hello'));

    tempDir = await Directory.systemTemp.createTemp('carplay_flag_test');
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

  group('CarPlayService - Flagged Words Formatting Helpers', () {
    test('formatFlagItemText returns star indicator based on flagged state', () {
      expect(CarPlayService.formatFlagItemText(false), '☆ Flag for Review');
      expect(CarPlayService.formatFlagItemText(true), '★ Flagged for Review');
    });

    test('formatFlagItemDetailText returns clear instruction based on flagged state', () {
      expect(CarPlayService.formatFlagItemDetailText(false), 'Save to study later on phone');
      expect(CarPlayService.formatFlagItemDetailText(true), 'Saved to study later on phone');
    });
  });

  Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!condition() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(condition(), isTrue, reason: 'Condition not met within $timeout');
  }

  group('CarPlayService - Flag for Review In-Car Integration', () {
    test('player template adheres strictly to 8-row limit and includes flag row', () async {
      final storage = _MockStorageService();
      final audioPlayer = _MockAudioPlayer();
      final contentService = _MockContentService();
      final tts = _MockTtsService();
      final progressService = _MockProgressService();

      when(() => storage.isItemFlagged('w1')).thenReturn(false);
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

      final item = LanguageItem(
        id: 'w1',
        portuguese: 'Obrigado',
        english: 'Thank you',
      );

      when(() => contentService.loadContent(mode: any(named: 'mode')))
          .thenAnswer((_) async => [item]);

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

      await waitForCondition(() => container.read(listenRepeatViewModelProvider).currentItem != null);

      final template = carPlayService.playerTemplateForTesting;
      expect(template, isNotNull);

      // Verify sections and row counts:
      // Section 0: Current Word (wordItem, flagItem) -> 2 items
      // Section 1: Playback (pauseItem, previousItem, nextItem) -> 3 items
      // Section 2: Session (focusItem, speedItem, stopItem) -> 3 items
      // Total = 8 items!
      expect(template!.sections.length, 3);
      expect(template.sections[0].items.length, 2);
      expect(template.sections[1].items.length, 3);
      expect(template.sections[2].items.length, 3);

      final totalRows = template.sections.fold<int>(0, (sum, sec) => sum + sec.items.length);
      expect(totalRows, 8, reason: 'CarPlay template must strictly adhere to the 8-row limit');

      final flagItem = carPlayService.flagItemForTesting;
      expect(flagItem, isNotNull);
      expect(flagItem!.text, '☆ Flag for Review');
      expect(flagItem.detailText, 'Save to study later on phone');
    });

    test('tapping Flag row invokes StorageService toggle and updates row text', () async {
      final storage = _MockStorageService();
      final audioPlayer = _MockAudioPlayer();
      final contentService = _MockContentService();
      final tts = _MockTtsService();
      final progressService = _MockProgressService();

      when(() => storage.isItemFlagged('w1')).thenReturn(false);
      when(() => storage.toggleItemFlagged('w1', item: any(named: 'item'))).thenAnswer((_) async => true);

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

      final item = LanguageItem(
        id: 'w1',
        portuguese: 'Obrigado',
        english: 'Thank you',
      );

      when(() => contentService.loadContent(mode: any(named: 'mode')))
          .thenAnswer((_) async => [item]);

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

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'language_trainer/carplay_scene',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      await waitForCondition(() => container.read(listenRepeatViewModelProvider).currentItem != null);

      final flagItem = carPlayService.flagItemForTesting;
      expect(flagItem, isNotNull);

      // Trigger onPress on the flag item
      var completed = false;
      flagItem!.onPress!( () {
        completed = true;
      }, flagItem);

      expect(completed, isTrue);

      await waitForCondition(() => flagItem.text == '★ Flagged for Review');
      expect(flagItem.detailText, 'Saved to study later on phone');
      verify(() => storage.toggleItemFlagged('w1', item: any(named: 'item'))).called(1);
    });
  });
}
