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

  /// Initialise CarPlay
  void init() {
    FlutterCarplay.setRootTemplate(
      rootTemplate: CPListTemplate(
        sections: [
          CPListSection(
            items: [
              CPListItem(
                text: "Start Voice Quiz",
                detailText: "Practice Portuguese hands-free",
                image: "assets/images/app_icon.png",
                onPress: (complete, setItem) {
                  _startCarPlayQuiz();
                  complete();
                },
              ),
            ],
            header: "Language Trainer",
          ),
        ],
        title: "Language Trainer",
        systemIcon: "house.fill", // Required by some versions
      ),
      animated: true,
    );
  }

  void _startCarPlayQuiz() async {
    // 1. Initialize Voice Service
    await _voiceService.init();

    // 2. Show "Loading..." or "Starting..." on CarPlay
    // We can push a new template (Information Template)
    _updateStatusTemplate("Starting Quiz...", "Get ready!");

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
    _runQuizLoop();
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
  void _runQuizLoop() async {
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
      if (!_isPlaying) break;

      // Mock Question
      // In reality: questions[i]
      var q = Question(
        id: "1",
        questionText: "How do you say 'Hello'?",
        options: ["Ola", "Adeus", "Obrigado", "Sim"],
        correctAnswer: "Ola",
        type: QuestionType.multipleChoice,
        sourceItem: LanguageItem.empty(),
      );

      // Update UI
      _updateStatusTemplate("Question ${i + 1}", q.questionText);

      // Play Audio
      await _voiceService.playQuestion(q);

      // Listen
      _updateStatusTemplate("Listening...", "Speak your answer now");
      String? answer = await _voiceService.listenForAnswer(
        Duration(seconds: 5),
      );

      if (answer == null) {
        await _voiceService.speakFeedback(false); // Timeout/No speech
      } else {
        bool correct = _voiceService.isCorrect(answer, q.correctAnswer);
        if (correct) score++;
        await _voiceService.speakFeedback(correct);
      }

      // Pause before next
      await Future.delayed(Duration(seconds: 3));
    }

    if (_isPlaying) {
      _updateStatusTemplate("Quiz Finished", "Score: $score / 5");
      await Future.delayed(Duration(seconds: 5));
      FlutterCarplay.pop(); // Return to menu
    }
  }
}
