import 'dart:math';
import 'package:flutter/material.dart';

class WordStarField extends StatefulWidget {
  final List<String> words;
  final int wordCount;

  const WordStarField({super.key, required this.words, this.wordCount = 15});

  @override
  State<WordStarField> createState() => _WordStarFieldState();
}

class _WordStarFieldState extends State<WordStarField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Star> _stars = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60), // Long loop
    )..repeat();

    // Initial population
    if (widget.words.isNotEmpty) {
      for (int i = 0; i < widget.wordCount; i++) {
        _stars.add(_generateStar(true));
      }
    }
  }

  @override
  void didUpdateWidget(WordStarField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.words != oldWidget.words) {
      _stars.clear();
      if (widget.words.isNotEmpty) {
        for (int i = 0; i < widget.wordCount; i++) {
          _stars.add(_generateStar(true));
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _Star _generateStar(bool initial) {
    final word = widget.words[_random.nextInt(widget.words.length)];
    // Random position
    // If initial, anywhere on screen. Else, maybe start from edges?
    // For now, simpler: just wrap around in update or start anywhere.
    // Let's use 0.0-1.0 coords.
    return _Star(
      text: word,
      x: _random.nextDouble(),
      y: _random.nextDouble(),
      z: 0.5 + _random.nextDouble() * 0.5, // 0.5 to 1.0 depth scale
      velocity:
          (_random.nextDouble() - 0.5) * 0.0005, // Slight horizontal drift
      color: _getRandomColor(),
      opacity: 0.0, // Start invisible and fade in?
      fadeInDuration: _random.nextInt(1000) + 500,
      phase: _random.nextDouble() * 2 * pi, // For twinkling
    );
  }

  Color _getRandomColor() {
    // Vibrant colors
    const colors = [
      Color(0xFFFF5252), // Red Accent
      Color(0xFFFF4081), // Pink Accent
      Color(0xFFE040FB), // Purple Accent
      Color(0xFF7C4DFF), // Deep Purple Accent
      Color(0xFF536DFE), // Indigo Accent
      Color(0xFF448AFF), // Blue Accent
      Color(0xFF40C4FF), // Light Blue Accent
      Color(0xFF18FFFF), // Cyan Accent
      Color(0xFF64FFDA), // Teal Accent
      Color(0xFF69F0AE), // Green Accent
      Color(0xFFB2FF59), // Light Green Accent
      Color(0xFFEEFF41), // Lime Accent
      Color(0xFFFFE082), // Amber Accent
      Color(0xFFFFAB40), // Orange Accent
    ];
    return colors[_random.nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double w = constraints.maxWidth;
            final double h = constraints.maxHeight;

            return Stack(
              children: _stars.map((star) {
                // Update star logic (simple function, no persistent state change in build normally,
                // but for simple animation loop it's okay-ish, or use a Ticker separately.
                // Better: Update state in a Ticker or Timer, but AnimatedBuilder rebuilds every frame anyway.
                // We'll calculate position based on controller value but controller just loops 0-1.
                // To have independent drifts, we need to update star state.

                // Let's update state here for simplicity of "Game Loop".
                // NOTE: Side effects in build are bad practice, but very common for simple Flutter animations like this.
                // Ideally, use a Ticker and setState.

                star.x += star.velocity;
                star.y -= 0.0002; // Drift up slowly

                // Wrap around
                if (star.x < -0.1) star.x = 1.1;
                if (star.x > 1.1) star.x = -0.1;
                if (star.y < -0.1) star.y = 1.1;
                if (star.y > 1.1) star.y = -0.1;

                // Twinkle
                final double opacityBase =
                    0.5 + 0.5 * sin(_controller.value * 2 * pi + star.phase);

                return Positioned(
                  left: star.x * w,
                  top: star.y * h,
                  child: Opacity(
                    opacity: (opacityBase * star.z).clamp(0.5, 1.0),
                    child: Transform.scale(
                      scale: star.z, // Smaller when further "back"
                      child: FractionalTranslation(
                        translation: const Offset(-0.5, 0),
                        child: Text(
                          star.text,
                          style: TextStyle(
                            color: star.color,
                            fontSize: 20, // Base size, scaled by z
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: star.color.withValues(alpha: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _Star {
  String text;
  double x;
  double y;
  double z;
  double velocity;
  Color color;
  double opacity;
  int fadeInDuration;
  double phase;

  _Star({
    required this.text,
    required this.x,
    required this.y,
    required this.z,
    required this.velocity,
    required this.color,
    required this.opacity,
    required this.fadeInDuration,
    required this.phase,
  });
}
