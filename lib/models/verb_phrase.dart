class VerbPhrase {
  final String verb;
  final String portuguese;
  final String english;

  const VerbPhrase({
    required this.verb,
    required this.portuguese,
    required this.english,
  });

  factory VerbPhrase.fromJson(Map<String, dynamic> json) {
    return VerbPhrase(
      verb: json['verb'] as String,
      portuguese: json['portuguese'] as String,
      english: json['english'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'verb': verb, 'portuguese': portuguese, 'english': english};
  }
}
