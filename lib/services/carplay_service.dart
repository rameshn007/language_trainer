import 'package:flutter_carplay/flutter_carplay.dart';
import 'voice_quiz_service.dart';
import '../models/question.dart';
import '../models/language_item.dart';

class CarPlayService {
  final VoiceQuizService _voiceService = VoiceQuizService();
  bool _isPlaying = false;

  // Singleton pattern
  static final CarPlayService _instance = CarPlayService._internal();
  factory CarPlayService() => _instance;
  CarPlayService._internal();

  final FlutterCarplay _flutterCarplay = FlutterCarplay();
  late CPListItem _startQuizItem;

  /// Initialise CarPlay
  void init() {
    print("CarPlay: init() called");

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

      // 3. Fetch Questions (Mocking or accessing Provider)
      // Accessing the provider container directly is tricky if not passed.
      // Ideally we inject the Questions or use the Service Locator pattern.
      // For now, let's assume we can get the container or ref from main.

      // TEMPORARY: Access global container if available, or just create a fresh batch
      // Since we are in the same isolate, we can potentially access the provider.
      // TEMPORARY: Mock data for now.
      // final container = ProviderScope.containerOf(rootNavigatorKey.currentContext!);
      // ^ This relies on context which we don't have here easily.

      // FALLBACK: Let's assume we trigger `QuizViewModel`.
      // For this implementation, I will just proceed with the structure.

      // ... logic to start loop ...
      print("CarPlay: Starting quiz loop...");
      await _runQuizLoop();
      print("CarPlay: Quiz loop finished");
    } catch (e, stack) {
      print("CarPlay: Error starting quiz: $e");
      print(stack);
      _updateStatusTemplate("Error", "Could not start quiz: $e");
    }
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
  Future<void> _runQuizLoop() async {
    print("CarPlay: _runQuizLoop started");
    _isPlaying = true;

    // Mock question list for the prototype loop
    // In real implementation, fetch from ViewModel state
    // Mock question list for the prototype loop
    // In real implementation, fetch from ViewModel state
    // List<Question> questions = []; // populate this

    // Since I can't easily reach the ProviderContainer without context in this snippet,
    // I will note that integration point.

    int score = 0;

    for (var i = 0; i < 5; i++) {
      print("CarPlay: Loop iteration $i");
      if (!_isPlaying) {
        print("CarPlay: Quiz stopped (isPlaying=false)");
        break;
      }

      // Mock Question
      // In reality: questions[i]
      var q = Question(
        id: "1", // ID should be unique really
        questionText: "How do you say 'Hello'?",
        options: ["Ola", "Adeus", "Obrigado", "Sim"],
        correctAnswer: "Ola",
        type: QuestionType.multipleChoice,
        sourceItem: LanguageItem.empty(),
      );

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
        Duration(seconds: 5),
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
      await Future.delayed(Duration(seconds: 3));
    }

    if (_isPlaying) {
      _updateStatusTemplate("Quiz Finished", "Score: $score / 5");
      await Future.delayed(Duration(seconds: 5));
      FlutterCarplay.pop(); // Return to menu
    }
  }
}
