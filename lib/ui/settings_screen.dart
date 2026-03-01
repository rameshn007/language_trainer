import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart'; // for ttsServiceProvider and storageServiceProvider

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _selectedPtVoiceId;
  String? _selectedEnVoiceId;

  // Expose lists of voice maps to build simple dropdowns
  List<Map<String, String>> _ptVoices = [];
  List<Map<String, String>> _enVoices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVoices();
  }

  Future<void> _loadVoices() async {
    final tts = ref.read(ttsServiceProvider);
    final storage = ref.read(storageServiceProvider);

    if (tts.initFuture != null) {
      await tts.initFuture;
    }

    if (!mounted) return;

    setState(() {
      _ptVoices = tts.availablePtVoices;
      _enVoices = tts.availableEnVoices;

      // Pre-select current saved setting or default to first if none
      _selectedPtVoiceId =
          storage.getSetting('tts_voice_pt') as String? ??
          (_ptVoices.isNotEmpty ? _ptVoices.first["identifier"] : null);

      _selectedEnVoiceId =
          storage.getSetting('tts_voice_en') as String? ??
          (_enVoices.isNotEmpty ? _enVoices.first["identifier"] : null);

      _isLoading = false;
    });
  }

  Future<void> _saveSelection(String language, String identifier) async {
    final tts = ref.read(ttsServiceProvider);
    await tts.setExplicitVoice(language, identifier);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Voice Configuration",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Portuguese Dropdown
            const Text(
              "Portuguese Voice (Portugal)",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_ptVoices.isEmpty)
              const Text(
                "No valid Portuguese voices found.",
                style: TextStyle(color: Colors.red),
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                initialValue: _selectedPtVoiceId,
                items: _ptVoices.map((v) {
                  return DropdownMenuItem<String>(
                    value: v["identifier"],
                    child: Text(v["name"] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPtVoiceId = val);
                    _saveSelection('pt', val);

                    // Play a quick test
                    ref
                        .read(ttsServiceProvider)
                        .speak("Olá, como estás?", language: 'pt');
                  }
                },
              ),

            const SizedBox(height: 30),

            // English Dropdown
            const Text(
              "English Voice (US/UK)",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_enVoices.isEmpty)
              const Text(
                "No valid English voices found.",
                style: TextStyle(color: Colors.red),
              )
            else
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                initialValue: _selectedEnVoiceId,
                items: _enVoices.map((v) {
                  return DropdownMenuItem<String>(
                    value: v["identifier"],
                    child: Text(v["name"] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedEnVoiceId = val);
                    _saveSelection('en', val);

                    // Play a quick test
                    ref
                        .read(ttsServiceProvider)
                        .speak(
                          "Hello, and testing one two three.",
                          language: 'en',
                        );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
