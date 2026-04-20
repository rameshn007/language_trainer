import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animate_do/animate_do.dart';

import '../../main.dart';
import '../../models/verb_phrase.dart';
import '../../models/progress_data.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../../services/storage_service.dart';
import '../common/long_press_word_text.dart';
import 'single_verb_conjugation_screen.dart';

class VerbPhraseTrainerScreen extends ConsumerStatefulWidget {
  const VerbPhraseTrainerScreen({super.key});

  @override
  ConsumerState<VerbPhraseTrainerScreen> createState() =>
      _VerbPhraseTrainerScreenState();
}

class _VerbPhraseTrainerScreenState
    extends ConsumerState<VerbPhraseTrainerScreen> {
  List<VerbPhrase> _phrases = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isFlipped = false;
  late bool _isEnglishFront;
  bool _hasRated = false;

  // Scoring state
  int _correctCount = 0;
  int _totalRated = 0;
  int _sessionXP = 0;
  DateTime? _sessionStartTime;

  late final TtsService _ttsService;
  late final StorageService _storageService;
  late final ProgressService _progressService;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _ttsService = ref.read(ttsServiceProvider);
    _storageService = ref.read(storageServiceProvider);
    _progressService = ref.read(progressServiceProvider.notifier);
    _loadPhrases();
  }

  @override
  void dispose() {
    _recordSessionComplete();
    super.dispose();
  }

  Future<void> _loadPhrases() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/verb_phrases.json',
      );
      final List<dynamic> data = json.decode(response);

      if (!mounted) return;

      setState(() {
        _phrases = data.map((json) => VerbPhrase.fromJson(json)).toList();
        _phrases.shuffle(_random);
        _currentIndex = 0;
        _isEnglishFront = _random.nextBool();
        _isLoading = false;
        _sessionStartTime = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load phrases: $e')));
    }
  }

  void _nextCard() {
    if (_currentIndex < _phrases.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
        _hasRated = false;
        _isEnglishFront = _random.nextBool();
      });
    } else {
      // Session complete — record it, then reshuffle
      _recordSessionComplete();
      setState(() {
        _phrases.shuffle(_random);
        _currentIndex = 0;
        _isFlipped = false;
        _hasRated = false;
        _isEnglishFront = _random.nextBool();
        _correctCount = 0;
        _totalRated = 0;
        _sessionXP = 0;
        _sessionStartTime = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reshuffled! Starting again.')),
      );
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
        _hasRated = false;
        _isEnglishFront = _random.nextBool();
      });
    }
  }

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });

    if (_isFlipped) {
      // Speak the Portuguese side automatically when revealed
      final phrase = _phrases[_currentIndex];
      _ttsService.speak(phrase.portuguese, language: 'pt');
    }
  }

  Future<void> _rateAnswer(bool correct) async {
    if (_hasRated) return;

    final phrase = _phrases[_currentIndex];
    final itemId = 'verbphrase_${phrase.verb}_$_currentIndex';

    final xp = await _progressService.recordQuizAnswer(
      storage: _storageService,
      itemId: itemId,
      correct: correct,
      firstAttempt: correct,
    );

    if (mounted) {
      setState(() {
        _hasRated = true;
        _totalRated++;
        _sessionXP += xp;
        if (correct) _correctCount++;
      });
    }
  }

  Future<void> _recordSessionComplete() async {
    if (_totalRated == 0) return;
    final durationSec = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;

    await _progressService.recordSessionComplete(
      storage: _storageService,
      activityType: ActivityType.phraseTrainer,
      score: _correctCount,
      total: _totalRated,
      durationSeconds: durationSec,
      sessionXP: _sessionXP,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('100 Phrases')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_phrases.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('100 Phrases')),
        body: const Center(child: Text('No phrases loaded.')),
      );
    }

    final phrase = _phrases[_currentIndex];

    // Determine what to show on front vs back
    // If _isEnglishFront == true:
    // Front: English phrase + Portuguese Verb
    // Back:  Portuguese phrase + English Phrase + Verb
    // Else (_isEnglishFront == false):
    // Front: Portuguese phrase + Portuguese Verb
    // Back:  English phrase + Portuguese phrase

    return Scaffold(
      appBar: AppBar(
        title: Text('Phrase ${_currentIndex + 1}/${_phrases.length}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FadeInDown(
                child: Text(
                  'Tap the card to reveal translation',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ),
              const Spacer(),

              // Flashcard
              GestureDetector(
                onTap: _toggleFlip,
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! < -300) {
                      _nextCard(); // Swipe left
                    } else if (details.primaryVelocity! > 300) {
                      _previousCard(); // Swipe right
                    }
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        // Simple flip transition
                        final rotateAnim = Tween(
                          begin: 3.14,
                          end: 0.0,
                        ).animate(animation);
                        return AnimatedBuilder(
                          animation: rotateAnim,
                          child: child,
                          builder: (context, widget) {
                            final isUnder =
                                (ValueKey(_isFlipped) != widget?.key);
                            var tilt =
                                ((animation.value - 0.5).abs() - 0.5) * 0.003;
                            tilt *= isUnder ? -1.0 : 1.0;
                            final value = isUnder
                                ? min(rotateAnim.value, 3.14 / 2)
                                : rotateAnim.value;
                            return Transform(
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, tilt)
                                ..rotateY(value),
                              alignment: Alignment.center,
                              child: widget,
                            );
                          },
                        );
                      },
                  child: _isFlipped
                      ? _buildBackCard(phrase, key: const ValueKey(true))
                      : _buildFrontCard(phrase, key: const ValueKey(false)),
                ),
              ),

              const Spacer(),

              // Self-assessment buttons (appear after flip)
              if (_isFlipped)
                FadeInUp(
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRatingButton(
                          label: 'Missed it',
                          icon: Icons.close,
                          color: Colors.red.shade400,
                          isSelected: _hasRated && _totalRated > 0 && !(_correctCount == _totalRated),
                          onPressed: _hasRated ? null : () => _rateAnswer(false),
                        ),
                        const SizedBox(width: 16),
                        _buildRatingButton(
                          label: 'Got it!',
                          icon: Icons.check,
                          color: Colors.green.shade400,
                          isSelected: _hasRated,
                          onPressed: _hasRated ? null : () => _rateAnswer(true),
                        ),
                      ],
                    ),
                  ),
                ),

              // Score indicator
              if (_totalRated > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$_correctCount / $_totalRated correct  •  $_sessionXP XP',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _currentIndex > 0 ? _previousCard : null,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _nextCard,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontCard(VerbPhrase phrase, {required Key key}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: key,
      height: 420,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
        border: Border.all(
          color: isDark
              ? Theme.of(context).colorScheme.outlineVariant
              : Theme.of(context).primaryColor.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SingleVerbConjugationScreen(
                      verbInfinitive: phrase.verb,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) 
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      phrase.verb.toUpperCase(),
                      style: TextStyle(
                        color: isDark ? Theme.of(context).colorScheme.primary : Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: isDark ? Theme.of(context).colorScheme.primary : Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          _isEnglishFront
              ? Text(
                  phrase.english,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                )
              : LongPressWordText(
                  text: phrase.portuguese,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swap_horiz, color: Colors.grey.shade400, size: 20),
              const SizedBox(width: 8),
              Text(
                _isEnglishFront ? 'EN -> PT' : 'PT -> EN',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackCard(VerbPhrase phrase, {required Key key}) {
    return Container(
      key: key,
      height: 420,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6A11CB), // Vibrant Purple
            Color(0xFF2575FC), // Vibrant Blue
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6A11CB).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2), // Subtle inner shine
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _isEnglishFront
              ? LongPressWordText(
                  text: phrase.portuguese,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                )
              : Text(
                  phrase.english,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.3), thickness: 1),
          const SizedBox(height: 20),
          _isEnglishFront
              ? Text(
                  phrase.english,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                )
              : LongPressWordText(
                  text: phrase.portuguese,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
          const SizedBox(height: 40),
          IconButton(
            icon: const Icon(Icons.volume_up, size: 36),
            color: Colors.white,
            onPressed: () {
              // Re-play the Portuguese part explicitly when this button is pressed
              _ttsService.speak(phrase.portuguese, language: 'pt');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color.withValues(alpha: 0.8) : null,
        foregroundColor: isSelected ? Colors.white : color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color, width: 1.5),
        ),
      ),
    );
  }
}
