import 'package:hive/hive.dart';

part 'language_item.g.dart';

@HiveType(typeId: 0)
class LanguageItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String portuguese;

  @HiveField(2)
  final String english;

  @HiveField(3)
  final String notes;

  @HiveField(4)
  int masteryLevel; // 0 = New, 1-5 = Learned

  @HiveField(5)
  DateTime? lastReviewed;

  LanguageItem({
    required this.id,
    required this.portuguese,
    required this.english,
    this.notes = '',
    this.masteryLevel = 0,
    this.lastReviewed,
  });

  factory LanguageItem.fromMap(Map<String, String> map) {
    // Generate a simple ID based on the content or allow overwriting if we had a stable ID
    // For now, assume content is unique enough or we generate UUIDs during parsing
    return LanguageItem(
      id: '${map['Portuguese']}_${map['English']}'.replaceAll(' ', '_'),
      portuguese: map['Portuguese'] ?? '',
      english: map['English'] ?? '',
      notes: map['Notes'] ?? '',
    );
  }

  factory LanguageItem.empty() {
    return LanguageItem(id: 'empty', portuguese: '', english: '');
  }

  bool get isEmpty => portuguese.isEmpty && english.isEmpty;
}
