import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:language_trainer/main.dart';
import 'package:language_trainer/services/storage_service.dart';
import 'package:language_trainer/ui/listen_repeat/listen_repeat_view_model.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorageService extends Mock implements StorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('empty vocabulary reports a failure instead of retrying forever', () async {
    final storage = _MockStorageService();
    when(() => storage.getAllItems()).thenReturn([]);
    final container = ProviderContainer(
      overrides: [storageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);

    await container.read(listenRepeatViewModelProvider.notifier).startSession();

    final state = container.read(listenRepeatViewModelProvider);
    expect(state.isPlaying, isFalse);
    expect(state.failure, contains('No vocabulary found'));
    // Bounded retries: the first look plus _maxEmptyLoadAttempts retries, then
    // it gives up rather than looping on a 1s delay forever.
    verify(() => storage.getAllItems()).called(6);
  });
}
