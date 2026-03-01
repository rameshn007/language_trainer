import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  Map<String, String>? _bestPtVoice;
  Map<String, String>? _bestEnVoice;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    // 1. Get all available voices
    try {
      var voices = await _flutterTts.getVoices;

      if (Platform.isIOS) {
        await _flutterTts
            .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            ]);
      }

      // 2. Filter for Portuguese (Portugal)
      var ptVoices = voices.where((v) {
        final locale = v['locale'].toString();
        return locale.contains('pt-PT') || locale.contains('pt_PT');
      }).toList();

      if (ptVoices.isNotEmpty) {
        ptVoices.sort(
          (a, b) => _scoreVoice(b, 'pt').compareTo(_scoreVoice(a, 'pt')),
        );

        var bestVoice = ptVoices.first;
        _bestPtVoice = {
          "name": (bestVoice["name"] ?? "") as String,
          "locale": (bestVoice["locale"] ?? "") as String,
          "identifier": (bestVoice["identifier"] ?? "") as String,
        };
        // We do not set the default voice here, we set it individually in speak()
      }

      // 3. Filter and find best English (US/UK)
      var enVoices = voices.where((v) {
        final locale = v['locale'].toString().toLowerCase();
        return locale.contains('en-us') ||
            locale.contains('en_us') ||
            locale.contains('en-gb') ||
            locale.contains('en_gb');
      }).toList();

      if (enVoices.isNotEmpty) {
        enVoices.sort(
          (a, b) => _scoreVoice(b, 'en').compareTo(_scoreVoice(a, 'en')),
        );

        var bestVoice = enVoices.first;
        _bestEnVoice = {
          "name": (bestVoice["name"] ?? "") as String,
          "locale": (bestVoice["locale"] ?? "") as String,
          "identifier": (bestVoice["identifier"] ?? "") as String,
        };
      }
    } catch (e) {
      // Fallbacks
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

  // Helper to score voices
  int _scoreVoice(Map<Object?, Object?> v, String languageType) {
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

    // PT Specifics
    if (languageType == 'pt' && name.contains('joana')) {
      score += 5; // Joana is usually good on iOS
    }

    // EN Specifics
    if (languageType == 'en') {
      if (name.contains('siri') || id.contains('siri')) {
        score += 15; // Siri voices are generally the best
      }
      if (name.contains('samantha') && !name.contains('compact')) {
        score += 5; // Samantha is a standard good fallback
      }

      // EXPLICITLY PENALIZE NOVELTY/ROBOTIC MAC/IOS VOICES
      // Apple includes several novelty "singing" or "robotic" voices in the en-US pack.
      if (name.contains('zarvox') ||
          name.contains('cellos') ||
          name.contains('trinoids') ||
          name.contains('bad news') ||
          name.contains('good news') ||
          name.contains('bells') ||
          name.contains('boing') ||
          name.contains('bubbles') ||
          name.contains('deranged') ||
          name.contains('hysterical') ||
          name.contains('pipe organ') ||
          name.contains('whisper') ||
          name.contains('ralph') || // Novelty deep voice
          name.contains('albert')) {
        // Novelty raspy voice
        score -= 1000;
      }
    }

    // Penalize low quality
    if (name.contains('compact') || id.contains('compact')) {
      score -= 5;
    }

    return score;
  }

  Future<void> speak(String text, {String? language}) async {
    if (text.isEmpty) return;

    if (language != null) {
      if (language.startsWith('en')) {
        if (_bestEnVoice != null) {
          await _flutterTts.setVoice(_bestEnVoice!);
        } else {
          await _flutterTts.setLanguage('en-US');
        }
      } else if (language.startsWith('pt')) {
        if (_bestPtVoice != null) {
          await _flutterTts.setVoice(_bestPtVoice!);
        } else {
          await _flutterTts.setLanguage('pt-PT');
        }
      }
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
