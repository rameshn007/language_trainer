import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/verb.dart';
import '../../models/progress_data.dart';
import '../../services/verb_service.dart';
import '../../services/progress_service.dart';
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
  final int sessionScore;
  final int sessionTotal;
  final int sessionXP;
  final int verbsCompleted;

  VerbConjugationState({
    required this.verbs,
    required this.currentVerbIndex,
    this.isLoading = false,
    this.matchedPairs = const {},
    this.shuffledConjugations = const [],
    this.selectedPronoun,
    this.selectedConjugation,
    this.sessionScore = 0,
    this.sessionTotal = 0,
    this.sessionXP = 0,
    this.verbsCompleted = 0,
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
    int? sessionScore,
    int? sessionTotal,
    int? sessionXP,
    int? verbsCompleted,
  }) {
    return VerbConjugationState(
      verbs: verbs ?? this.verbs,
      currentVerbIndex: currentVerbIndex ?? this.currentVerbIndex,
      isLoading: isLoading ?? this.isLoading,
      matchedPairs: matchedPairs ?? this.matchedPairs,
      shuffledConjugations: shuffledConjugations ?? this.shuffledConjugations,
      selectedPronoun: clearSelections
          ? null
          : (selectedPronoun ?? this.selectedPronoun),
      selectedConjugation: clearSelections
          ? null
          : (selectedConjugation ?? this.selectedConjugation),
      sessionScore: sessionScore ?? this.sessionScore,
      sessionTotal: sessionTotal ?? this.sessionTotal,
      sessionXP: sessionXP ?? this.sessionXP,
      verbsCompleted: verbsCompleted ?? this.verbsCompleted,
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
  DateTime? _sessionStartTime;

  @override
  VerbConjugationState build() {
    Future.microtask(() => loadVerbs());
    return VerbConjugationState(
      verbs: [],
      currentVerbIndex: 0,
      isLoading: true,
    );
  }

  Future<void> loadVerbs() async {
    state = state.copyWith(isLoading: true);
    _sessionStartTime = DateTime.now();
    final verbService = ref.read(verbServiceProvider);
    final verbs = await verbService.loadVerbs();
    verbs.shuffle(_random);
    state = state.copyWith(
      verbs: verbs,
      currentVerbIndex: 0,
      isLoading: false,
      sessionScore: 0,
      sessionTotal: 0,
      sessionXP: 0,
      verbsCompleted: 0,
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

      final storage = ref.read(storageServiceProvider);
      final progressService = ref.read(progressServiceProvider.notifier);
      // Use the verb infinitive as the item id for progress tracking
      final itemId = 'verb_${verb.infinitive}';

      if (verb.conjugations[pronoun] == conjugation) {
        // Match!
        final newMatches = Map<String, String>.from(state.matchedPairs);
        newMatches[pronoun] = conjugation;
        state = state.copyWith(
          matchedPairs: newMatches,
          clearSelections: true,
          sessionScore: state.sessionScore + 1,
          sessionTotal: state.sessionTotal + 1,
        );

        // Record correct via progress service
        progressService
            .recordQuizAnswer(
              storage: storage,
              itemId: itemId,
              correct: true,
              firstAttempt: true,
            )
            .then((xp) {
              state = state.copyWith(sessionXP: state.sessionXP + xp);
            });

        // Speak the combo
        ref
            .read(ttsServiceProvider)
            .speak('$pronoun $conjugation', language: 'pt');

        // Check if all pairs matched → record verb completed
        if (newMatches.length == verb.conjugations.length) {
          state = state.copyWith(verbsCompleted: state.verbsCompleted + 1);
        }
      } else {
        // Mismatch, reset selections
        state = state.copyWith(
          clearSelections: true,
          sessionTotal: state.sessionTotal + 1,
        );

        // Record incorrect via progress service
        progressService
            .recordQuizAnswer(storage: storage, itemId: itemId, correct: false)
            .then((xp) {
              state = state.copyWith(sessionXP: state.sessionXP + xp);
            });
      }
    }
  }

  void nextVerb() {
    if (state.verbs.isEmpty) return;

    int nextIndex = state.currentVerbIndex + 1;
    if (nextIndex >= state.verbs.length) {
      // Record session completion before reshuffling
      _recordSessionComplete();
      // Loop back or end, here we loop back
      nextIndex = 0;
      // Reshuffle if repeating
      final newVerbs = List<Verb>.from(state.verbs)..shuffle(_random);
      state = state.copyWith(
        verbs: newVerbs,
        currentVerbIndex: nextIndex,
        sessionScore: 0,
        sessionTotal: 0,
        sessionXP: 0,
        verbsCompleted: 0,
      );
      _sessionStartTime = DateTime.now();
    } else {
      state = state.copyWith(currentVerbIndex: nextIndex);
    }

    _setupCurrentVerb();
  }

  Future<void> _recordSessionComplete() async {
    if (state.sessionTotal == 0) return;
    final storage = ref.read(storageServiceProvider);
    final progressService = ref.read(progressServiceProvider.notifier);
    final durationSec = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 0;

    await progressService.recordSessionComplete(
      storage: storage,
      activityType: ActivityType.verbConjugation,
      score: state.sessionScore,
      total: state.sessionTotal,
      durationSeconds: durationSec,
      sessionXP: state.sessionXP,
    );
  }
}
