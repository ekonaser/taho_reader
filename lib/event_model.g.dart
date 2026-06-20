// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DriverEventAdapter extends TypeAdapter<DriverEvent> {
  @override
  final int typeId = 0;

  @override
  DriverEvent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DriverEvent(
      date: fields[0] as DateTime,
      type: fields[1] as String,
      description: fields[2] as String,
      location: fields[3] as String?,
      tags: (fields[4] as List?)?.cast<String>(),
      googleEventId: fields[5] as String?,
      latitude: fields[6] as double?,
      longitude: fields[7] as double?,
      endDate: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DriverEvent obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.location)
      ..writeByte(4)
      ..write(obj.tags)
      ..writeByte(5)
      ..write(obj.googleEventId)
      ..writeByte(6)
      ..write(obj.latitude)
      ..writeByte(7)
      ..write(obj.longitude)
      ..writeByte(8)
      ..write(obj.endDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverEventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
