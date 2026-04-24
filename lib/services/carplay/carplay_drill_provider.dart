import '../../services/storage_service.dart';
import '../../services/tts_service.dart';
import '../../services/quiz_engine_service.dart';

abstract class CarPlayDrillProvider {
  String get displayName;
  String get description;

  Future<void> init({
    required StorageService storageService,
    required TtsService ttsService,
    required QuizEngineService quizEngine,
  });

  Future<DrillChallenge?> startSession();
  DrillChallenge? nextChallenge();

  Future<bool> processAnswer(String answer);

  String? get completionSummary;

  bool get isFinished;
}

class DrillChallenge {
  final String promptText;
  final String? detailText;
  final List<String> options;
  final bool isVoiceOnly;

  DrillChallenge({
    required this.promptText,
    this.detailText,
    this.options = const [],
    this.isVoiceOnly = false,
  });
}
