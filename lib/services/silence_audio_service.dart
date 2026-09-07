import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../models/language_item.dart';
import '../utils/logger.dart';

class SilenceAudioService {
  SilenceAudioService._();

  /// Calculates the expected byte size of a 16-bit mono PCM WAV file.
  static int calculateExpectedWavBytes(double durationSeconds, {int sampleRate = 44100}) {
    const int channels = 1;
    const int bitsPerSample = 16;
    final int numSamples = (sampleRate * durationSeconds).round();
    final int dataSize = numSamples * channels * (bitsPerSample ~/ 8);
    return 44 + dataSize;
  }

  /// Calculates the recommended pause between words (after English before next Portuguese).
  ///
  /// For short single words, provides a comfortable 1.4s pause (close to legacy ~1.05s).
  /// For longer phrases, dynamically scales up to 2.4s max so learners have time to absorb
  /// the translation without creating long dead air that feels like playback stalled.
  static double calculateBetweenWordsPause(LanguageItem item) {
    final pt = item.portuguese.trim();
    final words = pt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = pt.length;

    if (words <= 2 && chars <= 16) {
      return 1.4;
    }

    final extraFromWords = (words - 2) * 0.25;
    final extraFromChars = chars > 25 ? 0.3 : (chars > 16 ? 0.15 : 0.0);
    final total = (1.4 + extraFromWords + extraFromChars).clamp(1.4, 2.4);
    return double.parse(total.toStringAsFixed(1));
  }

  /// Calculates the recommended repetition pause (after Portuguese before English).
  ///
  /// Base is 2.0s for single words (legacy was 2.09s), scaling up to 3.4s for long phrases
  /// so learners have ample time to repeat multi-word utterances without dead air.
  static double calculateRepetitionPause(LanguageItem item) {
    final pt = item.portuguese.trim();
    final words = pt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    final chars = pt.length;

    if (words <= 2 && chars <= 16) {
      return 2.0;
    }

    final extraFromWords = (words - 2) * 0.3;
    final extraFromChars = chars > 25 ? 0.3 : (chars > 16 ? 0.15 : 0.0);
    final total = (2.0 + extraFromWords + extraFromChars).clamp(2.0, 3.4);
    return double.parse(total.toStringAsFixed(1));
  }

  /// Creates raw PCM 16-bit 44.1kHz mono WAV bytes representing silence for [durationSeconds].
  static Uint8List createWavSilenceBytes(double durationSeconds, {int sampleRate = 44100}) {
    const int channels = 1;
    const int bitsPerSample = 16;
    final int numSamples = (sampleRate * durationSeconds).round();
    final int dataSize = numSamples * channels * (bitsPerSample ~/ 8);
    final int fileSize = 36 + dataSize;

    final header = ByteData(44);
    // 'RIFF'
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    // 'WAVE'
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    // 'fmt '
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6d);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    header.setUint16(20, 1, Endian.little);  // AudioFormat (1 for PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, sampleRate * channels * (bitsPerSample ~/ 8), Endian.little);
    header.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // 'data'
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final fullBytes = Uint8List(44 + dataSize);
    fullBytes.setRange(0, 44, header.buffer.asUint8List());
    // The rest of fullBytes is already 0-initialized
    return fullBytes;
  }

  /// Retrieves or creates a silence WAV file on disk for [durationSeconds].
  ///
  /// Caches the file in [targetDir] (or temporary directory) so subsequent calls
  /// for the same duration reuse the pre-generated file. Writes atomically via a
  /// temporary file and verifies exact byte size to protect against corrupt or
  /// truncated files.
  static Future<String> getSilenceFilePath({
    required double durationSeconds,
    Directory? targetDir,
  }) async {
    try {
      final dir = targetDir ?? await getTemporaryDirectory();
      final ms = (durationSeconds * 1000).round();
      final filePath = '${dir.path}/silence_${ms}ms.wav';
      final file = File(filePath);
      final expectedBytes = calculateExpectedWavBytes(durationSeconds);

      if (file.existsSync()) {
        if (file.lengthSync() == expectedBytes) {
          return filePath;
        }
        // File exists but size does not match expected length (truncated/corrupt). Delete it.
        AppLogger.log('[Silence] Evicting corrupted/invalid silence WAV: $filePath', name: 'SilenceAudioService');
        try {
          file.deleteSync();
        } catch (_) {}
      }

      final bytes = createWavSilenceBytes(durationSeconds);
      // Atomic write: write to temp file then rename
      final tempFilePath = '$filePath.tmp_${DateTime.now().microsecondsSinceEpoch}';
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(bytes, flush: true);
      await tempFile.rename(filePath);

      AppLogger.log('[Silence] Created silence WAV ($durationSeconds s): $filePath', name: 'SilenceAudioService');
      return filePath;
    } catch (e) {
      AppLogger.error('Failed to create silence WAV file', name: 'SilenceAudioService', error: e);
      rethrow;
    }
  }
}
