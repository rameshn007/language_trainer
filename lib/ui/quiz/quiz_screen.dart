import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:animate_do/animate_do.dart';
import '../../models/question.dart';
import 'quiz_view_model.dart';
import '../../services/tts_service.dart';
import '../../main.dart';
import '../vocabulary/vocabulary_list_screen.dart';
import '../common/long_press_word_text.dart';

class QuizScreen extends ConsumerStatefulWidget {
  final String? category;
  final bool isVocabularyQuiz;
  final bool isInterrogativeQuiz;
  final String? interrogativeCategory;
  const QuizScreen({
    super.key,
    this.category,
    this.isVocabularyQuiz = false,
    this.isInterrogativeQuiz = false,
    this.interrogativeCategory,
  });

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  final GlobalKey<QuestionCardState> _currentCardKey = GlobalKey<QuestionCardState>();
  late final TtsService _ttsService;
  double _speedMultiplier = 0.75; // Default as requested

  @override
  void initState() {
    super.initState();
    _ttsService = ref.read(ttsServiceProvider);
    // Start quiz on load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.isInterrogativeQuiz) {
        await ref.read(quizViewModelProvider.notifier).startInterrogativeQuiz(
          category: widget.interrogativeCategory,
        );
      } else if (widget.isVocabularyQuiz) {
        await ref.read(quizViewModelProvider.notifier).startVocabularyQuiz();
      } else {
        await ref
            .read(quizViewModelProvider.notifier)
            .startQuiz(category: widget.category);
      }
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

  void _showVoiceSettings() {
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'vocabulary') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VocabularyListScreen(),
                  ),
                );
              } else if (value == 'voice_settings') {
                _showVoiceSettings();
              } else if (value == 'show_answer') {
                _currentCardKey.currentState?.revealAnswer();
              }
            },
            itemBuilder: (BuildContext context) {
              return const [
                PopupMenuItem<String>(
                  value: 'show_answer',
                  child: Row(
                    children: [
                      Icon(Icons.visibility),
                      SizedBox(width: 8),
                      Text('Show Answer'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'vocabulary',
                  child: Row(
                    children: [
                      Icon(Icons.book),
                      SizedBox(width: 8),
                      Text('Vocabulary'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'voice_settings',
                  child: Row(
                    children: [
                      Icon(Icons.record_voice_over),
                      SizedBox(width: 8),
                      Text('Voice Settings'),
                    ],
                  ),
                ),
              ];
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
                        key: index == quizState.currentIndex ? _currentCardKey : ValueKey(question.id),
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
  State<QuestionCard> createState() => QuestionCardState();
}

class QuestionCardState extends State<QuestionCard> {
  Set<String> _wrongAnswers = {};
  bool _isCorrect = false;
  bool _hasAttempted = false;

  @override
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.question.id != oldWidget.question.id) {
      setState(() {
        _wrongAnswers = {};
        _isCorrect = false;
        _hasAttempted = false;
        // Reset reorder data
        _availableWords = null;
        _selectedWords = null;
        _selectedVerbForm = null;
        _originalVerb = null;
      });
    }
  }

  void _onOptionTap(String option) {
    if (_isCorrect) {
      // Repeat audio if tapping the correct answer again
      if (option == widget.question.correctAnswer) {
        widget.ttsService.speak(
          widget.question.sourceItem.portuguese,
          language: 'pt',
        );
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

      String textToSpeak = widget.question.sourceItem.portuguese;

      // For cloze (fill in the blank) questions, reconstruct the full sentence
      if (widget.question.type == QuestionType.cloze) {
        String baseText = widget.question.questionText;

        // 1. Handle "Fill in the blank: '...'" format
        if (baseText.contains("Fill in the blank: '")) {
          final start = baseText.indexOf("'") + 1;
          final end = baseText.lastIndexOf("'");
          if (start < end) {
            baseText = baseText.substring(start, end);
          }
        }

        // 2. Remove trailing (infinitive) like "(abrir)"
        if (baseText.contains(" (")) {
          baseText = baseText.split(" (").first;
        }

        // 3. Replace blanks (______ or ____) with the correct answer
        if (baseText.contains("______")) {
          textToSpeak = baseText.replaceAll("______", widget.question.correctAnswer);
        } else if (baseText.contains("____")) {
          textToSpeak = baseText.replaceAll("____", widget.question.correctAnswer);
        } else {
          // Fallback: just use what we have
          textToSpeak = baseText;
        }
      }

      widget.ttsService.speak(
        textToSpeak,
        language: 'pt',
      );
    } else {
      setState(() {
        _wrongAnswers.add(option);
      });
      widget.ttsService.speak("Incorrecto.", language: 'pt');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.question.type == QuestionType.reorderAndConjugate) {
      return _buildReorderAndConjugateBody(context);
    }

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
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
                            widget.question.type == QuestionType.interrogativeMatch
                                ? "What does this mean?"
                                : "Translate this",
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
                              language: 'pt',
                            ),
                          )
                        else
                          const SizedBox(width: 48), // Maintain balance
                      ],
                    ),
                    const SizedBox(height: 20),
                    widget.question.questionText == widget.question.sourceItem.portuguese || widget.question.type == QuestionType.cloze
                        ? LongPressWordText(
                            text: widget.question.questionText,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : Text(
                            widget.question.questionText,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                    const SizedBox(height: 30),
                    widget.question.type == QuestionType.vocabularyMatch
                        ? Center(
                          child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
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
                                    color = Theme.of(context).brightness == Brightness.dark
                                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                                        : Colors.grey.shade100;
                                    textColor = Theme.of(context).colorScheme.onSurface;
                                  }

                                  return ActionChip(
                                    label: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: textColor,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    onPressed: () => _onOptionTap(option),
                                    backgroundColor: color,
                                    side: BorderSide(
                                      color: (_isCorrect && isCorrectAnswer) || isWrongAnswer
                                          ? textColor
                                          : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  );
                                }),
                              ],
                            ),
                        )
                        : Column(
                            children: [
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
                                            color: (_isCorrect && isCorrectAnswer) || isWrongAnswer
                                                ? textColor
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _onOptionTap(option),
                                      child: Text(
                                        option,
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Bottom Action Area
            SizedBox(
              height: 60,
              width: double.infinity,
              child: _isCorrect 
                ? FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: widget.onNext,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        "Next Question",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // --- Reorder and Conjugate View ---

  List<String>? _availableWords;
  List<String>? _selectedWords;
  String? _selectedVerbForm;
  String? _originalVerb;

  void _initReorderData() {
    if (_availableWords != null) return;
    final words = widget.question.questionText.split('/').map((s) => s.trim()).toList();
    _availableWords = List.from(words);
    // Find the reflexive verb (ends in -se or -me etc, or has a hypthen)
    _originalVerb = _availableWords!.firstWhere(
      (w) => w.contains('-se') || w.contains('-me') || w.contains('-te') || w.contains('-nos') || w.contains('-vos'),
      orElse: () => "",
    );
    _selectedWords = [];
  }

  Widget _buildReorderAndConjugateBody(BuildContext context) {
    _initReorderData();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      "Reorder words & Conjugate verb",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.question.sourceItem.english,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(height: 40),
                    
                    // Answer Area
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black26 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._selectedWords!.map((word) {
                            return ActionChip(
                              label: Text(word, style: const TextStyle(fontSize: 16)),
                              onPressed: () {
                                if (_isCorrect) return;
                                setState(() {
                                  _selectedWords!.remove(word);
                                  if (word == _selectedVerbForm) {
                                    _availableWords!.add(_originalVerb!);
                                    _selectedVerbForm = null;
                                  } else {
                                    _availableWords!.add(word);
                                  }
                                });
                              },
                              backgroundColor: isDark 
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                                  : Colors.deepPurple.shade50,
                              labelStyle: TextStyle(
                                color: isDark ? Theme.of(context).colorScheme.primary : Colors.deepPurple.shade900,
                              ),
                              side: BorderSide(
                                color: isDark ? Theme.of(context).colorScheme.primary : Colors.deepPurple,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Word bank
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._availableWords!.map((word) {
                          return ActionChip(
                            label: Text(word, style: const TextStyle(fontSize: 16)),
                            onPressed: () {
                              if (_isCorrect) return;
                              if (word == _originalVerb) {
                                _showVerbPicker(context);
                              } else {
                                setState(() {
                                  _availableWords!.remove(word);
                                  _selectedWords!.add(word);
                                });
                              }
                            },
                            backgroundColor: isDark ? Colors.white10 : Colors.white,
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            
            // Bottom Action Area
            SizedBox(
              height: 60,
              width: double.infinity,
              child: _isCorrect 
                ? FadeInUp(
                    duration: const Duration(milliseconds: 400),
                    child: ElevatedButton.icon(
                      onPressed: widget.onNext,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text("Next Question"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: _selectedWords!.isEmpty ? null : _checkReorderAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Check Answer"),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerbPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Conjugate: $_originalVerb",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...widget.question.options.map((option) {
                    return ChoiceChip(
                      label: Text(option),
                      selected: false,
                      onSelected: (_) {
                        Navigator.pop(context);
                        setState(() {
                          _selectedVerbForm = option;
                          _availableWords!.remove(_originalVerb);
                          _selectedWords!.add(option);
                        });
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _checkReorderAnswer() {
    final userAnswer = _selectedWords!.join(' ');
    // Simple normalization: remove trailing punctuation if needed or just exact match
    if (userAnswer.trim() == widget.question.correctAnswer.trim() || 
        userAnswer.trim() == widget.question.correctAnswer.replaceAll('.', '').trim()) {
      setState(() {
        _isCorrect = true;
      });
      widget.ttsService.speak(widget.question.correctAnswer, language: 'pt');
    } else {
      widget.ttsService.speak("Tenta de novo.", language: 'pt');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect order or conjugation. Try again!"), duration: Duration(seconds: 1)),
      );
    }
  }

  void revealAnswer() {
    if (_isCorrect) return;

    setState(() {
      _isCorrect = true;
      _hasAttempted = true;

      if (widget.question.type == QuestionType.reorderAndConjugate) {
        _selectedWords = widget.question.correctAnswer.split(' ').map((s) => s.trim()).toList();
        _availableWords = [];
      }
    });

    widget.ttsService.speak(widget.question.correctAnswer, language: 'pt');
  }
}
