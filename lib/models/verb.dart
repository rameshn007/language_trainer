class Verb {
  final String infinitive;
  final String translation;
  final Map<String, String> conjugations;

  Verb({
    required this.infinitive,
    required this.translation,
    required this.conjugations,
  });

  @override
  String toString() {
    return 'Verb(infinitive: $infinitive, translation: $translation, conjugations: $conjugations)';
  }
}
