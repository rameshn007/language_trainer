import 'package:flutter_carplay/flutter_carplay.dart';
import 'voice_quiz_service.dart';
import 'tts_service.dart';
import 'quiz_engine_service.dart';
import '../utils/logger.dart';
import 'carplay/carplay_drill_provider.dart';
import 'carplay/vocabulary_flashcard_drill_provider.dart';
import 'storage_service.dart';

class CarPlayService {
  late final VoiceQuizService _voiceService;
  bool _isPlaying = false;

  static final CarPlayService _instance = CarPlayService._internal();
  factory CarPlayService() => _instance;
  CarPlayService._internal();

  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  final QuizEngineService _quizEngine = QuizEngineService();
  TtsService? _ttsService;
  
  final List<CarPlayDrillProvider> _drillProviders = [];

  void init({
    required StorageService storageService,
    required TtsService ttsService,
  }) {
    AppLogger.log("init() called", name: 'CarPlay');
    _ttsService = ttsService;
    _voiceService = VoiceQuizService(ttsService);

    final vocabProvider = VocabularyFlashcardDrillProvider();
    _drillProviders.add(vocabProvider);

    for (var provider in _drillProviders) {
      provider.init(
        storageService: storageService,
        ttsService: ttsService,
        quizEngine: _quizEngine,
      );
    }

    _flutterCarplay.addListenerOnConnectionChange((status) {
      if (status.toString().toLowerCase().contains('connected')) {
        _setupRootTemplate();
      }
    });
  }

  void _setupRootTemplate() {
    try {
      final List<CPListItem> drillItems = _drillProviders.map((p) => CPListItem(
        text: p.displayName,
        detailText: p.description,
        onPress: (complete, setItem) async {
          complete();
          _runDrillSession(p);
        },
      )).toList();

      FlutterCarplay.setRootTemplate(
        rootTemplate: CPListTemplate(
          sections: [
            CPListSection(
              items: drillItems,
              header: 'Available Drills',
            ),
          ],
          title: 'Language Trainer',
          systemIcon: 'house.fill',
        ),
        animated: true,
      );
    } catch (e) {
      AppLogger.error('Error in _setupRootTemplate', name: 'CarPlay', error: e);
    }
  }

  Future<void> _runDrillSession(CarPlayDrillProvider provider) async {
    try {
      _isPlaying = true;
      AppLogger.log('Starting drill session: ${provider.displayName}', name: 'CarPlay');

      DrillChallenge? currentChallenge = await provider.startSession();

      while (_isPlaying && currentChallenge != null && !provider.isFinished) {
        _updateStatusTemplate(
          'Drilling: ${provider.displayName}',
          currentChallenge.promptText,
          replace: true,
          options: currentChallenge.options,
        );

        if (currentChallenge.isVoiceOnly || currentChallenge.options.isEmpty) {
          if (_ttsService != null) await _ttsService!.speak(currentChallenge.promptText);
        }

        String? answer = await _voiceService.listenForAnswer(const Duration(seconds: 10));

        if (answer != null) {
          await provider.processAnswer(answer);
        }
        
        // Check if finished before getting next
        if (provider.isFinished) break;
        
        // Note: We are still using startSession() here because the provider interface
        // currently lacks a nextChallenge() method. This will be improved in a future update.
        currentChallenge = await provider.startSession(); 
      }

      _updateStatusTemplate(
        'Session Finished',
        provider.completionSummary ?? 'Done!',
        replace: true,
      );
        
      if (_ttsService != null) await _ttsService!.speak(provider.completionSummary ?? 'Session complete.');
      await Future.delayed(const Duration(seconds: 5));
      FlutterCarplay.pop();
    } catch (e) {
      AppLogger.error('Error in drill session', name: 'CarPlay', error: e);
      _updateStatusTemplate('Error', 'Session failed.', replace: true);
    } finally {
      _isPlaying = false;
    }
  }

  void _updateStatusTemplate(String title, String detail, {bool replace = true, List<String> options = const []}) {
    if (replace) {
      // Note: FlutterCarplay doesn't always handle pop well if it's the root or already popping
      // Better to use setRoot or handle navigation stack carefully.
      // For now, let's keep it simple or use push.
    }

    final List<CPListItem> allItems = [
      CPListItem(text: title, detailText: detail),
      ...options.map((opt) => CPListItem(text: opt, detailText: '')),
    ];

    FlutterCarplay.push(
      template: CPListTemplate(
        sections: [CPListSection(items: allItems, header: title)],
        title: 'Drill Session',
        systemIcon: 'play.fill',
      ),
      animated: true,
    );
  }
}
