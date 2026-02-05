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
      // 1. Show "Loading..." or "Starting..." on CarPlay IMMEDIATELY
      // We can push a new template (Information Template)
      _updateStatusTemplate("Starting Quiz...", "Get ready!");

      // 2. Initialize Voice Service
      print("CarPlay: Initializing VoiceService...");
      await _voiceService.init();
      print("CarPlay: VoiceService initialized");

      // 3. Fetch Questions
      print("CarPlay: Fetching questions...");
      List<Question> questions = await _fetchQuestions();
      print("CarPlay: Fetched ${questions.length} questions");

      if (questions.isEmpty) {
        _updateStatusTemplate("Error", "No questions available.");
        await _voiceService.speakFeedback(false); // Make it speak error
        return;
      }

      print("CarPlay: Starting quiz loop...");
      await _runQuizLoop(questions);
      print("CarPlay: Quiz loop finished");
    } catch (e, stack) {
      print("CarPlay: Error starting quiz: $e");
      print(stack);
      _updateStatusTemplate("Error", "Could not start quiz: $e");
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

  void _updateStatusTemplate(String title, String detail) {
    FlutterCarplay.push(
      template: CPInformationTemplate(
        title: title,
        layout: CPInformationTemplateLayout.leading,
        actions: [],
        informationItems: [CPInformationItem(title: detail, detail: "")],
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
      print("CarPlay: Updating status for Question ${i + 1}");
      _updateStatusTemplate("Question ${i + 1}", q.questionText);

      // Play Audio
      print("CarPlay: Playing audio for question...");
      await _voiceService.playQuestion(q);
      print("CarPlay: Audio finished");

      // Listen
      print("CarPlay: Listening for answer...");
      _updateStatusTemplate("Listening...", "Speak your answer now");
      String? answer = await _voiceService.listenForAnswer(
        const Duration(seconds: 5),
      );
      print("CarPlay: Received answer: $answer");

      if (answer == null) {
        print("CarPlay: Answer was null (timeout/no speech)");
        await _voiceService.speakFeedback(false); // Timeout/No speech
      } else {
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
      );
      await _voiceService.speak(
        "Quiz finished. You got $score out of ${questions.length} correct.",
      );
      await Future.delayed(const Duration(seconds: 5));
      FlutterCarplay.pop(); // Return to menu
    }
  }
}
