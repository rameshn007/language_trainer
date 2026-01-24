import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    // 1. Get all available voices
    var voices = await _flutterTts.getVoices;

    try {
      // 2. Filter for Portuguese (Portugal)
      // Note: adjust locale check if needed (e.g., specific to 'pt-PT')
      var ptVoices = voices.where((v) {
        final locale = v['locale'].toString();
        return locale.contains('pt-PT') || locale.contains('pt_PT');
      }).toList();

      if (ptVoices.isNotEmpty) {
        // 3. Try to find a "high quality" voice

        // Strategy:
        // 1. Look for voices with 'enhanced', 'premium', 'high' in name/identifier/quality
        // 2. Prefer 'Joana' (common high quality PT voice on iOS)

        // 2. Prefer 'Joana' (common high quality PT voice on iOS)

        // Helper to score voices
        int scoreVoice(Map<Object?, Object?> v) {
          int score = 0;
          final name = (v['name'] ?? '').toString().toLowerCase();
          final id = (v['identifier'] ?? '').toString().toLowerCase();
          final quality = (v['quality'] ?? '').toString().toLowerCase();

          if (name.contains('enhanced') ||
              id.contains('enhanced') ||
              quality.contains('enhanced')) {
            score += 10;
          }
          if (name.contains('premium') ||
              id.contains('premium') ||
              quality.contains('premium')) {
            score += 10;
          }
          if (name.contains('joana')) {
            score += 5; // Joana is usually good on iOS
          }

          // Penalize compact
          if (name.contains('compact') || id.contains('compact')) score -= 5;

          return score;
        }

        // Sort by score descending
        ptVoices.sort((a, b) => scoreVoice(b).compareTo(scoreVoice(a)));

        var bestVoice = ptVoices.first;
        // print("Selected Best Voice: $bestVoice");

        await _flutterTts.setVoice({
          "name": (bestVoice["name"] ?? "") as String,
          "locale": (bestVoice["locale"] ?? "") as String,
          "identifier": (bestVoice["identifier"] ?? "") as String,
        });
      } else {
        // Fallback if no specific pt-PT voice found in list (rare)
        await _flutterTts.setLanguage("pt-PT");
      }
    } catch (e) {
      // print("Error setting voice: $e");
      // Fallback
      await _flutterTts.setLanguage("pt-PT");
    }

    await _flutterTts.setPitch(1.0);
    // 0.5 is standard speed for this lib, but let's make it slightly adjustable if needed.
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> setRate(double multiplier) async {
    // Base rate is 0.5 (as defined in original code as "good" speed)
    // We multiply that by the user's preference.
    // Example: 0.8x -> 0.4 actual rate.
    // Clamp to reasonable limits (0.0 to 1.0) for flutter_tts
    double rate = (0.5 * multiplier).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(rate);
  }

  String getVoiceInstallationInstructions() {
    if (Platform.isIOS) {
      return "To get the best quality Portuguese voice:\n\n"
          "1. Open device **Settings**.\n"
          "2. Go to **Accessibility** -> **Spoken Content**.\n"
          "3. Tap **Voices**.\n"
          "4. Select **Portuguese**.\n"
          "5. Select **Joana (Enhanced)**.\n"
          "   (You may need to download it nearby if not installed).\n\n"
          "Once downloaded, restart this app.";
    } else if (Platform.isAndroid) {
      return "To get the best quality Portuguese voice:\n\n"
          "1. Open device **Settings**.\n"
          "2. Search for **Text-to-speech output**.\n"
          "3. Tap the **Gear icon** next to the preferred engine (usually Google).\n"
          "4. Tap **Install voice data**.\n"
          "5. Select **Portuguese (Portugal)**.\n"
          "6. Download a high-quality voice pack if available.\n\n"
          "Note: Some Android devices might use Samsung TTS engine which has its own store.";
    }
    return "Please check your system Text-to-Speech settings to install high-quality voices.";
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
