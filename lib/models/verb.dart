class Verb {
  final String infinitive;
  final String translation;
  final Map<String, String> conjugations;
  final Map<String, String>? pastConjugations;

  Verb({
    required this.infinitive,
    required this.translation,
    required this.conjugations,
    this.pastConjugations,
  });

  @override
  String toString() {
    return 'Verb(infinitive: $infinitive, translation: $translation, conjugations: $conjugations, pastConjugations: $pastConjugations)';
  }
}
