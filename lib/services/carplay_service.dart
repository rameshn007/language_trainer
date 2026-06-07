import 'package:flutter_carplay/flutter_carplay.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'voice_quiz_service.dart';
import 'tts_service.dart';
import 'quiz_engine_service.dart';
import '../models/progress_data.dart';
import '../utils/logger.dart';
import 'carplay/carplay_drill_provider.dart';
import 'carplay/vocabulary_flashcard_drill_provider.dart';
import 'carplay/quiz_drill_provider.dart';
import 'carplay/verb_drill_provider.dart';
import 'carplay/phrase_drill_provider.dart';
import 'carplay/interrogative_drill_provider.dart';
import 'storage_service.dart';

// Static connection state accessible without a Riverpod ref
bool _carplayConnected = false;
bool get isCarplayConnected => _carplayConnected;

// Provider for CarPlay connection status
final carplayConnectionProvider = StateNotifierProvider<CarPlayConnectionNotifier, bool>((ref) {
  return CarPlayConnectionNotifier();
});

class CarPlayConnectionNotifier extends StateNotifier<bool> {
  CarPlayConnectionNotifier() : super(false);

  void setConnected(bool value) {
    _carplayConnected = value;
    state = value;
  }
}

final carplayConnectionNotifier = CarPlayConnectionNotifier();

class CarPlayService {
  late final VoiceQuizService _voiceService;
  late final QuizDrillProvider _quizProvider;
  late final VerbConjugationDrillProvider _verbProvider;
  late final PhraseTrainerDrillProvider _phraseProvider;
  late final InterrogativeDrillProvider _interrogativeProvider;
  bool _isPlaying = false;
  bool _hasSetRoot = false;
  
  // Session state for resume
  String? _sessionProviderId;
  int? _sessioncurrentIndex;
  int? _sessionScore;
  int? _sessionTotal;
  Set<String>? _sessionSeenIds;

  static final CarPlayService _instance = CarPlayService._internal();
  factory CarPlayService() => _instance;
  CarPlayService._internal();

  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  final QuizEngineService _quizEngine = QuizEngineService();
  TtsService? _ttsService;
  StorageService? _storageService;
  
  final List<CarPlayDrillProvider> _drillProviders = [];
  bool _isCarplayConnected = false;

  void init({
    required StorageService storageService,
    required TtsService ttsService,
  }) {
    AppLogger.log("init() called", name: 'CarPlay');
    _storageService = storageService;
    _ttsService = ttsService;
    _voiceService = VoiceQuizService(ttsService);

    // Initialize all providers
    _quizProvider = QuizDrillProvider();
    _verbProvider = VerbConjugationDrillProvider();
    _phraseProvider = PhraseTrainerDrillProvider();
    _interrogativeProvider = InterrogativeDrillProvider();
    
    _drillProviders.add(_quizProvider);
    _drillProviders.add(_verbProvider);
    _drillProviders.add(_phraseProvider);
    _drillProviders.add(_interrogativeProvider);
    _drillProviders.add(VocabularyFlashcardDrillProvider());

    for (var provider in _drillProviders) {
      provider.init(
        storageService: storageService,
        ttsService: ttsService,
        quizEngine: _quizEngine,
      );
    }

    // Setup CarPlay connection listener
    _setupConnectionListener();
    
    // Check if CarPlay is already connected
    _checkConnectionStatus();
  }

  void _setupConnectionListener() {
    _flutterCarplay.addListenerOnConnectionChange((status) {
      final isConnected = status.toString().toLowerCase().contains('connected');
      AppLogger.log("CarPlay connection status: $status", name: 'CarPlay');
      carplayConnectionNotifier.setConnected(isConnected);
      
      if (isConnected) {
        _isCarplayConnected = true;
        _checkForResume();
      } else {
        _isCarplayConnected = false;
        // Save session state if a session was in progress
        _saveSessionState();
      }
    });
  }

  void _checkConnectionStatus() {
    // This is a placeholder - in practice, flutter_carplay might provide a way to check current status
    // For now, we'll assume not connected until we receive a connection event
    _isCarplayConnected = false;
  }

  void _checkForResume() {
    // Load any saved session state from previous connection
    _loadSessionState();
    
    // Always show root template on connect
    _setupRootTemplate();
  }

  void _saveSessionState() {
    // Save session state to settings for resume
    if (_sessionProviderId != null) {
      _storageService?.saveSetting('carplay_session_provider', _sessionProviderId);
      _storageService?.saveSetting('carplay_session_index', _sessioncurrentIndex);
      _storageService?.saveSetting('carplay_session_score', _sessionScore);
      _storageService?.saveSetting('carplay_session_total', _sessionTotal);
      _storageService?.saveSetting('carplay_session_seen_ids', jsonEncode(_sessionSeenIds?.toList() ?? []));
      AppLogger.log("Session state saved for resume", name: 'CarPlay');
    }
  }

  void _loadSessionState() {
    // Load session state from settings
    _sessionProviderId = _storageService?.getSetting('carplay_session_provider');
    _sessioncurrentIndex = _storageService?.getSetting('carplay_session_index');
    _sessionScore = _storageService?.getSetting('carplay_session_score');
    _sessionTotal = _storageService?.getSetting('carplay_session_total');
    
    final seenIdsJson = _storageService?.getSetting('carplay_session_seen_ids');
    if (seenIdsJson != null) {
      try {
        final List<dynamic> list = jsonDecode(seenIdsJson);
        _sessionSeenIds = Set<String>.from(list.whereType<String>());
      } catch (e) {
        AppLogger.error("Error loading session state: $e", name: 'CarPlay');
      }
    }
    
    AppLogger.log("Loaded session state: provider=$_sessionProviderId, index=$_sessioncurrentIndex", name: 'CarPlay');
  }

  void clearSessionState() {
    _sessionProviderId = null;
    _sessioncurrentIndex = null;
    _sessionScore = null;
    _sessionTotal = null;
    _sessionSeenIds = null;
    // Clear saved state
    _storageService?.saveSetting('carplay_session_provider', null);
    _storageService?.saveSetting('carplay_session_index', null);
    _storageService?.saveSetting('carplay_session_score', null);
    _storageService?.saveSetting('carplay_session_total', null);
    _storageService?.saveSetting('carplay_session_seen_ids', null);
  }

  int _pushedTemplateCount = 0;
  bool get isConnected => _isCarplayConnected;

  void _setupRootTemplate() {
    try {
      if (_hasSetRoot) {
        // If root is already set, just return (root template is already displayed)
        return;
      }
      
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
      _hasSetRoot = true;
    } catch (e) {
      AppLogger.error('Error in _setupRootTemplate', name: 'CarPlay', error: e);
    }
  }

  Future<void> _runDrillSession(CarPlayDrillProvider provider) async {
    try {
      // Load any saved session state
      _loadSessionState();
      
      _isPlaying = true;
      AppLogger.log('Starting drill session: ${provider.displayName}', name: 'CarPlay');
      
      // Save current session info
      _sessionProviderId = provider.displayName;
      _sessioncurrentIndex = 0;
      _sessionScore = 0;
      _sessionTotal = 0;

      DrillChallenge? currentChallenge = await provider.startSession();

      if (currentChallenge == null) {
        AppLogger.log('No challenges available', name: 'CarPlay');
        await _pushDrillTemplate('No Challenges', 'No questions available for this drill.', options: ['Back']);
        await Future.delayed(const Duration(seconds: 3));
        _popToRoot();
        return;
      }

      while (_isPlaying && currentChallenge != null && !provider.isFinished) {
        _sessioncurrentIndex = _sessioncurrentIndex ?? 0;
        _sessionTotal = (_sessionTotal ?? 0) + 1;
        
        await _pushDrillTemplate(
          'Drilling: ${provider.displayName}',
          currentChallenge.promptText,
          options: currentChallenge.options,
        );

        if (currentChallenge.isVoiceOnly || currentChallenge.options.isEmpty) {
          if (_ttsService != null) await _ttsService!.speak(currentChallenge.promptText);
        }

        String? answer = await _voiceService.listenForAnswer(const Duration(seconds: 10));

        if (answer != null) {
          final isCorrect = await provider.processAnswer(answer);
          if (isCorrect) {
            _sessionScore = (_sessionScore ?? 0) + 1;
          }
        }
        
        // Check if finished before getting next
        if (provider.isFinished) break;
        
        currentChallenge = provider.nextChallenge(); 
      }

      // Record session complete with XP
      final storage = _storageService!;
      
      if (_sessionScore != null && _sessionTotal != null) {
        // Award completion bonus
        await storage.addXP(20);
        await storage.incrementDailySessions();
        
        // Record session
        await storage.saveSession(SessionRecord(
          timestamp: DateTime.now(),
          activityType: ActivityType.quiz,
          score: _sessionScore ?? 0,
          total: _sessionTotal ?? 0,
          xpEarned: 20, // completion bonus
          durationSeconds: 0, // TODO: track duration
        ));
      }
      
      // Show score summary
      final score = _sessionScore ?? 0;
      final total = _sessionTotal ?? 0;
      await _pushDrillTemplate(
        'Score: $score/$total',
        provider.completionSummary ?? 'Great job!',
        options: ['Back to Menu'],
      );
        
      if (_ttsService != null) await _ttsService!.speak(provider.completionSummary ?? 'Session complete. You got $score out of $total correct.');
      await Future.delayed(const Duration(seconds: 5));
      
      // Clear session state
      clearSessionState();
    } catch (e) {
      AppLogger.error('Error in drill session', name: 'CarPlay', error: e);
      // Clear session state on error
      clearSessionState();
    } finally {
      _isPlaying = false;
      // Pop back to root
      _popToRoot();
    }
  }

  Future<void> _pushDrillTemplate(String title, String detail, {List<String> options = const []}) async {
    try {
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
      _pushedTemplateCount++;
    } catch (e) {
      AppLogger.error('Error pushing template', name: 'CarPlay', error: e);
    }
  }

  void _popToRoot() {
    try {
      while (_pushedTemplateCount > 0) {
        FlutterCarplay.pop(animated: false);
        _pushedTemplateCount--;
      }
    } catch (e) {
      AppLogger.error('Error popping to root', name: 'CarPlay', error: e);
      _pushedTemplateCount = 0;
    }
  }
}
