// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'progress_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyRecordAdapter extends TypeAdapter<DailyRecord> {
  @override
  final int typeId = 4;

  @override
  DailyRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyRecord(
      date: fields[0] as String,
      xpEarned: fields[1] as int,
      sessionsCompleted: fields[2] as int,
      wordsReviewed: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyRecord obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.xpEarned)
      ..writeByte(2)
      ..write(obj.sessionsCompleted)
      ..writeByte(3)
      ..write(obj.wordsReviewed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SessionRecordAdapter extends TypeAdapter<SessionRecord> {
  @override
  final int typeId = 5;

  @override
  SessionRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SessionRecord(
      timestamp: fields[0] as DateTime,
      activityType: fields[1] as ActivityType,
      score: fields[2] as int,
      total: fields[3] as int,
      xpEarned: fields[4] as int,
      durationSeconds: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SessionRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.timestamp)
      ..writeByte(1)
      ..write(obj.activityType)
      ..writeByte(2)
      ..write(obj.score)
      ..writeByte(3)
      ..write(obj.total)
      ..writeByte(4)
      ..write(obj.xpEarned)
      ..writeByte(5)
      ..write(obj.durationSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WordProgressAdapter extends TypeAdapter<WordProgress> {
  @override
  final int typeId = 6;

  @override
  WordProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WordProgress(
      itemId: fields[0] as String,
      correctStreak: fields[1] as int,
      totalCorrect: fields[2] as int,
      totalWrong: fields[3] as int,
      lastReviewedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, WordProgress obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.itemId)
      ..writeByte(1)
      ..write(obj.correctStreak)
      ..writeByte(2)
      ..write(obj.totalCorrect)
      ..writeByte(3)
      ..write(obj.totalWrong)
      ..writeByte(4)
      ..write(obj.lastReviewedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ActivityTypeAdapter extends TypeAdapter<ActivityType> {
  @override
  final int typeId = 3;

  @override
  ActivityType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ActivityType.quiz;
      case 1:
        return ActivityType.vocabularyQuiz;
      case 2:
        return ActivityType.interrogativeQuiz;
      case 3:
        return ActivityType.verbConjugation;
      case 4:
        return ActivityType.phraseTrainer;
      case 5:
        return ActivityType.voiceTrainer;
      case 6:
        return ActivityType.sentenceBuilder;
      default:
        return ActivityType.quiz;
    }
  }

  @override
  void write(BinaryWriter writer, ActivityType obj) {
    switch (obj) {
      case ActivityType.quiz:
        writer.writeByte(0);
        break;
      case ActivityType.vocabularyQuiz:
        writer.writeByte(1);
        break;
      case ActivityType.interrogativeQuiz:
        writer.writeByte(2);
        break;
      case ActivityType.verbConjugation:
        writer.writeByte(3);
        break;
      case ActivityType.phraseTrainer:
        writer.writeByte(4);
        break;
      case ActivityType.voiceTrainer:
        writer.writeByte(5);
        break;
      case ActivityType.sentenceBuilder:
        writer.writeByte(6);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
