import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/language_item.dart';
import '../../services/related_words_service.dart';
import '../../services/tts_service.dart';
import '../../main.dart'; // added

class WordGraphScreen extends ConsumerStatefulWidget {
  final LanguageItem initialWord;

  const WordGraphScreen({super.key, required this.initialWord});

  @override
  ConsumerState<WordGraphScreen> createState() => _WordGraphScreenState();
}

class _WordGraphScreenState extends ConsumerState<WordGraphScreen>
    with TickerProviderStateMixin {
  late LanguageItem _centerWord;
  List<LanguageItem> _orbitingWords = [];

  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late TtsService _ttsService;
  late RelatedWordsService _relatedWordsService;

  @override
  void initState() {
    super.initState();
    _centerWord = widget.initialWord;

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ttsService = ref.read(ttsServiceProvider);
      _relatedWordsService = ref.read(relatedWordsServiceProvider);
      _loadRelatedWords();
      _playTts(_centerWord);
    });
  }

  void _loadRelatedWords() {
    setState(() {
      _orbitingWords = _relatedWordsService.getRelatedWords(
        _centerWord,
        limit: 6,
      );
    });
  }

  Future<void> _playTts(LanguageItem item) async {
    await _ttsService.speak(item.portuguese, language: 'pt-PT');
    await Future.delayed(const Duration(milliseconds: 1500));
    // Check if mounted just in case
    if (mounted) {
      await _ttsService.speak(item.english, language: 'en-US');
    }
  }

  void _onNodeTap(LanguageItem tappedItem) {
    if (_centerWord.id == tappedItem.id) {
      _playTts(tappedItem);
      return;
    }
    setState(() {
      _centerWord = tappedItem;
      _loadRelatedWords();
    });
    _playTts(tappedItem);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Graph'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColorDark.withValues(alpha: 0.8),
              Colors.black87,
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            return CustomPaint(
              painter: GraphLinesPainter(
                centerWord: _centerWord,
                orbitingWords: _orbitingWords,
                rotationProgress: _rotationController.value,
              ),
              child: Stack(
                children: [
                  // Orbiting nodes
                  ..._buildOrbitingNodes(context),

                  // Center node
                  Align(
                    alignment: Alignment.center,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.1),
                          child: _buildNode(_centerWord, isCenter: true),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildOrbitingNodes(BuildContext context) {
    if (_orbitingWords.isEmpty) return [];

    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Calculate radius based on screen size
    final radius = math.min(size.width, size.height) * 0.35;

    return List.generate(_orbitingWords.length, (index) {
      final item = _orbitingWords[index];

      // Calculate angle with rotation offset
      final baseAngle = (2 * math.pi * index) / _orbitingWords.length;
      final currentAngle =
          baseAngle + (_rotationController.value * 2 * math.pi);

      // Add a slight oscillation to the radius to make them float organically
      // Using index for phase shift so they oscillate differently
      final floatOffset =
          math.sin((_rotationController.value * 10 * math.pi) + index) * 15;
      final actualRadius = radius + floatOffset;

      final x = centerX + actualRadius * math.cos(currentAngle);
      final y = centerY + actualRadius * math.sin(currentAngle);

      return Positioned(
        left: x - 50, // Center the 100px wide node
        top: y - 50, // Center the node
        child: _buildNode(item, isCenter: false),
      );
    });
  }

  Widget _buildNode(LanguageItem item, {required bool isCenter}) {
    return GestureDetector(
      onTap: () => _onNodeTap(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isCenter ? 120 : 100,
        height: isCenter ? 120 : 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: isCenter
                ? [Colors.blueAccent, Colors.purpleAccent]
                : [Colors.teal, Colors.greenAccent],
          ),
          boxShadow: [
            BoxShadow(
              color: (isCenter ? Colors.purpleAccent : Colors.tealAccent)
                  .withValues(alpha: 0.6),
              blurRadius: isCenter ? 20 : 10,
              spreadRadius: isCenter ? 5 : 2,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.portuguese,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isCenter ? 14 : 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isCenter) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.english,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GraphLinesPainter extends CustomPainter {
  final LanguageItem centerWord;
  final List<LanguageItem> orbitingWords;
  final double rotationProgress;

  GraphLinesPainter({
    required this.centerWord,
    required this.orbitingWords,
    required this.rotationProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (orbitingWords.isEmpty) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = math.min(size.width, size.height) * 0.35;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < orbitingWords.length; i++) {
      final baseAngle = (2 * math.pi * i) / orbitingWords.length;
      final currentAngle = baseAngle + (rotationProgress * 2 * math.pi);

      final floatOffset = math.sin((rotationProgress * 10 * math.pi) + i) * 15;
      final actualRadius = radius + floatOffset;

      final targetX = centerX + actualRadius * math.cos(currentAngle);
      final targetY = centerY + actualRadius * math.sin(currentAngle);

      // Optional: Draw slightly curved lines (bezier) instead of straight for flair
      final path = Path();
      path.moveTo(centerX, centerY);

      // Control point halfway but offset slightly to create a curve
      final cpX =
          centerX + (targetX - centerX) / 2 - (math.sin(currentAngle) * 30);
      final cpY =
          centerY + (targetY - centerY) / 2 + (math.cos(currentAngle) * 30);

      path.quadraticBezierTo(cpX, cpY, targetX, targetY);

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GraphLinesPainter oldDelegate) {
    return true; // Simple approach, always repaint on animation frame
  }
}
