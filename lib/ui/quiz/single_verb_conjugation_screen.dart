import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';

import '../../main.dart';
import 'single_verb_conjugation_view_model.dart';
import '../../models/verb.dart';

class SingleVerbConjugationScreen extends ConsumerStatefulWidget {
  final String verbInfinitive;
  final String returnText;

  const SingleVerbConjugationScreen({
    super.key,
    required this.verbInfinitive,
    this.returnText = 'Return to Flashcards',
  });

  @override
  ConsumerState<SingleVerbConjugationScreen> createState() =>
      _SingleVerbConjugationScreenState();
}

class _SingleVerbConjugationScreenState extends ConsumerState<SingleVerbConjugationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(singleVerbConjugationViewModelProvider.notifier).loadVerb(widget.verbInfinitive);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(singleVerbConjugationViewModelProvider);
    final viewModel = ref.read(singleVerbConjugationViewModelProvider.notifier);

    if (state.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conjugation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conjugation')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(widget.returnText),
                )
              ],
            ),
          ),
        ),
      );
    }

    final verb = state.verb;
    if (verb == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conjugation')),
        body: const Center(child: Text('Verb not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(verb.infinitive.toUpperCase()),
        centerTitle: true,
      ),
      body: SafeArea(
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
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.check_circle),
                              label: Text(widget.returnText),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
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
    );
  }

  Widget _buildVerbHeader(Verb verb) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark 
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) 
              : Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              verb.infinitive,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Theme.of(context).colorScheme.primary : Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.volume_up, size: 28),
              color: isDark 
                  ? Theme.of(context).colorScheme.primary 
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
