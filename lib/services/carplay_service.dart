import 'package:flutter_carplay/flutter_carplay.dart';
import 'voice_quiz_service.dart';
import '../models/question.dart';
import '../models/language_item.dart';
import 'storage_service.dart';
import 'quiz_engine_service.dart';

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
    print("CarPlay: init() called");
    _storageService = storageService;

    _startQuizItem = CPListItem(
      text: "Start Voice Quiz",
      detailText: "Practice Portuguese hands-free",
      image: "assets/images/app_icon.png",
      onPress: (complete, setItem) {
        print("CarPlay: 'Start Voice Quiz' pressed");
        complete();
        Future.delayed(const Duration(milliseconds: 200), () {
          _startCarPlayQuiz();
        });
      },
    );

    _flutterCarplay.addListenerOnConnectionChange((status) {
      print("CarPlay: Connection Status Changed: $status");
      // Check if status name contains 'connected' (case insensitive just to be safe)
      if (status.toString().toLowerCase().contains("connected")) {
        _setupRootTemplate();
      }
    });
  }

  void _setupRootTemplate() {
    print("CarPlay: Setting up root template");
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
      print("CarPlay: setRootTemplate called");
    } catch (e) {
      print("CarPlay: Error in _setupRootTemplate: $e");
    }
  }

  void _startCarPlayQuiz() async {
    print("CarPlay: _startCarPlayQuiz called");
    try {
      // 1. Loading/Starting
      // REMOVED: _updateStatusTemplate("Starting Quiz...", ...)
      // We will go straight to Q1 after fetching.
      print("CarPlay: Fetching questions...");

      // 2. Initialize Voice Service
      print("CarPlay: Initializing VoiceService...");
      await _voiceService.init();
      print("CarPlay: VoiceService initialized");

      // 3. Fetch Questions
      print("CarPlay: Fetching questions...");
      List<Question> questions = await _fetchQuestions();
      print("CarPlay: Fetched ${questions.length} questions");

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

      print("CarPlay: Starting quiz loop...");
      await _runQuizLoop(questions);
      print("CarPlay: Quiz loop finished");
    } catch (e, stack) {
      print("CarPlay: Error starting quiz: $e");
      print(stack);
      _updateStatusTemplate("Error", "Could not start quiz: $e", replace: true);
    }
  }

  Future<List<Question>> _fetchQuestions() async {
    // If no storage service available, return empty or mock
    if (_storageService == null) {
      print("CarPlay: Storage not initialized!");
      return _mockFallbackQuestions();
    }

    final items = _storageService!.getAllItems();
    if (items.isEmpty) {
      print("CarPlay: No items in storage.");
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
      // Small delay to ensure pop is registered by native side before pushing logic continues?
      // Although this method is void, a small await might help if we were async.
      // But we can't await void.
    }

    final List<CPInformationItem> infoItems = [
      CPInformationItem(title: detail, detail: ""),
    ];

    if (options.isNotEmpty) {
      // Add options to the list
      // CPInformationItem doesn't look like a list, but we can stack them.
      for (var opt in options) {
        infoItems.add(CPInformationItem(title: "• $opt", detail: ""));
      }
    }

    FlutterCarplay.push(
      template: CPInformationTemplate(
        title: title,
        layout: CPInformationTemplateLayout.leading,
        actions: [
          CPTextButton(
            title: "Stop Quiz",
            onPress: () {
              print("CarPlay: Stop Quiz pressed");
              _isPlaying = false;
              _voiceService.stop();
              // Pop back to root
              FlutterCarplay.pop(animated: true);
            },
          ),
        ],
        informationItems: infoItems,
      ),
      animated: true,
    );
  }

  // The main loop
  Future<void> _runQuizLoop(List<Question> questions) async {
    print("CarPlay: _runQuizLoop started with ${questions.length} questions");
    _isPlaying = true;

    int score = 0;

    for (var i = 0; i < questions.length; i++) {
      print("CarPlay: Loop iteration $i");
      if (!_isPlaying) {
        print("CarPlay: Quiz stopped (isPlaying=false)");
        break;
      }

      final q = questions[i];

      // Update UI
      // Update UI
      print("CarPlay: Updating status for Question ${i + 1}");

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
      print("CarPlay: Playing audio for question...");
      await _voiceService.playQuestion(q);
      print("CarPlay: Audio finished");

      // Listen
      print("CarPlay: Listening for answer...");
      // REMOVED: _updateStatusTemplate("Listening...", ...) to avoid flash
      // The screen will stay on the Question + Options while listening.

      String? answer = await _voiceService.listenForAnswer(
        const Duration(seconds: 15),
      );
      print("CarPlay: Received answer: $answer");

      if (answer == null) {
        print("CarPlay: Answer was null (timeout/no speech)");
        await _voiceService.speakFeedback(false); // Timeout/No speech
      } else {
        // Check for stop command
        final normalizedAnswer = answer.toLowerCase().trim();
        if (normalizedAnswer.contains("stop questions") ||
            normalizedAnswer.contains("parar")) {
          print("CarPlay: Stop command received via voice");
          await _voiceService.speak("Stopping quiz.");
          _isPlaying = false;
          _voiceService.stop();
          FlutterCarplay.pop(animated: true);
          break;
        }

        bool correct = _voiceService.isCorrect(answer, q.correctAnswer);
        print("CarPlay: Answer correct? $correct");
        if (correct) score++;
        await _voiceService.speakFeedback(correct);
      }

      // Pause before next
      print("CarPlay: Pausing before next question...");
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
