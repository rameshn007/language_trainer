import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/verb.dart';
import '../../services/verb_service.dart';
import '../../main.dart';

final verbConjugationViewModelProvider =
    NotifierProvider<VerbConjugationViewModel, VerbConjugationState>(
      VerbConjugationViewModel.new,
    );

class VerbConjugationState {
  final List<Verb> verbs;
  final int currentVerbIndex;
  final bool isLoading;
  final Map<String, String> matchedPairs; // pronoun -> conjugation
  final List<String> shuffledConjugations;
  final String? selectedPronoun;
  final String? selectedConjugation;

  VerbConjugationState({
    required this.verbs,
    required this.currentVerbIndex,
    this.isLoading = false,
    this.matchedPairs = const {},
    this.shuffledConjugations = const [],
    this.selectedPronoun,
    this.selectedConjugation,
  });

  VerbConjugationState copyWith({
    List<Verb>? verbs,
    int? currentVerbIndex,
    bool? isLoading,
    Map<String, String>? matchedPairs,
    List<String>? shuffledConjugations,
    String? selectedPronoun,
    String? selectedConjugation,
    bool clearSelections = false,
  }) {
    return VerbConjugationState(
      verbs: verbs ?? this.verbs,
      currentVerbIndex: currentVerbIndex ?? this.currentVerbIndex,
      isLoading: isLoading ?? this.isLoading,
      matchedPairs: matchedPairs ?? this.matchedPairs,
      shuffledConjugations: shuffledConjugations ?? this.shuffledConjugations,
      selectedPronoun: clearSelections ? null : (selectedPronoun ?? this.selectedPronoun),
      selectedConjugation: clearSelections ? null : (selectedConjugation ?? this.selectedConjugation),
    );
  }

  Verb? get currentVerb {
    if (verbs.isEmpty) return null;
    return verbs[currentVerbIndex];
  }

  bool get isAllMatched {
    final verb = currentVerb;
    if (verb == null) return false;
    return matchedPairs.length == verb.conjugations.length;
  }
}

class VerbConjugationViewModel extends Notifier<VerbConjugationState> {
  final _random = Random();

  @override
  VerbConjugationState build() {
    Future.microtask(() => loadVerbs());
    return VerbConjugationState(verbs: [], currentVerbIndex: 0, isLoading: true);
  }

  Future<void> loadVerbs() async {
    state = state.copyWith(isLoading: true);
    final verbService = ref.read(verbServiceProvider);
    final verbs = await verbService.loadVerbs();
    verbs.shuffle(_random);
    state = state.copyWith(
      verbs: verbs,
      currentVerbIndex: 0,
      isLoading: false,
    );
    _setupCurrentVerb();
  }

  void _setupCurrentVerb() {
    final verb = state.currentVerb;
    if (verb == null) return;

    final conjugations = verb.conjugations.values.toList();
    conjugations.shuffle(_random);

    state = state.copyWith(
      matchedPairs: {},
      shuffledConjugations: conjugations,
      clearSelections: true,
    );
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
      final verb = state.currentVerb;
      if (verb == null) return;

      if (verb.conjugations[pronoun] == conjugation) {
        // Match!
        final newMatches = Map<String, String>.from(state.matchedPairs);
        newMatches[pronoun] = conjugation;
        state = state.copyWith(
          matchedPairs: newMatches,
          clearSelections: true,
        );
        
        // Speak the combo
        ref.read(ttsServiceProvider).speak('$pronoun $conjugation', language: 'pt');
      } else {
        // Mismatch, reset selections
        state = state.copyWith(clearSelections: true);
      }
    }
  }

  void nextVerb() {
    if (state.verbs.isEmpty) return;
    
    int nextIndex = state.currentVerbIndex + 1;
    if (nextIndex >= state.verbs.length) {
      // Loop back or end, here we loop back
      nextIndex = 0;
      // Reshuffle if repeating
      final newVerbs = List<Verb>.from(state.verbs)..shuffle(_random);
      state = state.copyWith(verbs: newVerbs, currentVerbIndex: nextIndex);
    } else {
      state = state.copyWith(currentVerbIndex: nextIndex);
    }
    
    _setupCurrentVerb();
  }
}
