import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:animate_do/animate_do.dart';
import '../../models/question.dart';
import 'quiz_view_model.dart';
import '../../services/tts_service.dart';
import '../vocabulary/vocabulary_list_screen.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String? category;
  const QuizScreen({super.key, this.category});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  final TtsService _ttsService = TtsService();
  double _speedMultiplier = 0.75; // Default as requested

  @override
  void initState() {
    super.initState();
    // Start quiz on load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(quizViewModelProvider.notifier)
          .startQuiz(category: widget.category);
      // Initialize speed
      await _ttsService.setRate(_speedMultiplier);
    });
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _toggleSpeed() {
    setState(() {
      if (_speedMultiplier == 0.75) {
        _speedMultiplier = 1.0;
      } else if (_speedMultiplier == 1.0) {
        _speedMultiplier = 1.5;
      } else if (_speedMultiplier == 1.5) {
        _speedMultiplier = 0.5;
      } else {
        _speedMultiplier = 0.75;
      }
    });
    _ttsService.setRate(_speedMultiplier);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Speed: ${_speedMultiplier}x"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleAnswer(String option, Question question) async {
    final viewModel = ref.read(quizViewModelProvider.notifier);
    viewModel.answerQuestion(option);
  }

  void _handleNext() {
    final viewModel = ref.read(quizViewModelProvider.notifier);
    _swiperController.swipe(CardSwiperDirection.left);
    viewModel.nextQuestion();
  }

  @override
  Widget build(BuildContext context) {
    final quizState = ref.watch(quizViewModelProvider);

    if (quizState.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 60, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No questions found for this category.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (quizState.isFinished) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: const Icon(
                  Icons.emoji_events,
                  size: 100,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 20),
              FadeInUp(
                child: Text(
                  'Quiz Complete!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              Text(
                'Score: ${quizState.score}/${quizState.questions.length}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Score: ${quizState.score}'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.speed),
            tooltip: 'Toggle Speed',
            onPressed: _toggleSpeed,
          ),
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'Vocabulary List',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VocabularyListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over), // or help_outline
            tooltip: 'Voice Settings',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Improve Voice Quality'),
                  content: SingleChildScrollView(
                    child: Text(_ttsService.getVoiceInstallationInstructions()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close Quiz',
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
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
                numberOfCardsDisplayed: 3,
                isDisabled: true, // Disable manual swiping, force answer
                cardBuilder:
                    (context, index, percentThresholdX, percentThresholdY) {
                      final question = quizState.questions[index];
                      return QuestionCard(
                        key: ValueKey(question.id),
                        question: question,
                        onAnswer: (option) => _handleAnswer(option, question),
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

class QuestionCard extends StatefulWidget {
  final Question question;
  final Function(String) onAnswer;
  final VoidCallback onNext;
  final TtsService ttsService;

  const QuestionCard({
    super.key,
    required this.question,
    required this.onAnswer,
    required this.onNext,
    required this.ttsService,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final Set<String> _wrongAnswers = {};
  bool _isCorrect = false;
  bool _hasAttempted = false;

  void _onOptionTap(String option) {
    if (_isCorrect) {
      // Repeat audio if tapping the correct answer again
      if (option == widget.question.correctAnswer) {
        widget.ttsService.speak(widget.question.sourceItem.portuguese);
      }
      return;
    }

    if (_wrongAnswers.contains(option)) return; // Already tried this wrong one

    if (!_hasAttempted) {
      widget.onAnswer(option);
      _hasAttempted = true;
    }

    if (option == widget.question.correctAnswer) {
      setState(() {
        _isCorrect = true;
      });
      // Always speak Portuguese source on correct
      widget.ttsService.speak(widget.question.sourceItem.portuguese);
    } else {
      setState(() {
        _wrongAnswers.add(option);
      });
      widget.ttsService.speak("Incorrecto.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48), // Balance
                  Expanded(
                    child: Text(
                      "Translate this",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (widget.question.type != QuestionType.cloze)
                    IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => widget.ttsService.speak(
                        widget.question.sourceItem.portuguese,
                      ),
                    )
                  else
                    const SizedBox(width: 48), // Maintain balance
                ],
              ),
              const SizedBox(height: 20),
              Text(
                widget.question.questionText,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ...widget.question.options.map((option) {
                final isCorrectAnswer = option == widget.question.correctAnswer;
                final isWrongAnswer = _wrongAnswers.contains(option);

                Color? color;
                Color? textColor;

                if (_isCorrect && isCorrectAnswer) {
                  color = Colors.green.shade100;
                  textColor = Colors.green.shade900;
                } else if (isWrongAnswer) {
                  color = Colors.red.shade100;
                  textColor = Colors.red.shade900;
                } else {
                  // Default state
                  color = Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : Colors.white;
                  textColor = Theme.of(context).colorScheme.onSurface;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: textColor,
                        elevation: (_isCorrect || isWrongAnswer) ? 0 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                (_isCorrect && isCorrectAnswer) || isWrongAnswer
                                ? textColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      onPressed: () => _onOptionTap(option),
                      child: Text(option, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Visibility(
                visible: _isCorrect,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: widget.onNext,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text(
                      "Next Question",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
