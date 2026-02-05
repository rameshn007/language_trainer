import 'package:flutter_carplay/flutter_carplay.dart';
import 'voice_quiz_service.dart';
import '../models/question.dart';
import '../models/language_item.dart';
import 'storage_service.dart';
import 'quiz_engine_service.dart';
import '../utils/logger.dart';

class CarPlayService {
  final VoiceQuizService _voiceService = VoiceQuizService();
  bool _isPlaying = false;

  // Singleton pattern
  static final CarPlayService _instance = CarPlayService._internal();
  factory CarPlayService() => _instance;
  CarPlayService._internal();

  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  final QuizEngineService _quizEngine = QuizEngineService();
  late CPListItem _startQuizItem;
  StorageService? _storageService;

  /// Initialise CarPlay
  void init({StorageService? storageService}) {
    AppLogger.log("init() called", name: 'CarPlay');
    _storageService = storageService;

    _startQuizItem = CPListItem(
      text: "Start Voice Quiz",
      detailText: "Practice Portuguese hands-free",
      image: "assets/images/app_icon.png",
      onPress: (complete, setItem) {
        AppLogger.log("'Start Voice Quiz' pressed", name: 'CarPlay');
        complete();
        Future.delayed(const Duration(milliseconds: 200), () {
          _startCarPlayQuiz();
        });
      },
    );

    _flutterCarplay.addListenerOnConnectionChange((status) {
      AppLogger.log("Connection Status Changed: $status", name: 'CarPlay');
      // Check if status name contains 'connected' (case insensitive just to be safe)
      if (status.toString().toLowerCase().contains("connected")) {
        _setupRootTemplate();
      }
    });
  }

  void _setupRootTemplate() {
    AppLogger.log("Setting up root template", name: 'CarPlay');
    try {
      FlutterCarplay.setRootTemplate(
        rootTemplate: CPListTemplate(
          sections: [
            CPListSection(items: [_startQuizItem], header: "Language Trainer"),
          ],
          title: "Language Trainer",
          systemIcon: "house.fill", // Required by some versions
        ),
        animated: true,
      );
      AppLogger.log("setRootTemplate called", name: 'CarPlay');
    } catch (e) {
      AppLogger.error("Error in _setupRootTemplate", name: 'CarPlay', error: e);
    }
  }

  void _startCarPlayQuiz() async {
    AppLogger.log("_startCarPlayQuiz called", name: 'CarPlay');
    try {
      // 1. Loading/Starting
      // REMOVED: _updateStatusTemplate("Starting Quiz...", ...)
      // We will go straight to Q1 after fetching.
      AppLogger.log("Fetching questions...", name: 'CarPlay');

      // 2. Initialize Voice Service
      AppLogger.log("Initializing VoiceService...", name: 'CarPlay');
      await _voiceService.init();
      AppLogger.log("VoiceService initialized", name: 'CarPlay');

      // 3. Fetch Questions
      AppLogger.log("Fetching questions...", name: 'CarPlay');
      List<Question> questions = await _fetchQuestions();
      AppLogger.log("Fetched ${questions.length} questions", name: 'CarPlay');

      if (questions.isEmpty) {
        if (questions.isEmpty) {
          _updateStatusTemplate(
            "Error",
            "No questions available.",
            replace: true,
          );
          await _voiceService.speakFeedback(false); // Make it speak error
          return;
        }
      }

      AppLogger.log("Starting quiz loop...", name: 'CarPlay');
      await _runQuizLoop(questions);
      AppLogger.log("Quiz loop finished", name: 'CarPlay');
    } catch (e, stack) {
      AppLogger.error(
        "Error starting quiz",
        name: 'CarPlay',
        error: e,
        stackTrace: stack,
      );
      _updateStatusTemplate("Error", "Could not start quiz: $e", replace: true);
    }
  }

  Future<List<Question>> _fetchQuestions() async {
    // If no storage service available, return empty or mock
    if (_storageService == null) {
      AppLogger.log("Storage not initialized!", name: 'CarPlay');
      return _mockFallbackQuestions();
    }

    final items = _storageService!.getAllItems();
    if (items.isEmpty) {
      AppLogger.log("No items in storage.", name: 'CarPlay');
      return _mockFallbackQuestions();
    }

    // Generate quiz (randomized by default in service)
    return _quizEngine.generateQuiz(items, count: 5);
  }

  List<Question> _mockFallbackQuestions() {
    return [
      Question(
        id: "1",
        questionText: "How do you say 'Hello'?",
        options: ["Ola", "Adeus", "Obrigado", "Sim"],
        correctAnswer: "Ola",
        type: QuestionType.multipleChoice,
        sourceItem: LanguageItem.empty(),
      ),
    ];
  }

  // Revised method signature
  void _updateStatusTemplate(
    String title,
    String detail, {
    bool replace = true,
    List<String> options = const [],
  }) {
    if (replace) {
      FlutterCarplay.pop(animated: false);
    }

    // Main status item
    final headerItem = CPListItem(
      text: title,
      detailText: detail,
      image:
          "assets/images/app_icon.png", // Re-use icon or remove if unnecessary
    );

    List<CPListItem> allItems = [headerItem];

    // Options (if any)
    if (options.isNotEmpty) {
      // Create a section for options? Or just add them.
      // Let's add them as items.
      for (var opt in options) {
        allItems.add(
          CPListItem(
            text: opt,
            detailText: "", // Option text
          ),
        );
      }
    }

    // Stop Button
    final stopItem = CPListItem(
      text: "Stop Quiz",
      detailText: "End current session",
      image: "assets/images/app_icon.png", // Or a stop icon if available
      onPress: (complete, setItem) {
        AppLogger.log("Stop Quiz pressed", name: 'CarPlay');
        _isPlaying = false;
        _voiceService.stop();
        complete();
        FlutterCarplay.pop(animated: true);
      },
    );
    allItems.add(stopItem);

    FlutterCarplay.push(
      template: CPListTemplate(
        sections: [
          CPListSection(
            items: allItems,
            header: title, // Use title as section header too
          ),
        ],
        title: "Quiz",
        systemIcon: "play.fill",
      ),
      animated: true,
    );
  }

  // The main loop
  Future<void> _runQuizLoop(List<Question> questions) async {
    AppLogger.log(
      "_runQuizLoop started with ${questions.length} questions",
      name: 'CarPlay',
    );
    _isPlaying = true;

    int score = 0;

    for (var i = 0; i < questions.length; i++) {
      AppLogger.log("Loop iteration $i", name: 'CarPlay');
      if (!_isPlaying) {
        AppLogger.log("Quiz stopped (isPlaying=false)", name: 'CarPlay');
        break;
      }

      final q = questions[i];

      // Update UI
      // Update UI
      AppLogger.log("Updating status for Question ${i + 1}", name: 'CarPlay');

      // If it's the first question, we are pushing onto Root (Stack: Root -> Q1). replace=false.
      // If subsequent (i > 0), we want to replace previous Q (Stack: Root -> Q1 -> pop -> Q2). replace=true.
      bool shouldReplace = (i > 0);

      _updateStatusTemplate(
        "Question ${i + 1}",
        q.questionText,
        replace: shouldReplace,
        options: q.options,
      );

      // Add small delay to ensure native transition (pop/push) settles
      // especially important if user hits Back repeatedly
      await Future.delayed(const Duration(milliseconds: 300));

      // Play Audio
      AppLogger.log("Playing audio for question...", name: 'CarPlay');
      await _voiceService.playQuestion(q);
      AppLogger.log("Audio finished", name: 'CarPlay');

      // Listen
      AppLogger.log("Listening for answer...", name: 'CarPlay');
      // REMOVED: _updateStatusTemplate("Listening...", ...) to avoid flash
      // The screen will stay on the Question + Options while listening.

      String? answer = await _voiceService.listenForAnswer(
        const Duration(seconds: 15),
      );
      AppLogger.log("Received answer: $answer", name: 'CarPlay');

      if (answer == null) {
        AppLogger.log("Answer was null (timeout/no speech)", name: 'CarPlay');
        await _voiceService.speakFeedback(false); // Timeout/No speech
      } else {
        // Check for stop command
        final normalizedAnswer = answer.toLowerCase().trim();
        if (normalizedAnswer.contains("stop questions") ||
            normalizedAnswer.contains("parar")) {
          AppLogger.log("Stop command received via voice", name: 'CarPlay');
          await _voiceService.speak("Stopping quiz.");
          _isPlaying = false;
          _voiceService.stop();
          FlutterCarplay.pop(animated: true);
          break;
        }

        bool correct = _voiceService.isCorrect(answer, q.correctAnswer);
        AppLogger.log("Answer correct? $correct", name: 'CarPlay');
        if (correct) score++;
        await _voiceService.speakFeedback(correct);
      }

      // Pause before next
      AppLogger.log("Pausing before next question...", name: 'CarPlay');
      await Future.delayed(const Duration(seconds: 3));
    }

    if (_isPlaying) {
      _updateStatusTemplate(
        "Quiz Finished",
        "Score: $score / ${questions.length}",
        replace: true,
      );
      await _voiceService.speak(
        "Quiz finished. You got $score out of ${questions.length} correct.",
      );
      await Future.delayed(const Duration(seconds: 5));
      FlutterCarplay.pop(); // Return to menu
    }
  }
}
