import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'listen_repeat_view_model.dart';

class ListenRepeatScreen extends ConsumerStatefulWidget {
  const ListenRepeatScreen({super.key});

  @override
  ConsumerState<ListenRepeatScreen> createState() => _ListenRepeatScreenState();
}

class _ListenRepeatScreenState extends ConsumerState<ListenRepeatScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(listenRepeatViewModelProvider.notifier).startSession();
    });
  }

  void _replayCurrentWord() {
    ref.read(listenRepeatViewModelProvider.notifier).replayCurrentWord();
  }

  void _nextWord() {
    ref.read(listenRepeatViewModelProvider.notifier).nextWord();
  }

  void _shufflePool() {
    ref.read(listenRepeatViewModelProvider.notifier).shufflePool();
  }

  void _stopSession() {
    ref.read(listenRepeatViewModelProvider.notifier).stopSession();
    if (mounted) {
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
          if (state.isPlaying)
            TextButton(onPressed: _stopSession, child: const Text('Stop')),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Word display
            if (item != null) ...[
              // AvatarGlow for audio playback feedback
              AvatarGlow(
                animate: isSpeaking,
                glowColor: Colors.blue.shade300,
                duration: const Duration(milliseconds: 2000),
                repeat: true,
                child: Container(
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
                      // Portuguese word
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
                      if (item.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          item.notes,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

              // Play audio button (manual override)
              AvatarGlow(
                animate: isSpeaking,
                glowColor: Theme.of(context).colorScheme.primary,
                duration: const Duration(milliseconds: 2000),
                repeat: true,
                child: ElevatedButton.icon(
                  onPressed: isSpeaking ? null : _replayCurrentWord,
                  icon: Icon(
                    isSpeaking ? Icons.pause : Icons.volume_up_rounded,
                  ),
                  label: Text(isSpeaking ? 'Speaking...' : 'Play Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Next word button
              ElevatedButton.icon(
                onPressed: _nextWord,
                icon: const Icon(Icons.forward_rounded),
                label: const Text('Next Word'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  textStyle: const TextStyle(fontSize: 18),
                ),
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
    );
  }
}
