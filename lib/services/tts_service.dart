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
      // iOS 17+ also sometimes requires speaking an empty string to wake up the engine
      if (Platform.isIOS) {
        try {
          await _flutterTts.speak("");
        } catch (_) {}
      }

      int retries = 0;
      while ((voices == null || voices.isEmpty) && retries < 10) {
        AppLogger.log(
          "getVoices returned empty, retrying... ($retries)",
          name: "TtsService",
        );
        await Future.delayed(const Duration(milliseconds: 300));
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
          final name = v['name'].toString().toLowerCase();
          return locale.startsWith('pt') || name.contains('joana') || name.contains('luciana');
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
          final name = v['name'].toString().toLowerCase();
          return locale.startsWith('en') || name.contains('fred') || name.contains('samantha') || name.contains('daniel');
        } catch (e) {
          return false;
        }
      }).toList();

      AppLogger.log(
        "Found ${enVoicesRaw.length} EN voices",
        name: "TtsService",
      );

      for (var v in enVoicesRaw) {
        AppLogger.log(
          "EN Voice: ${v['name']} - ${v['identifier']} - ${v['quality']}",
          name: "TtsService",
        );
      }

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
      return "To get the best quality voices:\n\n"
          "1. Open device **Settings**.\n"
          "2. Go to **Accessibility** -> **Live Speech**.\n"
          "3. Under **Preferred Voices**, tap **Add Preferred Voice...**\n"
          "4. For Portuguese, select **Joana**.\n"
          "5. For English, select **Samantha**, **Alex**, or **Daniel**.\n"
          "   (You may need to download them if not installed).\n\n"
          "Once downloaded, restart this app.";
    } else if (Platform.isAndroid) {
      return "To get the best quality voices:\n\n"
          "1. Open device **Settings**.\n"
          "2. Search for **Text-to-speech output**.\n"
          "3. Tap the **Gear icon** next to the preferred engine.\n"
          "4. Tap **Install voice data**.\n"
          "5. Download high-quality voice packs for Portuguese and English.\n\n"
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
      score += 20; // Joana is our recommended preferred voice
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
          name.contains('fred') || // Classic Mac robot voice
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

  /// Dynamically find the best available voice for a language by querying
  /// the system at speak-time. This avoids stale cached data and guessed identifiers.
  Future<Map<String, String>?> _findBestAvailableVoice(String langPrefix) async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices == null || voices.isEmpty) return null;

      final matching = voices.where((v) {
        try {
          final locale = v['locale'].toString().toLowerCase();
          return locale.startsWith(langPrefix);
        } catch (_) {
          return false;
        }
      }).toList();

      if (matching.isEmpty) return null;

      // Sort by score to pick the best
      matching.sort(
        (a, b) => _scoreVoice(b, langPrefix).compareTo(_scoreVoice(a, langPrefix)),
      );

      final best = matching.first;
      AppLogger.log(
        "Dynamic voice pick for '$langPrefix': ${best['name']} (${best['identifier']}) quality=${best['quality']} score=${_scoreVoice(best, langPrefix)}",
        name: "TtsService",
      );

      return {
        "name": (best["name"] ?? "") as String,
        "locale": (best["locale"] ?? "") as String,
        "identifier": (best["identifier"] ?? "") as String,
      };
    } catch (e) {
      AppLogger.log("Error finding voice for $langPrefix: $e", name: "TtsService");
      return null;
    }
  }

  Future<void> speak(String text, {String? language}) async {
    if (text.isEmpty) return;

    if (initFuture != null) {
      await initFuture;
    }

    if (language != null) {
      if (language.startsWith('en')) {
        // Always set language first as a baseline — this ensures we never
        // fall through to the device's default language (which might be
        // Portuguese or something else entirely).
        await _flutterTts.setLanguage('en-US');

        bool voiceSet = false;

        // 1. Try the cached best voice (from init or user selection)
        if (_bestEnVoice != null) {
          final name = (_bestEnVoice!['name'] ?? '').toLowerCase();
          final id = (_bestEnVoice!['identifier'] ?? '').toLowerCase();
          if (!name.contains('siri') && !id.contains('siri')) {
            try {
              AppLogger.log(
                "EN: Trying cached voice: ${_bestEnVoice!['name']} (${_bestEnVoice!['identifier']})",
                name: "TtsService",
              );
              final result = await _flutterTts.setVoice(_bestEnVoice!);
              if (result == 1) voiceSet = true;
            } catch (_) {}
          }
        }

        // 2. If cached voice failed, dynamically query available voices
        if (!voiceSet) {
          AppLogger.log("EN: Cached voice failed, querying system voices dynamically...", name: "TtsService");
          final dynamicVoice = await _findBestAvailableVoice('en');
          if (dynamicVoice != null) {
            try {
              final result = await _flutterTts.setVoice(dynamicVoice);
              if (result == 1) {
                voiceSet = true;
                AppLogger.log("EN: Dynamic voice set successfully: ${dynamicVoice['name']}", name: "TtsService");
              }
            } catch (_) {}
          }
        }

        if (!voiceSet) {
          AppLogger.log("EN: All voice attempts failed, using setLanguage('en-US') only", name: "TtsService");
        }

      } else if (language.startsWith('pt')) {
        await _flutterTts.setLanguage('pt-PT');

        bool voiceSet = false;

        if (_bestPtVoice != null) {
          try {
            AppLogger.log(
              "PT: Trying cached voice: ${_bestPtVoice!['name']} (${_bestPtVoice!['identifier']})",
              name: "TtsService",
            );
            final result = await _flutterTts.setVoice(_bestPtVoice!);
            if (result == 1) voiceSet = true;
          } catch (_) {}
        }

        if (!voiceSet) {
          AppLogger.log("PT: Cached voice failed, querying system voices dynamically...", name: "TtsService");
          final dynamicVoice = await _findBestAvailableVoice('pt');
          if (dynamicVoice != null) {
            try {
              final result = await _flutterTts.setVoice(dynamicVoice);
              if (result == 1) {
                voiceSet = true;
                AppLogger.log("PT: Dynamic voice set successfully: ${dynamicVoice['name']}", name: "TtsService");
              }
            } catch (_) {}
          }
        }

        if (!voiceSet) {
          AppLogger.log("PT: All voice attempts failed, using setLanguage('pt-PT') only", name: "TtsService");
        }
      }
    }

    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
