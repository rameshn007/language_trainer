import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage_service.dart';
import 'services/tts_service.dart';
import 'services/carplay_service.dart';
import 'ui/home_screen.dart';
import 'utils/logger.dart';

// Global provider for storage service
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Global provider for TTS service
final ttsServiceProvider = Provider<TtsService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return TtsService(storage);
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.init();

  final ttsService = TtsService(storageService);

  // CarPlay initialization moved to HomeScreen
  // CarPlayService().init();
  AppLogger.log("main() started", name: 'Main');
  CarPlayService().init(storageService: storageService, ttsService: ttsService);

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        ttsServiceProvider.overrideWithValue(ttsService),
      ],
      child: const LanguageTrainerApp(),
    ),
  );
}

class LanguageTrainerApp extends StatelessWidget {
  const LanguageTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Language Trainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
