import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/models/progress_data.dart';
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

    tempDir = await Directory.systemTemp.createTemp('lr_mode_test');
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

  void setupContainer() {
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

    when(() => ttsService.synthesizeToFile(any(), any(), language: any(named: 'language'))).thenAnswer((invocation) async {
      final path = invocation.positionalArguments[1] as String;
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(List.filled(1000, 0));
    });

    when(() => contentService.loadContent(mode: any(named: 'mode')))
        .thenAnswer((invocation) async {
      final mode = invocation.namedArguments[#mode] as ListenRepeatMode;
      return [
        LanguageItem(
          id: '${mode.name}_1',
          portuguese: '${mode.name} PT',
          english: '${mode.name} EN',
        ),
      ];
    });

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

  ListenRepeatState state() =>
      container!.read(listenRepeatViewModelProvider);

  ListenRepeatViewModel notifier() =>
      container!.read(listenRepeatViewModelProvider.notifier);

  tearDown(() => container?.dispose());

  test('default mode is ListenRepeatMode.all', () {
    setupContainer();
    expect(state().mode, equals(ListenRepeatMode.all));
  });

  test('cycleMode cycles sequentially through all modes, rebuilds deck and starts playback', () async {
    setupContainer();
    final vm = notifier();

    expect(state().mode, equals(ListenRepeatMode.all));

    // all -> verbs
    final mode1 = await vm.cycleMode();
    expect(mode1, equals(ListenRepeatMode.verbs));
    expect(state().mode, equals(ListenRepeatMode.verbs));
    expect(state().pool.first.id, equals('verbs_1'));
    expect(state().isPlaying, isTrue);
    verify(() => contentService.loadContent(mode: ListenRepeatMode.verbs)).called(1);

    // verbs -> prepositions
    final mode2 = await vm.cycleMode();
    expect(mode2, equals(ListenRepeatMode.prepositions));
    expect(state().mode, equals(ListenRepeatMode.prepositions));
    expect(state().pool.first.id, equals('prepositions_1'));
    expect(state().isPlaying, isTrue);
    verify(() => contentService.loadContent(mode: ListenRepeatMode.prepositions)).called(1);

    // prepositions -> phrases
    final mode3 = await vm.cycleMode();
    expect(mode3, equals(ListenRepeatMode.phrases));
    expect(state().mode, equals(ListenRepeatMode.phrases));
    expect(state().pool.first.id, equals('phrases_1'));
    expect(state().isPlaying, isTrue);
    verify(() => contentService.loadContent(mode: ListenRepeatMode.phrases)).called(1);

    // phrases -> vocabulary
    final mode4 = await vm.cycleMode();
    expect(mode4, equals(ListenRepeatMode.vocabulary));
    expect(state().mode, equals(ListenRepeatMode.vocabulary));
    expect(state().pool.first.id, equals('vocabulary_1'));
    expect(state().isPlaying, isTrue);
    verify(() => contentService.loadContent(mode: ListenRepeatMode.vocabulary)).called(1);

    // vocabulary -> all
    final mode5 = await vm.cycleMode();
    expect(mode5, equals(ListenRepeatMode.all));
    expect(state().mode, equals(ListenRepeatMode.all));
    expect(state().pool.first.id, equals('all_1'));
    expect(state().isPlaying, isTrue);
    verify(() => contentService.loadContent(mode: ListenRepeatMode.all)).called(1);
  });

  test('setMode directly rebuilds deck and starts playback for specified mode', () async {
    setupContainer();
    final vm = notifier();

    await vm.setMode(ListenRepeatMode.prepositions);
    expect(state().mode, equals(ListenRepeatMode.prepositions));
    expect(state().pool.first.id, equals('prepositions_1'));
    expect(state().isPlaying, isTrue);
    verify(() => contentService.loadContent(mode: ListenRepeatMode.prepositions)).called(1);

    await vm.setMode(ListenRepeatMode.phrases);
    expect(state().mode, equals(ListenRepeatMode.phrases));
    expect(state().pool.first.id, equals('phrases_1'));
    expect(state().isPlaying, isTrue);
    verify(() => contentService.loadContent(mode: ListenRepeatMode.phrases)).called(1);
  });

  test('mode switching does not record completed sessions or award premature XP', () async {
    setupContainer();
    final vm = notifier();

    // Rapid cycling through several modes
    await vm.setMode(ListenRepeatMode.verbs);
    await vm.cycleMode();
    await vm.cycleMode();

    // Mode switching must NOT invoke recordSessionComplete
    verifyNever(() => progressService.recordSessionComplete(
          storage: any(named: 'storage'),
          activityType: any(named: 'activityType'),
          score: any(named: 'score'),
          total: any(named: 'total'),
          sessionXP: any(named: 'sessionXP'),
        ));

    // Only explicit stopSession settles progress
    when(() => progressService.recordSessionComplete(
          storage: any(named: 'storage'),
          activityType: any(named: 'activityType'),
          score: any(named: 'score'),
          total: any(named: 'total'),
          sessionXP: any(named: 'sessionXP'),
        )).thenAnswer((_) async => 10);

    await vm.stopSession();
    // Explicit stopSession settles progress once for the entire session with all accumulated words
    verify(() => progressService.recordSessionComplete(
          storage: any(named: 'storage'),
          activityType: ActivityType.listenRepeat,
          score: 3,
          total: 3,
          durationSeconds: any(named: 'durationSeconds'),
          sessionXP: 6,
        )).called(1);
  });

  test('preserves totalWordsSeen across mode switches', () async {
    setupContainer();
    final vm = notifier();

    await vm.setMode(ListenRepeatMode.verbs);
    // Simulate words seen
    container!.read(listenRepeatViewModelProvider.notifier).state =
        state().copyWith(totalWordsSeen: 5);
    expect(state().totalWordsSeen, equals(5));

    // Switch mode
    await vm.setMode(ListenRepeatMode.phrases);
    expect(state().mode, equals(ListenRepeatMode.phrases));
    // 5 words previously seen + 1st phrase now playing = 6
    expect(state().totalWordsSeen, equals(6));
  });

  test('switching mode while a start is in flight aborts previous attempt cleanly', () async {
    setupContainer();
    final vm = notifier();

    // Fire first mode switch (verbs) and immediately switch to phrases
    final first = vm.startSession(mode: ListenRepeatMode.verbs);
    final second = vm.setMode(ListenRepeatMode.phrases);

    await Future.wait([first, second]);

    expect(state().mode, equals(ListenRepeatMode.phrases));
    expect(state().pool.first.id, equals('phrases_1'));
    expect(state().isPlaying, isTrue);
  });
}
