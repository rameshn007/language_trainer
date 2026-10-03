import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Structured result of a semantic voice evaluation.
class SemanticGradingResult {
  final bool isCorrect;
  final double confidence;
  final String errorType;
  final String? feedbackMessage;
  final bool usedNeuralEngine;

  const SemanticGradingResult({
    required this.isCorrect,
    required this.confidence,
    this.errorType = 'none',
    this.feedbackMessage,
    this.usedNeuralEngine = false,
  });

  /// Factory for baseline fast-path matches (exact or substring).
  factory SemanticGradingResult.fastPathMatch() => const SemanticGradingResult(
    isCorrect: true,
    confidence: 1.0,
    errorType: 'none',
    usedNeuralEngine: false,
  );

  /// Factory for high-confidence Levenshtein match.
  factory SemanticGradingResult.fuzzyMatch(double similarity) =>
      SemanticGradingResult(
        isCorrect: true,
        confidence: similarity,
        errorType: 'none',
        usedNeuralEngine: false,
      );

  /// Factory for fallback Levenshtein decision when Core ML is inactive.
  factory SemanticGradingResult.fallback({
    required bool isCorrect,
    required double similarity,
  }) => SemanticGradingResult(
    isCorrect: isCorrect,
    confidence: similarity,
    errorType: isCorrect ? 'none' : 'unrecognized',
    usedNeuralEngine: false,
  );
}

/// On-device semantic grading service that delegates to Apple Neural Engine
/// (via Core ML on iOS) with graceful zero-crash fallback on other platforms.
class SemanticGradingService {
  static const MethodChannel _channel = MethodChannel(
    'language_trainer/semantic_grading',
  );

  bool _isAvailable = false;
  bool _isInitialized = false;

  bool get isAvailable => _isAvailable;
  bool get isInitialized => _isInitialized;

  /// Initializes the Core ML model channel and preloads the Apple Neural Engine
  /// weights if running on iOS.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!Platform.isIOS) {
      _isAvailable = false;
      return;
    }

    try {
      final bool? available = await _channel.invokeMethod<bool>('isAvailable');
      if (available == true) {
        final bool? preloaded = await _channel.invokeMethod<bool>('preload');
        _isAvailable = preloaded == true;
        AppLogger.log(
          'Laya CoreML on Apple Neural Engine available: $_isAvailable',
          name: 'SemanticGrading',
        );
      } else {
        _isAvailable = false;
      }
    } catch (e) {
      AppLogger.log(
        'Laya CoreML initialization error: $e (falling back to fuzzy tiers)',
        name: 'SemanticGrading',
      );
      _isAvailable = false;
    }
  }

  /// Evaluates whether [spoken] is semantically correct for [expected].
  ///
  /// Returns null if Core ML is unavailable or encounters an error, allowing
  /// the caller to smoothly fall back to traditional Levenshtein fuzzy matching.
  Future<SemanticGradingResult?> evaluate({
    required String expected,
    required String spoken,
    String context = '',
    String locale = 'pt-PT',
  }) async {
    if (!_isAvailable) return null;

    try {
      final Map<dynamic, dynamic>? res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('evaluate', {
            'expected': expected,
            'spoken': spoken,
            'context': context,
            'locale': locale,
          });

      if (res != null) {
        final bool isCorrect = res['isCorrect'] as bool? ?? false;
        final double confidence =
            (res['confidence'] as num?)?.toDouble() ?? 0.0;
        final String errorType = res['errorType'] as String? ?? 'none';
        final String? feedback = res['feedbackMessage'] as String?;

        return SemanticGradingResult(
          isCorrect: isCorrect,
          confidence: confidence,
          errorType: errorType,
          feedbackMessage: feedback,
          usedNeuralEngine: true,
        );
      }
    } catch (e) {
      AppLogger.log('CoreML evaluation failed: $e', name: 'SemanticGrading');
    }
    return null;
  }
}
