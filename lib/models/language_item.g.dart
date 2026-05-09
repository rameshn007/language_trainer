// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LanguageItemAdapter extends TypeAdapter<LanguageItem> {
  @override
  final int typeId = 0;

  @override
  LanguageItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LanguageItem(
      id: fields[0] as String,
      portuguese: fields[1] as String,
      english: fields[2] as String,
      notes: fields[3] as String,
      masteryLevel: fields[4] as int,
      lastReviewed: fields[5] as DateTime?,
      pronunciation: fields[6] as String?,
      wordType: fields[7] as String?,
      cefrLevel: fields[8] as String?,
      topicCategory: fields[9] as String?,
      exampleSentencePt: fields[10] as String?,
      exampleSentenceEn: fields[11] as String?,
      gender: fields[12] as String?,
      plural: fields[13] as String?,
      irregular: fields[14] as bool?,
      verbClass: fields[15] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LanguageItem obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.portuguese)
      ..writeByte(2)
      ..write(obj.english)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.masteryLevel)
      ..writeByte(5)
      ..write(obj.lastReviewed)
      ..writeByte(6)
      ..write(obj.pronunciation)
      ..writeByte(7)
      ..write(obj.wordType)
      ..writeByte(8)
      ..write(obj.cefrLevel)
      ..writeByte(9)
      ..write(obj.topicCategory)
      ..writeByte(10)
      ..write(obj.exampleSentencePt)
      ..writeByte(11)
      ..write(obj.exampleSentenceEn)
      ..writeByte(12)
      ..write(obj.gender)
      ..writeByte(13)
      ..write(obj.plural)
      ..writeByte(14)
      ..write(obj.irregular)
      ..writeByte(15)
      ..write(obj.verbClass);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
