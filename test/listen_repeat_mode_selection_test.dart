import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/models/language_item.dart';
import 'package:language_trainer/services/listen_repeat_content_service.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockStorageService storage;
  ProviderContainer? container;

  void setupContainer(List<LanguageItem> items) {
    storage = _MockStorageService();
    when(() => storage.getAllItems()).thenReturn(items);
    container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
  }

  ListenRepeatState state() =>
      container!.read(listenRepeatViewModelProvider);

  ListenRepeatViewModel notifier() =>
      container!.read(listenRepeatViewModelProvider.notifier);

  tearDown(() => container?.dispose());

  test('default mode is ListenRepeatMode.all', () {
    setupContainer([]);
    expect(state().mode, equals(ListenRepeatMode.all));
  });

  test('cycleMode cycles sequentially through all modes and loops back', () {
    setupContainer([]);
    final vm = notifier();

    expect(state().mode, equals(ListenRepeatMode.all));

    final mode1 = vm.cycleMode();
    expect(mode1, equals(ListenRepeatMode.verbs));
    expect(state().mode, equals(ListenRepeatMode.verbs));

    final mode2 = vm.cycleMode();
    expect(mode2, equals(ListenRepeatMode.prepositions));
    expect(state().mode, equals(ListenRepeatMode.prepositions));

    final mode3 = vm.cycleMode();
    expect(mode3, equals(ListenRepeatMode.phrases));
    expect(state().mode, equals(ListenRepeatMode.phrases));

    final mode4 = vm.cycleMode();
    expect(mode4, equals(ListenRepeatMode.vocabulary));
    expect(state().mode, equals(ListenRepeatMode.vocabulary));

    final mode5 = vm.cycleMode();
    expect(mode5, equals(ListenRepeatMode.all));
    expect(state().mode, equals(ListenRepeatMode.all));
  });

  test('setMode directly sets the specified mode', () {
    setupContainer([]);
    final vm = notifier();

    vm.setMode(ListenRepeatMode.prepositions);
    expect(state().mode, equals(ListenRepeatMode.prepositions));

    vm.setMode(ListenRepeatMode.phrases);
    expect(state().mode, equals(ListenRepeatMode.phrases));
  });
}
