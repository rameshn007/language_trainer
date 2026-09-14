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

  group('Silence-gated buffer refill and speech shielding', () {
    test('speech source pt1 (index 0) does not initiate background refill during word 0', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      // Clear interactions from startup sequence (which generates word 0)
      clearInteractions(ttsService);

      // Current index stays at 0 (pt1)
      when(() => audioPlayer.currentIndex).thenReturn(0);
      currentIndexController.add(0);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // pt1 must NOT trigger background synthesis
      verifyNever(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language')));
    });

    test('silence source silence1 (index 1) initiates refill for subsequent word', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      clearInteractions(ttsService);

      // Audio transitions to silence1 (index 1)
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);

      // Allow background worker to run and append next word
      await Future<void>.delayed(const Duration(milliseconds: 350));

      // silence1 must trigger synthesis for the next buffered word
      verify(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language'))).called(greaterThanOrEqualTo(1));
    });

    test('speech source pt2 (index 2) does not trigger refill when buffer has >= 2 words', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      // Trigger refill on silence1 so buffer has at least 2 words
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      clearInteractions(ttsService);

      // Now move to pt2 (index 2, speech)
      when(() => audioPlayer.currentIndex).thenReturn(2);
      currentIndexController.add(2);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // pt2 must remain clean with zero synthesis activity
      verifyNever(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language')));
    });

    test('speech source en (index 4) does not trigger refill when buffer has >= 2 words', () async {
      setupContainer();
      final vm = notifier();
      await vm.startSession();

      // Trigger refill on silence1
      when(() => audioPlayer.currentIndex).thenReturn(1);
      currentIndexController.add(1);
      await Future<void>.delayed(const Duration(milliseconds: 350));

      clearInteractions(ttsService);

      // Move to en (index 4, speech)
      when(() => audioPlayer.currentIndex).thenReturn(4);
      currentIndexController.add(4);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // en must remain clean with zero synthesis activity
      verifyNever(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language')));
    });

    test('emergency starvation guard initiates refill if remaining words <= 1 at en source', () async {
      setupContainer(customItems: [
        LanguageItem(id: 'starve_1', portuguese: 'Fome 1', english: 'Hunger 1'),
        LanguageItem(id: 'starve_2', portuguese: 'Fome 2', english: 'Hunger 2'),
      ]);
      final vm = notifier();
      await vm.startSession();

      clearInteractions(ttsService);

      // Only word 0 is in playlist (remaining = 1 - 0 = 1 <= 1). Audio reaches en (index 4)
      when(() => audioPlayer.currentIndex).thenReturn(4);
      currentIndexController.add(4);

      await Future<void>.delayed(const Duration(milliseconds: 350));

      // Emergency starvation guard should trigger synthesis to prevent queue from running out
      verify(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language'))).called(greaterThanOrEqualTo(1));
    });
  });
}
