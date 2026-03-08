import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'storage_service.dart';
import '../utils/logger.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final StorageService _storageService;

  Map<String, String>? _bestPtVoice;
  Map<String, String>? _bestEnVoice;

  List<Map<String, String>> availablePtVoices = [];
  List<Map<String, String>> availableEnVoices = [];

  bool get isEnhancedPtVoiceAvailable {
    return availablePtVoices.any((v) {
      final name = (v['name'] ?? '').toLowerCase();
      final id = (v['identifier'] ?? '').toLowerCase();
      return name.contains('enhanced') ||
          id.contains('enhanced') ||
          name.contains('premium') ||
          id.contains('premium');
    });
  }

  bool get isEnhancedPtVoiceSelected {
    if (_bestPtVoice == null) return false;
    final name = (_bestPtVoice!['name'] ?? '').toLowerCase();
    final id = (_bestPtVoice!['identifier'] ?? '').toLowerCase();
    return name.contains('enhanced') ||
        id.contains('enhanced') ||
        name.contains('premium') ||
        id.contains('premium');
  }

  Future<void>? initFuture;

  TtsService(this._storageService) {
    initFuture = _init();
  }

  Future<void> _init() async {
    try {
      if (Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts
            .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            ]);
        // slight delay to let audio session spin up
        await Future.delayed(const Duration(milliseconds: 50));
      }

      var voices = await _flutterTts.getVoices;

      // Retry logic for iOS because audio session can take time to spin up
      int retries = 0;
      while ((voices == null || voices.isEmpty) && retries < 3) {
        AppLogger.log(
          "getVoices returned empty, retrying... ($retries)",
          name: "TtsService",
        );
        await Future.delayed(const Duration(milliseconds: 200));
        voices = await _flutterTts.getVoices;
        retries++;
      }

      AppLogger.log(
        "getVoices returned ${voices?.length} voices",
        name: "TtsService",
      );

      if (voices == null || voices.isEmpty) {
        AppLogger.log("No voices found after retries!", name: "TtsService");
        return;
      }

      // 2. Filter for Portuguese
      var ptVoicesRaw = voices.where((v) {
        try {
          final locale = v['locale'].toString().toLowerCase();
          return locale.startsWith(
            'pt',
          ); // Just match any Portuguese to be safe, e.g. pt-PT, pt-BR, pt_PT
        } catch (e) {
          return false;
        }
      }).toList();

      AppLogger.log(
        "Found ${ptVoicesRaw.length} PT voices",
        name: "TtsService",
      );

      for (var v in ptVoicesRaw) {
        AppLogger.log(
          "PT Voice: ${v['name']} - ${v['identifier']} - ${v['quality']}",
          name: "TtsService",
        );
      }

      if (ptVoicesRaw.isNotEmpty) {
        ptVoicesRaw.sort(
          (a, b) => _scoreVoice(b, 'pt').compareTo(_scoreVoice(a, 'pt')),
        );

        // Store available voices for Settings
        availablePtVoices = ptVoicesRaw
            .map(
              (v) => {
                "name": (v["name"] ?? "") as String,
                "locale": (v["locale"] ?? "") as String,
                "identifier": (v["identifier"] ?? "") as String,
              },
            )
            .toList();

        // Check for saved preference
        final savedPtId = _storageService.getSetting('tts_voice_pt');
        if (savedPtId != null) {
          try {
            _bestPtVoice = availablePtVoices.firstWhere(
              (v) => v["identifier"] == savedPtId || v["name"] == savedPtId,
            );
          } catch (_) {
            _bestPtVoice =
                availablePtVoices.first; // fallback if saved not found
          }
        } else {
          _bestPtVoice = availablePtVoices.first;
        }
      }

      // 3. Filter and find best English
      var enVoicesRaw = voices.where((v) {
        try {
          final locale = v['locale'].toString().toLowerCase();
          return locale.startsWith('en'); // Just match any English
        } catch (e) {
          return false;
        }
      }).toList();

      AppLogger.log(
        "Found ${enVoicesRaw.length} EN voices",
        name: "TtsService",
      );

      if (enVoicesRaw.isNotEmpty) {
        enVoicesRaw.sort(
          (a, b) => _scoreVoice(b, 'en').compareTo(_scoreVoice(a, 'en')),
        );

        // Store available voices for Settings
        availableEnVoices = enVoicesRaw
            .map(
              (v) => {
                "name": (v["name"] ?? "") as String,
                "locale": (v["locale"] ?? "") as String,
                "identifier": (v["identifier"] ?? "") as String,
              },
            )
            .toList();

        // Check for saved preference
        final savedEnId = _storageService.getSetting('tts_voice_en');
        if (savedEnId != null) {
          try {
            _bestEnVoice = availableEnVoices.firstWhere(
              (v) => v["identifier"] == savedEnId || v["name"] == savedEnId,
            );
          } catch (_) {
            _bestEnVoice = availableEnVoices.first;
          }
        } else {
          _bestEnVoice = availableEnVoices.first;
        }
      }
    } catch (e) {
      // Fallbacks
    }

    await _flutterTts.setPitch(1.0);
    // 0.5 is standard speed for this lib, but let's make it slightly adjustable if needed.
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> setExplicitVoice(String language, String identifier) async {
    if (language.startsWith('pt')) {
      try {
        _bestPtVoice = availablePtVoices.firstWhere(
          (v) => v["identifier"] == identifier,
        );
        await _storageService.saveSetting('tts_voice_pt', identifier);
      } catch (_) {}
    } else if (language.startsWith('en')) {
      try {
        _bestEnVoice = availableEnVoices.firstWhere(
          (v) => v["identifier"] == identifier,
        );
        await _storageService.saveSetting('tts_voice_en', identifier);
      } catch (_) {}
    }
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
      // iOS blocks third-party apps from using Siri voices. Trying to set it falls back to a terrible robotic voice.
      if (name.contains('siri') || id.contains('siri')) {
        score -= 1000;
      }
      if (name.contains('samantha') && !name.contains('compact')) {
        score += 5; // Samantha is a standard good fallback
      }
      if (name.contains('alex') || name.contains('daniel')) {
        score += 10; // Alex and Daniel are excellent premium Apple voices
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

    if (initFuture != null) {
      await initFuture;
    }

    if (language != null) {
      if (language.startsWith('en')) {
        bool voiceSet = false;
        if (_bestEnVoice != null) {
          // Extra guard to prevent using a restricted Siri voice even if it was saved prior to the penalty update
          final name = (_bestEnVoice!['name'] ?? '').toLowerCase();
          final id = (_bestEnVoice!['identifier'] ?? '').toLowerCase();
          if (!name.contains('siri') && !id.contains('siri')) {
            try {
              final result = await _flutterTts.setVoice(_bestEnVoice!);
              if (result != 0 && result != false) voiceSet = true;
            } catch (_) {}
          }
        }
        if (!voiceSet) {
          await _flutterTts.setLanguage('en-US');
        }
      } else if (language.startsWith('pt')) {
        bool voiceSet = false;
        if (_bestPtVoice != null) {
          try {
            final result = await _flutterTts.setVoice(_bestPtVoice!);
            if (result != 0 && result != false) voiceSet = true;
          } catch (_) {}
        }
        if (!voiceSet) {
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
