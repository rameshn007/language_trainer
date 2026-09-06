import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'listen_repeat_view_model.dart';
import '../../services/listen_repeat_content_service.dart';
import '../widgets/xp_popup.dart';

class ListenRepeatScreen extends ConsumerStatefulWidget {
  const ListenRepeatScreen({super.key});

  @override
  ConsumerState<ListenRepeatScreen> createState() => _ListenRepeatScreenState();
}

class _ListenRepeatScreenState extends ConsumerState<ListenRepeatScreen> {
  ListenRepeatViewModel? _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ref.read(listenRepeatViewModelProvider.notifier);
    debugPrint('ListenRepeatScreen.initState - scheduling startSession');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('ListenRepeatScreen.postFrameCallback - calling startSession');
      _viewModel?.startSession();
    });
  }

  @override
  void dispose() {
    debugPrint('ListenRepeatScreen.dispose - stopping session');
    try {
      _viewModel?.stopSession();
    } catch (e) {
      debugPrint('Error stopping session on dispose: $e');
    }
    super.dispose();
  }

  void _previousWord() {
    ref.read(listenRepeatViewModelProvider.notifier).previousWord();
  }

  Future<void> _togglePlayPause() async {
    await ref.read(listenRepeatViewModelProvider.notifier).togglePlayPause();
  }

  void _nextWord() {
    ref.read(listenRepeatViewModelProvider.notifier).nextWord();
  }

  void _shufflePool() {
    ref.read(listenRepeatViewModelProvider.notifier).shufflePool();
  }

  void _retrySession() {
    // startSession() is a no-op while a session is already running, so this is
    // only reachable from the failure state.
    ref.read(listenRepeatViewModelProvider.notifier).startSession();
  }

  void _stopSession() async {
    final xp = await ref.read(listenRepeatViewModelProvider.notifier).stopSession();
    if (mounted) {
      if (xp > 0) {
        XPPopup.show(context, xp);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(listenRepeatViewModelProvider);
    final item = state.currentItem;
    final isSpeaking = state.isSpeaking;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Listen & Repeat'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.speed, size: 20),
            label: Text("${state.playbackSpeed}x"),
            onPressed: () {
              final newSpeed = ref.read(listenRepeatViewModelProvider.notifier).cycleSpeed();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Speed: ${newSpeed}x"),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          if (state.isPlaying)
            TextButton(onPressed: _stopSession, child: const Text('Stop')),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Content Focus Selector
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ListenRepeatMode.values.map((mode) {
                      final isSelected = state.mode == mode;
                      final isStarting = state.isPlaying && state.currentItem == null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text(mode.label),
                          onSelected: isStarting
                              ? null
                              : (selected) {
                                  if (selected) {
                                    ref.read(listenRepeatViewModelProvider.notifier).setMode(mode);
                                  }
                                },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Word display
              if (item != null) ...[
                // AvatarGlow for audio playback feedback
                AvatarGlow(
                  animate: isSpeaking,
                  glowColor: Colors.blue.shade300,
                  duration: const Duration(milliseconds: 2000),
                  repeat: true,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Grammar / Tense Badge
                        if (item.notes.isNotEmpty) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.notes,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        // Portuguese word / phrase
                        Text(
                          item.portuguese,
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        // English translation
                        Text(
                          item.english,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Auto-playing ...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

              // Playback controls row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous button
                  ElevatedButton.icon(
                    onPressed: _previousWord,
                    icon: const Icon(Icons.skip_previous_rounded),
                    label: const Text('Prev'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Play/Pause button
                  AvatarGlow(
                    animate: isSpeaking,
                    glowColor: Theme.of(context).colorScheme.primary,
                    duration: const Duration(milliseconds: 2000),
                    repeat: true,
                    child: ElevatedButton.icon(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        state.isPlaying ? Icons.pause : Icons.play_arrow_rounded,
                      ),
                      label: Text(state.isPlaying ? 'Pause' : 'Play'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Next button
                  ElevatedButton.icon(
                    onPressed: _nextWord,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Shuffle and Stop row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _shufflePool,
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Shuffle'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _stopSession,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Word counter
              Text(
                'Word ${state.totalWordsSeen}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (state.isPlaying) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Loading words...'),
            ] else if (state.failure != null) ...[
              Icon(
                Icons.error_outline_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Listen & Repeat is not working',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  state.failure!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retrySession,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              const SizedBox(height: 10),
              Text(
                'Or go back and reopen the screen.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Icon(
                Icons.headset_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No words loaded',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add vocabulary words to get started',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );}
}
