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

            if (!_isLoading &&
                !ref.read(ttsServiceProvider).isEnhancedPtVoiceAvailable)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade900,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "High-quality voice not found",
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ref
                          .read(ttsServiceProvider)
                          .getVoiceInstallationInstructions(),
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

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
                    ref.read(ttsServiceProvider).speak(
                          "Hello, and testing one two three.",
                          language: 'en',
                        );
                  }
                },
              ),

            const SizedBox(height: 40),

            // Practice Reminders Section
            const Text(
              "Practice Reminders",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Receive a daily notification to keep your learning streak alive.",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Daily Reminder", style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _remindersEnabled
                    ? "Scheduled for ${_formatTime(_reminderHour, _reminderMinute)}"
                    : "Notifications are currently disabled",
              ),
              trailing: Switch(
                value: _remindersEnabled,
                onChanged: (val) => _toggleReminders(val),
              ),
            ),

            if (_remindersEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.access_time_rounded),
                  label: const Text("Change Reminder Time"),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _remindersEnabled => ref.read(storageServiceProvider).remindersEnabled;
  int get _reminderHour => ref.read(storageServiceProvider).reminderHour;
  int get _reminderMinute => ref.read(storageServiceProvider).reminderMinute;

  String _formatTime(int hour, int minute) {
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.format(context);
  }

  Future<void> _toggleReminders(bool enabled) async {
    final storage = ref.read(storageServiceProvider);
    final notifications = ref.read(notificationServiceProvider);

    if (enabled) {
      final granted = await notifications.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Notification permissions are required for reminders.")),
          );
        }
        return;
      }
    }

    await storage.setRemindersEnabled(enabled);
    await notifications.updateReminders();
    setState(() {});
  }

  Future<void> _pickTime() async {
    final storage = ref.read(storageServiceProvider);
    final notifications = ref.read(notificationServiceProvider);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _reminderHour, minute: _reminderMinute),
    );

    if (picked != null) {
      await storage.setReminderTime(picked.hour, picked.minute);
      await notifications.updateReminders();
      setState(() {});
    }
  }
}
