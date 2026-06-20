// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArchiveRecordAdapter extends TypeAdapter<ArchiveRecord> {
  @override
  final int typeId = 1;

  @override
  ArchiveRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArchiveRecord(
      cardNumber: fields[0] as String,
      driverName: fields[1] as String,
      downloadDate: fields[2] as DateTime,
      rawBytes: fields[3] as Uint8List,
      isGen2: fields[4] as bool,
      fileName: fields[5] as String,
    );
  }

  @override
  void write(BinaryWriter writer, ArchiveRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.cardNumber)
      ..writeByte(1)
      ..write(obj.driverName)
      ..writeByte(2)
      ..write(obj.downloadDate)
      ..writeByte(3)
      ..write(obj.rawBytes)
      ..writeByte(4)
      ..write(obj.isGen2)
      ..writeByte(5)
      ..write(obj.fileName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArchiveRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
