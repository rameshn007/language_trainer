import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockStorageService storage;
  ProviderContainer? container;

  /// Container whose vocabulary reads always return [items].
  void containerWith(List<LanguageItem> items) {
    storage = _MockStorageService();
    when(() => storage.getAllItems()).thenReturn(items);
    container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
  }

  void containerThatThrows() {
    storage = _MockStorageService();
    when(() => storage.getAllItems()).thenThrow(Exception('box not open'));
    container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
  }

  ListenRepeatState state() =>
      container!.read(listenRepeatViewModelProvider);

  ListenRepeatViewModel notifier() =>
      container!.read(listenRepeatViewModelProvider.notifier);

  tearDown(() => container?.dispose());

  test('empty vocabulary stays a normal empty state, not an error', () async {
    containerWith([]);

    await notifier().startSession();

    // Nothing is broken here, so no failure banner: the screen keeps its
    // "add vocabulary" empty state.
    expect(state().isPlaying, isFalse);
    expect(state().failure, isNull);
    // Bounded retries: first look plus _maxEmptyLoadAttempts retries.
    verify(() => storage.getAllItems()).called(6);
  });

  test('a storage failure surfaces as a failure, not an empty library', () async {
    containerThatThrows();

    await notifier().startSession();

    expect(state().isPlaying, isFalse);
    expect(state().failure, contains('Session could not start'));
    expect(state().failure, contains('box not open'));
  });

  test('a second start attempt cannot run alongside the first', () async {
    containerWith([]);

    // The Try again button and shufflePool() both fire without awaiting.
    await Future.wait([notifier().startSession(), notifier().startSession()]);

    // One attempt, not two: the retry budget is spent once.
    verify(() => storage.getAllItems()).called(6);
  });

  test('backing out mid-load aborts the attempt instead of carrying on', () async {
    containerWith([]);
    final vm = notifier();

    final inFlight = vm.startSession();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // What ListenRepeatScreen.dispose() does on pop.
    await vm.stopSession();
    await inFlight;

    expect(state().isPlaying, isFalse);
    expect(state().failure, isNull);
    // Aborted during the first wait rather than spending the whole budget.
    verify(() => storage.getAllItems()).called(1);
  });
}
