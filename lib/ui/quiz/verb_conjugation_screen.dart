import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../main.dart';
import 'verb_conjugation_view_model.dart';
import '../../models/verb.dart';

class VerbConjugationScreen extends ConsumerStatefulWidget {
  const VerbConjugationScreen({super.key});

  @override
  ConsumerState<VerbConjugationScreen> createState() =>
      _VerbConjugationScreenState();
}

class _VerbConjugationScreenState extends ConsumerState<VerbConjugationScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verbConjugationViewModelProvider);
    final viewModel = ref.read(verbConjugationViewModelProvider.notifier);

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verb Conjugator')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final verb = state.currentVerb;
    if (verb == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verb Conjugator')),
        body: const Center(child: Text('No verbs found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verb Conjugator'),
        centerTitle: true,
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            // Swipe left
            viewModel.nextVerb();
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Infinitive verb + TTS)
                _buildVerbHeader(verb),
                const SizedBox(height: 30),

                // Matching Game Area
                Expanded(
                  child: Row(
                    children: [
                      // Pronoun Column
                      Expanded(
                        child: Column(
                          children: verb.conjugations.keys.map((pronoun) {
                            final isMatched =
                                state.matchedPairs.containsKey(pronoun);
                            final isSelected =
                                state.selectedPronoun == pronoun;
                            return Expanded(
                              child: _MatchButton(
                                text: pronoun,
                                isMatched: isMatched,
                                isSelected: isSelected,
                                onTap: () => viewModel.selectPronoun(pronoun),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Conjugation Column
                      Expanded(
                        child: Column(
                          children:
                              state.shuffledConjugations.map((conjugation) {
                            final isMatched =
                                state.matchedPairs.containsValue(conjugation);
                            final isSelected =
                                state.selectedConjugation == conjugation;
                            return Expanded(
                              child: _MatchButton(
                                text: conjugation,
                                isMatched: isMatched,
                                isSelected: isSelected,
                                onTap: () =>
                                    viewModel.selectConjugation(conjugation),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Score indicator
                if (state.sessionTotal > 0)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        '${state.sessionScore} / ${state.sessionTotal} correct  •  ${state.sessionXP} XP',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

              // Footer (Translation & Next Button when all matched)
              SizedBox(
                height: 120, // fixed height to avoid layout jump
                child: state.isAllMatched
                    ? FadeInUp(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              verb.translation,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => viewModel.nextVerb(),
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Next Verb'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerbHeader(Verb verb) {
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              verb.infinitive,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.volume_up, size: 28),
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.deepPurple.shade100 
                  : Theme.of(context).primaryColor,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                ref.read(ttsServiceProvider).speak(
                      verb.infinitive,
                      language: 'pt',
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchButton extends StatelessWidget {
  final String text;
  final bool isMatched;
  final bool isSelected;
  final VoidCallback onTap;

  const _MatchButton({
    required this.text,
    required this.isMatched,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedColor = isDark ? theme.colorScheme.primary : theme.primaryColor;
    final onSelectedColor = isDark ? theme.colorScheme.onPrimary : Colors.white;

    final color = isMatched
        ? Colors.green.withValues(alpha: 0.8)
        : (isSelected ? selectedColor : theme.cardColor);

    final textColor = isMatched
        ? Colors.white
        : (isSelected 
            ? onSelectedColor 
            : (theme.textTheme.bodyLarge?.color ?? Colors.black));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        elevation: isMatched ? 1 : (isDark ? 0 : 4),
        child: InkWell(
          onTap: isMatched ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: isMatched
                    ? Colors.green
                    : (isSelected 
                        ? selectedColor 
                        : (isDark ? theme.colorScheme.outlineVariant : Colors.grey.withValues(alpha: 0.3))),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
