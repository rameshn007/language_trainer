import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/carplay_service.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/services/progress_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'helpers/carplay_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    registerCarPlayFallbackValues();
    tempDir = await Directory.systemTemp.createTemp('carplay_flag_test');
    setupCarPlayPlatformChannels(tempDir);
  });

  tearDownAll(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
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

  group('CarPlayService - Flag for Review In-Car Integration', () {
    test('strictly adheres to 8-row limit and sets up Flag for Review in Section 0', () async {
      final storage = FakeStorageService();
      final audioPlayer = MockAudioPlayer();
      final contentService = MockListenRepeatContentService();
      final tts = MockTtsService();
      final progressService = MockProgressService();

      when(() => audioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => audioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => audioPlayer.currentIndex).thenReturn(0);
      when(() => audioPlayer.playing).thenReturn(false);
      when(() => audioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(() => audioPlayer.setAudioSource(any(), initialIndex: any(named: 'initialIndex'), initialPosition: any(named: 'initialPosition'))).thenAnswer((_) async => const Duration(seconds: 1));
      when(() => audioPlayer.setSpeed(any())).thenAnswer((_) async {});
      when(() => audioPlayer.play()).thenAnswer((_) async {});
      when(() => audioPlayer.stop()).thenAnswer((_) async {});
      when(() => audioPlayer.dispose()).thenAnswer((_) async {});

      final testItems = [
        LanguageItem(id: 'w1', portuguese: 'Obrigado', english: 'Thank you'),
        LanguageItem(id: 'w2', portuguese: 'De nada', english: "You're welcome"),
      ];

      when(() => contentService.loadContent(mode: any(named: 'mode'))).thenAnswer((_) async => testItems);
      when(() => tts.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((inv) async {
        final path = inv.positionalArguments[1] as String;
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(List.filled(1000, 0));
      });

      final vm = ListenRepeatViewModel(audioPlayer: audioPlayer);
      final container = ProviderContainer(
        overrides: [
          listenRepeatViewModelProvider.overrideWith(() => vm),
          storageServiceProvider.overrideWithValue(storage),
          listenRepeatContentServiceProvider.overrideWithValue(contentService),
          ttsServiceProvider.overrideWithValue(tts),
          progressServiceProvider.overrideWith(() => progressService),
        ],
      );

      final carPlay = CarPlayService();
      carPlay.init(container: container, storageService: storage);

      const channel = MethodChannel('language_trainer/carplay_scene');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      await waitForCondition(() => carPlay.playerTemplateForTesting != null);

      final template = carPlay.playerTemplateForTesting!;
      expect(template.sections.length, 3);
      expect(template.sections[0].items.length, 2, reason: 'Section 0 must have word + flag row');
      expect(template.sections[1].items.length, 3, reason: 'Section 1 must have 3 playback controls');
      expect(template.sections[2].items.length, 3, reason: 'Section 2 must have 3 session controls');

      final totalRows = template.sections.fold<int>(0, (sum, sec) => sum + sec.items.length);
      expect(totalRows, 8, reason: 'CarPlay template strictly capped at 8 items');

      final flagItem = carPlay.flagItemForTesting;
      expect(flagItem, isNotNull);
      expect(flagItem!.text, '☆ Flag for Review');
      expect(flagItem.detailText, 'Save to study later on phone');
    });

    test('taps on flagItem toggle flagged state round-trip (flag and unflag)', () async {
      final storage = FakeStorageService();
      final audioPlayer = MockAudioPlayer();
      final contentService = MockListenRepeatContentService();
      final tts = MockTtsService();
      final progressService = MockProgressService();

      when(() => audioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => audioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => audioPlayer.currentIndex).thenReturn(0);
      when(() => audioPlayer.playing).thenReturn(false);
      when(() => audioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(() => audioPlayer.setAudioSource(any(), initialIndex: any(named: 'initialIndex'), initialPosition: any(named: 'initialPosition'))).thenAnswer((_) async => const Duration(seconds: 1));
      when(() => audioPlayer.setSpeed(any())).thenAnswer((_) async {});
      when(() => audioPlayer.play()).thenAnswer((_) async {});
      when(() => audioPlayer.stop()).thenAnswer((_) async {});
      when(() => audioPlayer.dispose()).thenAnswer((_) async {});

      final testItem = LanguageItem(id: 'word_flag_1', portuguese: 'Desculpe', english: 'Sorry');
      when(() => contentService.loadContent(mode: any(named: 'mode'))).thenAnswer((_) async => [testItem]);
      when(() => tts.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((inv) async {
        final path = inv.positionalArguments[1] as String;
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(List.filled(1000, 0));
      });

      final vm = ListenRepeatViewModel(audioPlayer: audioPlayer);
      final container = ProviderContainer(
        overrides: [
          listenRepeatViewModelProvider.overrideWith(() => vm),
          storageServiceProvider.overrideWithValue(storage),
          listenRepeatContentServiceProvider.overrideWithValue(contentService),
          ttsServiceProvider.overrideWithValue(tts),
          progressServiceProvider.overrideWith(() => progressService),
        ],
      );

      final carPlay = CarPlayService();
      carPlay.init(container: container, storageService: storage);

      const channel = MethodChannel('language_trainer/carplay_scene');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      await waitForCondition(() => carPlay.playerTemplateForTesting != null);
      await waitForCondition(() => container.read(listenRepeatViewModelProvider).currentItem != null);
      final flagItem = carPlay.flagItemForTesting!;

      // 1. Initial state: not flagged
      expect(storage.isItemFlagged('word_flag_1'), isFalse);
      expect(flagItem.text, '☆ Flag for Review');

      // 2. First tap -> flag it
      var completeCalled = false;
      flagItem.onPress!(() => completeCalled = true, flagItem);
      expect(completeCalled, isTrue);

      await waitForCondition(() => storage.isItemFlagged('word_flag_1') == true);
      expect(storage.isItemFlagged('word_flag_1'), isTrue);
      expect(flagItem.text, '★ Flagged for Review');
      expect(flagItem.detailText, 'Saved to study later on phone');

      // 3. Second tap -> unflag it
      flagItem.onPress!(() => completeCalled = true, flagItem);
      await waitForCondition(() => storage.isItemFlagged('word_flag_1') == false);
      expect(storage.isItemFlagged('word_flag_1'), isFalse);
      expect(flagItem.text, '☆ Flag for Review');
      expect(flagItem.detailText, 'Save to study later on phone');
    });

    test('word transition updates flag row when transitioning between unflagged and flagged words', () async {
      final item1 = LanguageItem(id: 'w1', portuguese: 'Bom dia', english: 'Good morning');
      final item2 = LanguageItem(id: 'w2', portuguese: 'Boa noite', english: 'Good night');
      // w2 is pre-flagged in storage, w1 is not
      final storage = FakeStorageService(initialFlaggedIds: {'w2'});

      final audioPlayer = MockAudioPlayer();
      final contentService = MockListenRepeatContentService();
      final tts = MockTtsService();
      final progressService = MockProgressService();

      final currentIndexController = StreamController<int?>.broadcast();
      var currentTrackIndex = 0;
      when(() => audioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => audioPlayer.currentIndexStream).thenAnswer((_) => currentIndexController.stream);
      when(() => audioPlayer.currentIndex).thenAnswer((_) => currentTrackIndex);
      when(() => audioPlayer.playing).thenReturn(false);
      when(() => audioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(() => audioPlayer.setAudioSource(any(), initialIndex: any(named: 'initialIndex'), initialPosition: any(named: 'initialPosition'))).thenAnswer((_) async {
        currentIndexController.add(0);
        return const Duration(seconds: 1);
      });
      when(() => audioPlayer.setSpeed(any())).thenAnswer((_) async {});
      when(() => audioPlayer.play()).thenAnswer((_) async {});
      when(() => audioPlayer.stop()).thenAnswer((_) async {});
      when(() => audioPlayer.dispose()).thenAnswer((_) async {
        await currentIndexController.close();
      });
      when(() => audioPlayer.seek(any(), index: any(named: 'index'))).thenAnswer((inv) async {
        final idx = inv.namedArguments[#index] as int;
        currentTrackIndex = idx;
        currentIndexController.add(idx);
      });

      when(() => contentService.loadContent(mode: any(named: 'mode'))).thenAnswer((_) async => [item1, item2]);
      when(() => tts.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((inv) async {
        final path = inv.positionalArguments[1] as String;
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(List.filled(1000, 0));
      });

      final vm = ListenRepeatViewModel(audioPlayer: audioPlayer);
      final container = ProviderContainer(
        overrides: [
          listenRepeatViewModelProvider.overrideWith(() => vm),
          storageServiceProvider.overrideWithValue(storage),
          listenRepeatContentServiceProvider.overrideWithValue(contentService),
          ttsServiceProvider.overrideWithValue(tts),
          progressServiceProvider.overrideWith(() => progressService),
        ],
      );

      final carPlay = CarPlayService();
      carPlay.init(container: container, storageService: storage);

      const channel = MethodChannel('language_trainer/carplay_scene');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      await waitForCondition(() => carPlay.playerTemplateForTesting != null);
      await waitForCondition(() => container.read(listenRepeatViewModelProvider).currentItem != null);
      final flagItem = carPlay.flagItemForTesting!;

      final firstItem = container.read(listenRepeatViewModelProvider).currentItem!;
      final firstFlagged = storage.isItemFlagged(firstItem.id);
      expect(flagItem.text, CarPlayService.formatFlagItemText(firstFlagged));

      // Advance to next word
      final notifier = container.read(listenRepeatViewModelProvider.notifier);
      await notifier.nextWord();

      await waitForCondition(() {
        final current = container.read(listenRepeatViewModelProvider).currentItem;
        return current != null && current.id != firstItem.id;
      });

      final secondItem = container.read(listenRepeatViewModelProvider).currentItem!;
      final secondFlagged = storage.isItemFlagged(secondItem.id);
      // Verify flag row updated to match second item's flag state
      await waitForCondition(() => flagItem.text == CarPlayService.formatFlagItemText(secondFlagged));
      expect(flagItem.text, CarPlayService.formatFlagItemText(secondFlagged));
      expect(flagItem.detailText, CarPlayService.formatFlagItemDetailText(secondFlagged));
    });

    test('omits flag row when storageService is null', () async {
      final audioPlayer = MockAudioPlayer();
      final contentService = MockListenRepeatContentService();
      final tts = MockTtsService();
      final progressService = MockProgressService();

      when(() => audioPlayer.playingStream).thenAnswer((_) => Stream.value(false));
      when(() => audioPlayer.currentIndexStream).thenAnswer((_) => Stream.value(0));
      when(() => audioPlayer.currentIndex).thenReturn(0);
      when(() => audioPlayer.playing).thenReturn(false);
      when(() => audioPlayer.processingState).thenReturn(ProcessingState.ready);
      when(() => audioPlayer.setAudioSource(any(), initialIndex: any(named: 'initialIndex'), initialPosition: any(named: 'initialPosition'))).thenAnswer((_) async => const Duration(seconds: 1));
      when(() => audioPlayer.setSpeed(any())).thenAnswer((_) async {});
      when(() => audioPlayer.play()).thenAnswer((_) async {});
      when(() => audioPlayer.stop()).thenAnswer((_) async {});
      when(() => audioPlayer.dispose()).thenAnswer((_) async {});

      final testItem = LanguageItem(id: 'w1', portuguese: 'Obrigado', english: 'Thank you');
      when(() => contentService.loadContent(mode: any(named: 'mode'))).thenAnswer((_) async => [testItem]);
      when(() => tts.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((inv) async {
        final path = inv.positionalArguments[1] as String;
        final file = File(path);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(List.filled(1000, 0));
      });

      final vm = ListenRepeatViewModel(audioPlayer: audioPlayer);
      final container = ProviderContainer(
        overrides: [
          listenRepeatViewModelProvider.overrideWith(() => vm),
          listenRepeatContentServiceProvider.overrideWithValue(contentService),
          ttsServiceProvider.overrideWithValue(tts),
          progressServiceProvider.overrideWith(() => progressService),
        ],
      );

      final carPlay = CarPlayService();
      // Initialize WITHOUT storageService
      carPlay.init(container: container, storageService: null);

      const channel = MethodChannel('language_trainer/carplay_scene');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      await waitForCondition(() => carPlay.playerTemplateForTesting != null);
      final template = carPlay.playerTemplateForTesting!;
      expect(template.sections[0].items.length, 1, reason: 'Section 0 has only wordItem when storage is null');
      expect(carPlay.flagItemForTesting, isNull);
    });
  });
}
