import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/verb.dart';
import '../../services/verb_service.dart';
import '../../main.dart';

class SingleVerbConjugationState {
  final Verb? verb;
  final bool isLoading;
  final String? error;
  final Map<String, String> matchedPairs;
  final List<String> shuffledConjugations;
  final String? selectedPronoun;
  final String? selectedConjugation;

  const SingleVerbConjugationState({
    this.verb,
    this.isLoading = false,
    this.error,
    this.matchedPairs = const {},
    this.shuffledConjugations = const [],
    this.selectedPronoun,
    this.selectedConjugation,
  });

  SingleVerbConjugationState copyWith({
    Verb? verb,
    bool? isLoading,
    String? error,
    Map<String, String>? matchedPairs,
    List<String>? shuffledConjugations,
    String? selectedPronoun,
    String? selectedConjugation,
    bool clearSelections = false,
  }) {
    return SingleVerbConjugationState(
      verb: verb ?? this.verb,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      matchedPairs: matchedPairs ?? this.matchedPairs,
      shuffledConjugations: shuffledConjugations ?? this.shuffledConjugations,
      selectedPronoun: clearSelections ? null : (selectedPronoun ?? this.selectedPronoun),
      selectedConjugation: clearSelections ? null : (selectedConjugation ?? this.selectedConjugation),
    );
  }

  bool get isAllMatched {
    if (verb == null) return false;
    return matchedPairs.length == verb!.conjugations.length;
  }
}

final singleVerbConjugationViewModelProvider =
    NotifierProvider<SingleVerbConjugationViewModel, SingleVerbConjugationState>(
  SingleVerbConjugationViewModel.new,
);

class SingleVerbConjugationViewModel extends Notifier<SingleVerbConjugationState> {
  final _random = Random();

  @override
  SingleVerbConjugationState build() {
    return const SingleVerbConjugationState(isLoading: true);
  }

  Future<void> loadVerb(String verbInfinitive) async {
    // Reset state freshly every time a new verb is requested
    state = const SingleVerbConjugationState(isLoading: true);
    
    try {
      final verbService = ref.read(verbServiceProvider);
      final allVerbs = await verbService.loadVerbs();
      
      final normalizedTarget = verbInfinitive.trim().toLowerCase();
      final verb = allVerbs.firstWhere(
        (v) => v.infinitive.trim().toLowerCase() == normalizedTarget,
        orElse: () => throw Exception('Verb not found'),
      );

      final conjugations = verb.conjugations.values.toList();
      conjugations.shuffle(_random);

      state = state.copyWith(
        verb: verb,
        isLoading: false,
        shuffledConjugations: conjugations,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Conjugations not available for this verb.',
      );
    }
  }

  void selectPronoun(String pronoun) {
    if (state.matchedPairs.containsKey(pronoun)) return;

    if (state.selectedPronoun == pronoun) {
      state = state.copyWith(selectedPronoun: null, clearSelections: false);
    } else {
      state = state.copyWith(selectedPronoun: pronoun);
      _checkMatch();
    }
  }

  void selectConjugation(String conjugation) {
    if (state.matchedPairs.containsValue(conjugation)) return;

    if (state.selectedConjugation == conjugation) {
      state = state.copyWith(selectedConjugation: null, clearSelections: false);
    } else {
      state = state.copyWith(selectedConjugation: conjugation);
      _checkMatch();
    }
  }

  void _checkMatch() {
    final pronoun = state.selectedPronoun;
    final conjugation = state.selectedConjugation;

    if (pronoun != null && conjugation != null) {
      final verb = state.verb;
      if (verb == null) return;

      if (verb.conjugations[pronoun] == conjugation) {
        final newMatches = Map<String, String>.from(state.matchedPairs);
        newMatches[pronoun] = conjugation;
        state = state.copyWith(
          matchedPairs: newMatches,
          clearSelections: true,
        );
        ref.read(ttsServiceProvider).speak('$pronoun $conjugation', language: 'pt');
      } else {
        state = state.copyWith(clearSelections: true);
      }
    }
  }
}
