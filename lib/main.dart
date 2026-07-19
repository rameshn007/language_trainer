import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage_service.dart';
import 'services/tts_service.dart';
import 'services/carplay_service.dart';
import 'services/notification_service.dart';
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

// Global navigator key for deep linking from notifications
final navigatorKey = GlobalKey<NavigatorState>();

// Global provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationService(storage);
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.example.language_trainer.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  final storageService = StorageService();
  await storageService.init();

  final ttsService = TtsService(storageService);
  final notificationService = NotificationService(storageService);

  final container = ProviderContainer(
    overrides: [
      storageServiceProvider.overrideWithValue(storageService),
      ttsServiceProvider.overrideWithValue(ttsService),
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );

  AppLogger.log("main() started", name: 'Main');
  CarPlayService().init(container: container);
  try {
    await notificationService.init();
  } catch (e) {
    AppLogger.log(
      "Failed to initialize notification service: $e",
      name: 'Main',
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LanguageTrainerApp(),
    ),
  );
}

class LanguageTrainerApp extends StatelessWidget {
  const LanguageTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
