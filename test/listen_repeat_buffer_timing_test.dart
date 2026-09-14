import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
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

Future<void> _waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  if (condition()) return;
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
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

    tempDir = await Directory.systemTemp.createTemp('lr_timing_test');
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
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  late _MockAudioPlayer audioPlayer;
  late _MockStorageService storage;
  late _MockContentService contentService;
  late _MockTtsService ttsService;
  late _MockProgressService progressService;
  late StreamController<int?> currentIndexController;
  late StreamController<bool> playingController;
  ProviderContainer? container;

  void setupContainer({List<LanguageItem>? customItems}) {
    audioPlayer = _MockAudioPlayer();
    storage = _MockStorageService();
    contentService = _MockContentService();
    ttsService = _MockTtsService();
    progressService = _MockProgressService();
    currentIndexController = StreamController<int?>.broadcast();
    playingController = StreamController<bool>.broadcast();

    when(() => audioPlayer.playingStream).thenAnswer((_) => playingController.stream);
    when(() => audioPlayer.currentIndexStream).thenAnswer((_) => currentIndexController.stream);
    when(() => audioPlayer.currentIndex).thenReturn(0);
    when(() => audioPlayer.playing).thenReturn(true);
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

    when(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((invocation) async {
      final path = invocation.positionalArguments[1] as String;
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.filled(1000, 0));
    });

    when(() => storage.isItemFlagged(any())).thenReturn(false);

    final items = customItems ?? [
      LanguageItem(id: 'w1', portuguese: 'Palavra 1', english: 'Word 1'),
      LanguageItem(id: 'w2', portuguese: 'Palavra 2', english: 'Word 2'),
      LanguageItem(id: 'w3', portuguese: 'Palavra 3', english: 'Word 3'),
      LanguageItem(id: 'w4', portuguese: 'Palavra 4', english: 'Word 4'),
      LanguageItem(id: 'w5', portuguese: 'Palavra 5', english: 'Word 5'),
      LanguageItem(id: 'w6', portuguese: 'Palavra 6', english: 'Word 6'),
    ];

    when(() => contentService.loadContent(mode: any(named: 'mode')))
        .thenAnswer((_) async => items);

    final vm = ListenRepeatViewModel(audioPlayer: audioPlayer);
    container = ProviderContainer(
      overrides: [
        listenRepeatViewModelProvider.overrideWith(() => vm),
        storageServiceProvider.overrideWithValue(storage),
        listenRepeatContentServiceProvider.overrideWithValue(contentService),
        ttsServiceProvider.overrideWithValue(ttsService),
        progressServiceProvider.overrideWith(() => progressService),
      ],
    );
  }

  tearDown(() async {
    CarPlayService().resetForTesting();
    await currentIndexController.close();
    await playingController.close();
    container?.dispose();
  });

  ListenRepeatViewModel notifier() =>
      container!.read(listenRepeatViewModelProvider.notifier);

  group('Silence-gated buffer refill and speech shielding (Deterministic controls)', () {
    test('speech source pt1 (index 0) shields synthesis; positive control silence1 (index 1) triggers refill', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      expect(vm.playlistWordsCount, 1);

      // Current index stays at 0 (pt1)
      when(() => audioPlayer.currentIndex).thenReturn(0);
      currentIndexController.add(0);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Negative assertion: pt1 must NOT trigger background refill
      expect(vm.playlistWordsCount, 1);

      // Positive control in same test (C2): advance to silence1 (index 1)
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);

      // Deterministic condition check (C1)
      await _waitForCondition(() => vm.playlistWordsCount == 2 && !vm.isRefilling);
      expect(vm.playlistWordsCount, 2);
    });

    test('speech source pt2 (index 2) shields synthesis when buffer >= 2; positive control silence2 (index 3) triggers refill', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      // Trigger refill on silence1 so buffer has 2 words
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);
      await _waitForCondition(() => vm.playlistWordsCount == 2 && !vm.isRefilling);

      // Advance to pt2 (index 2, speech)
      when(() => audioPlayer.currentIndex).thenReturn(2);
      currentIndexController.add(2);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Negative assertion: pt2 must remain shielded and not grow playlist
      expect(vm.playlistWordsCount, 2);

      // Positive control: advance to silence2 (index 3)
      when(() => audioPlayer.currentIndex).thenReturn(3);
      currentIndexController.add(3);

      await _waitForCondition(() => vm.playlistWordsCount == 3 && !vm.isRefilling);
      expect(vm.playlistWordsCount, 3);
    });

    test('speech source en (index 4) shields synthesis when buffer >= 2; positive control silence3 (index 5) triggers refill', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      // Refill to 3 words
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);
      await _waitForCondition(() => vm.playlistWordsCount == 2 && !vm.isRefilling);

      when(() => audioPlayer.currentIndex).thenReturn(3);
      currentIndexController.add(3);
      await _waitForCondition(() => vm.playlistWordsCount == 3 && !vm.isRefilling);

      // Move to en (index 4, speech) with remaining = 3 - 0 = 3 (>= 2)
      when(() => audioPlayer.currentIndex).thenReturn(4);
      currentIndexController.add(4);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Negative assertion: en must remain shielded
      expect(vm.playlistWordsCount, 3);

      // Positive control: advance to silence3 (index 5)
      when(() => audioPlayer.currentIndex).thenReturn(5);
      currentIndexController.add(5);

      await _waitForCondition(() => vm.playlistWordsCount == 4 && !vm.isRefilling);
      expect(vm.playlistWordsCount, 4);
    });

    test('emergency starvation guard initiates refill if remaining words == 2 at en source (C6)', () async {
      setupContainer(customItems: [
        LanguageItem(id: 'starve_1', portuguese: 'Fome 1', english: 'Hunger 1'),
        LanguageItem(id: 'starve_2', portuguese: 'Fome 2', english: 'Hunger 2'),
        LanguageItem(id: 'starve_3', portuguese: 'Fome 3', english: 'Hunger 3'),
      ]);
      final vm = notifier();
      await vm.startSession();

      expect(vm.playlistWordsCount, 1);

      // Advance to silence1 so exactly 2 words are buffered
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);
      await _waitForCondition(() => vm.playlistWordsCount == 2 && !vm.isRefilling);

      // Now exactly 2 words are in playlist (remainingWords = 2 - 0 = 2).
      // Playback reaches en (index 4, speech).
      // Emergency starvation guard triggers during speech:
      when(() => audioPlayer.currentIndex).thenReturn(4);
      currentIndexController.add(4);

      await _waitForCondition(() => vm.playlistWordsCount == 3 && !vm.isRefilling);
      expect(vm.playlistWordsCount, 3);
    });

    test('post-starvation recovery rebuilds buffer to 2 words and does not loop indefinitely (C5)', () async {
      setupContainer(customItems: [
        LanguageItem(id: 'dry_1', portuguese: 'Seco 1', english: 'Dry 1'),
        LanguageItem(id: 'dry_2', portuguese: 'Seco 2', english: 'Dry 2'),
        LanguageItem(id: 'dry_3', portuguese: 'Seco 3', english: 'Dry 3'),
        LanguageItem(id: 'dry_4', portuguese: 'Seco 4', english: 'Dry 4'),
      ]);
      final vm = notifier();
      await vm.startSession();

      expect(vm.playlistWordsCount, 1);

      // Simulate queue running dry: player completed word 0, currentIndex becomes null
      when(() => audioPlayer.currentIndex).thenReturn(null);
      when(() => audioPlayer.processingState).thenReturn(ProcessingState.completed);
      when(() => audioPlayer.playing).thenReturn(false);

      // Recovery triggers via resume hook
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Starvation recovery must rebuild buffer to 2 words (1 consumed + 2 added = 3 total)
      await _waitForCondition(() => vm.playlistWordsCount == 3 && !vm.isRefilling);
      expect(vm.playlistWordsCount, 3);

      // Ensure it does not continue looping indefinitely (pre-fix bug reached 14+ words)
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(vm.playlistWordsCount, 3);
      expect(vm.isRefilling, isFalse);
    });

    test('didChangeAppLifecycleState(resumed) scopes forceRefill: shields speech when playing, forces when stopped (C3)', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      expect(vm.playlistWordsCount, 1);

      // Case A: Audio is actively playing (e.g. CarPlay background streaming).
      // Playback is at speech index 0 (pt1).
      when(() => audioPlayer.playing).thenReturn(true);
      when(() => audioPlayer.currentIndex).thenReturn(0);

      // Resuming while playing must respect speech shielding and NOT force refill
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(vm.playlistWordsCount, 1);

      // Case B: Audio is stopped/paused (isolate suspended, playback interrupted).
      when(() => audioPlayer.playing).thenReturn(false);
      when(() => audioPlayer.currentIndex).thenReturn(0);

      // Resuming while stopped must bypass the speech gate and refill buffer
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _waitForCondition(() => vm.playlistWordsCount == 2 && !vm.isRefilling);
      expect(vm.playlistWordsCount, 2);
    });

    test('CarPlay single-flight timer debounces and coalesces rapid word skips (C7)', () async {
      final carPlayCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.oguzhnatly.flutter_carplay'),
        (MethodCall call) async {
          carPlayCalls.add(call);
          return true;
        },
      );

      setupContainer(customItems: [
        LanguageItem(id: 'c1', portuguese: 'Carro 1', english: 'Car 1'),
        LanguageItem(id: 'c2', portuguese: 'Carro 2', english: 'Car 2'),
        LanguageItem(id: 'c3', portuguese: 'Carro 3', english: 'Car 3'),
      ]);

      final carPlay = CarPlayService();
      carPlay.init(container: container!, storageService: storage);

      const sceneChannel = MethodChannel('language_trainer/carplay_scene');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        sceneChannel.name,
        sceneChannel.codec.encodeMethodCall(
          const MethodCall('sceneWillEnterForeground'),
        ),
        (ByteData? data) {},
      );

      await _waitForCondition(() => carPlay.playerTemplateForTesting != null);
      expect(carPlay.hasPendingSectionUpdate, isFalse);

      final vm = notifier();
      await vm.startSession();

      // Buffer words 1 and 2 so we have playlist items to skip between
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);
      await _waitForCondition(() => vm.playlistWordsCount == 2 && !vm.isRefilling);

      when(() => audioPlayer.currentIndex).thenReturn(3);
      currentIndexController.add(3);
      await _waitForCondition(() => vm.playlistWordsCount == 3 && !vm.isRefilling);

      // Clear calls from startup / initial buffer fills
      carPlayCalls.clear();
      expect(carPlay.hasPendingSectionUpdate, isFalse);

      // Rapid skip 1: advance to word 1 (totalWordsSeen changes to 2)
      when(() => audioPlayer.currentIndex).thenReturn(6);
      currentIndexController.add(6);

      // Single-flight timer is active
      await _waitForCondition(() => carPlay.hasPendingSectionUpdate);
      expect(carPlay.hasPendingSectionUpdate, isTrue);

      // Rapid skip 2 before 250ms expires: advance to word 2 (totalWordsSeen changes to 3)
      when(() => audioPlayer.currentIndex).thenReturn(12);
      currentIndexController.add(12);

      // Timer was cancelled and rescheduled; still pending
      expect(carPlay.hasPendingSectionUpdate, isTrue);

      // Wait for 250ms debounced timer to complete
      await _waitForCondition(() => !carPlay.hasPendingSectionUpdate);

      // Verify coalescing: only 1 updateListTemplateSections call occurred
      final sectionUpdates = carPlayCalls
          .where((call) => call.method == 'updateListTemplateSections')
          .toList();
      expect(sectionUpdates.length, 1);

      // Verify cleanup: advance again and test resetForTesting()
      when(() => audioPlayer.currentIndex).thenReturn(0);
      currentIndexController.add(0);
      await _waitForCondition(() => carPlay.hasPendingSectionUpdate);

      carPlay.resetForTesting();
      expect(carPlay.hasPendingSectionUpdate, isFalse);
    });
  });
}
