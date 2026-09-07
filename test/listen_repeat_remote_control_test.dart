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

    tempDir = await Directory.systemTemp.createTemp('lr_remote_test');
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
  ProviderContainer? container;

  void setupContainer({List<LanguageItem>? customItems}) {
    audioPlayer = _MockAudioPlayer();
    storage = _MockStorageService();
    contentService = _MockContentService();
    ttsService = _MockTtsService();
    progressService = _MockProgressService();

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

    when(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((invocation) async {
      final path = invocation.positionalArguments[1] as String;
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.filled(1000, 0));
    });

    final items = customItems ?? [
      LanguageItem(id: 'w1', portuguese: 'Palavra 1', english: 'Word 1'),
      LanguageItem(id: 'w2', portuguese: 'Palavra 2', english: 'Word 2'),
      LanguageItem(id: 'w3', portuguese: 'Palavra 3', english: 'Word 3'),
      LanguageItem(id: 'w4', portuguese: 'Palavra 4', english: 'Word 4'),
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

  tearDown(() {
    CarPlayService().resetForTesting();
    container?.dispose();
  });

  ListenRepeatViewModel notifier() =>
      container!.read(listenRepeatViewModelProvider.notifier);

  group('Word skip controls (Fixing 5-source glitch)', () {
    test('nextWord seeks by exactly 5 audio sources (1 full word) and resumes play', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      // Clear any setup calls to seek / play
      clearInteractions(audioPlayer);

      // Current source index 0 (word 0, PT)
      when(() => audioPlayer.currentIndex).thenReturn(0);

      await vm.nextWord();

      // Must seek to index 5 (word 1, PT), NOT index 1 (silence1)
      verify(() => audioPlayer.seek(Duration.zero, index: 5)).called(1);
      verify(() => audioPlayer.play()).called(1);
    });

    test('nextWord from mid-word silence source advances to start of next word (PT)', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      clearInteractions(audioPlayer);

      // Suppose user is listening to silence chunk 2 of word 0 (source index 2)
      when(() => audioPlayer.currentIndex).thenReturn(2);

      await vm.nextWord();

      // 2 ~/ 5 = 0, so next word index is 1 -> seek to 5
      verify(() => audioPlayer.seek(Duration.zero, index: 5)).called(1);
      verify(() => audioPlayer.play()).called(1);
    });

    test('previousWord seeks back by exactly 5 audio sources (1 full word) and resumes play', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      clearInteractions(audioPlayer);

      // Current source index is in word 2 (source index 10)
      when(() => audioPlayer.currentIndex).thenReturn(10);

      await vm.previousWord();

      // Must seek to index 5 (word 1, PT)
      verify(() => audioPlayer.seek(Duration.zero, index: 5)).called(1);
      verify(() => audioPlayer.play()).called(1);
    });

    test('previousWord from mid-word in word 2 seeks to word 1 start', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      clearInteractions(audioPlayer);

      // Current source index is in word 2 English prompt (source index 13: 13 ~/ 5 = 2)
      when(() => audioPlayer.currentIndex).thenReturn(13);

      await vm.previousWord();

      // Must seek to (2 - 1) * 5 = 5
      verify(() => audioPlayer.seek(Duration.zero, index: 5)).called(1);
      verify(() => audioPlayer.play()).called(1);
    });

    test('previousWord at word 0 replays current word from start (index 0)', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      clearInteractions(audioPlayer);

      // Current index is at source 3 (word 0, EN)
      when(() => audioPlayer.currentIndex).thenReturn(3);

      await vm.previousWord();

      // At word 0, previousWord replays current word from index 0
      verify(() => audioPlayer.seek(Duration.zero, index: 0)).called(1);
      verify(() => audioPlayer.play()).called(1);
    });

    test('nextWord does not seek if session is stopped or inactive', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();
      await vm.stopSession();

      clearInteractions(audioPlayer);

      await vm.nextWord();

      verifyNever(() => audioPlayer.seek(any(), index: any(named: 'index')));
    });
  });

  group('CarPlayService remote command channel & debounce', () {
    const sceneChannel = MethodChannel('language_trainer/carplay_scene');

    test('remoteNextWord and remotePreviousWord invoke ViewModel methods via channel', () async {
      setupContainer();
      final carPlayService = CarPlayService();
      carPlayService.resetForTesting();
      carPlayService.init(container: container!);

      final vm = notifier();
      await vm.startSession();

      clearInteractions(audioPlayer);
      when(() => audioPlayer.currentIndex).thenReturn(0);

      // Simulate native channel sending remoteNextWord
      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      await binding.handlePlatformMessage(
        sceneChannel.name,
        sceneChannel.codec.encodeMethodCall(const MethodCall('remoteNextWord')),
        (_) {},
      );

      verify(() => audioPlayer.seek(Duration.zero, index: 5)).called(1);
    });

    test('rapid remote calls within debounce window are discarded', () async {
      setupContainer();
      final carPlayService = CarPlayService();
      carPlayService.resetForTesting();
      carPlayService.init(container: container!);

      final vm = notifier();
      await vm.startSession();

      clearInteractions(audioPlayer);
      when(() => audioPlayer.currentIndex).thenReturn(0);

      final binding = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      // Fire two remoteNextWord calls in rapid succession (simulating hardware switch bounce)
      await binding.handlePlatformMessage(
        sceneChannel.name,
        sceneChannel.codec.encodeMethodCall(const MethodCall('remoteNextWord')),
        (_) {},
      );
      await binding.handlePlatformMessage(
        sceneChannel.name,
        sceneChannel.codec.encodeMethodCall(const MethodCall('remoteNextWord')),
        (_) {},
      );

      // Should only have executed once due to 300ms debounce
      verify(() => audioPlayer.seek(Duration.zero, index: 5)).called(1);
    });
  });
}
