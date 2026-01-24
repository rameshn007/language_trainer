import 'package:hive/hive.dart';
import 'language_item.dart';

part 'question.g.dart';

@HiveType(typeId: 1)
enum QuestionType {
  @HiveField(0)
  multipleChoice,
  @HiveField(1)
  cloze,
  @HiveField(2)
  jumble,
  @HiveField(3)
  trueFalse,
}

@HiveType(typeId: 2)
class Question {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String questionText;
  @HiveField(2)
  final List<String> options;
  @HiveField(3)
  final String correctAnswer;
  @HiveField(4)
  final QuestionType type;
  @HiveField(5)
  final LanguageItem sourceItem;
  @HiveField(6)
  final String? category;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    required this.type,
    required this.sourceItem,
    this.category,
  });
}
