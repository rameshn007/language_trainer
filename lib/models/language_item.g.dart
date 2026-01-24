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
    );
  }

  @override
  void write(BinaryWriter writer, LanguageItem obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.lastReviewed);
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
