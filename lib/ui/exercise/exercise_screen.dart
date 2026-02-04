import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:animate_do/animate_do.dart';
import '../../services/tts_service.dart';
import '../quiz/quiz_screen.dart'; // Reuse QuestionCard

import 'exercise_view_model.dart';

class ExerciseScreen extends ConsumerStatefulWidget {
  final String unitName;
  final String unitPath;
  final String? hintPath;

  const ExerciseScreen({
    super.key,
    required this.unitName,
    required this.unitPath,
    this.hintPath,
  });

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  final TtsService _ttsService = TtsService();
  final double _speedMultiplier = 0.75;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(exerciseViewModelProvider.notifier)
          .startExercise(widget.unitPath);
      await _ttsService.setRate(_speedMultiplier);
    });
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _handleAnswer(String option) async {
    final viewModel = ref.read(exerciseViewModelProvider.notifier);
    viewModel.answerQuestion(option);
  }

  void _handleNext() {
    final viewModel = ref.read(exerciseViewModelProvider.notifier);
    _swiperController.swipe(CardSwiperDirection.left);
    viewModel.nextQuestion();
  }

  void _showHint() {
    if (widget.hintPath == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(widget.hintPath!, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white70,
                  highlightColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(exerciseViewModelProvider);

    if (quizState.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.unitName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (quizState.isFinished) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.unitName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: const Icon(
                  Icons.check_circle_outline,
                  size: 100,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              FadeInUp(
                child: Text(
                  'Unit Complete!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Text(
                'Score: ${quizState.score}/${quizState.questions.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Exercises'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.unitName),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (widget.hintPath != null)
            IconButton(
              icon: const Icon(Icons.lightbulb_outline), // Requested icon
              tooltip: 'Show Hint',
              onPressed: _showHint,
            ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (quizState.currentIndex + 1) / quizState.questions.length,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: CardSwiper(
                controller: _swiperController,
                cardsCount: quizState.questions.length,
                numberOfCardsDisplayed: 1, // Focus on current question
                isDisabled: true,
                cardBuilder:
                    (context, index, percentThresholdX, percentThresholdY) {
                      final question = quizState.questions[index];
                      return QuestionCard(
                        key: ValueKey(question.id),
                        question: question,
                        onAnswer: (option) => _handleAnswer(option),
                        onNext: _handleNext,
                        ttsService: _ttsService,
                      );
                    },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
