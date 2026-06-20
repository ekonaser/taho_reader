import 'dart:typed_data';
import 'package:hive/hive.dart';

part 'archive_model.g.dart';

@HiveType(typeId: 1)
class ArchiveRecord extends HiveObject {
  @HiveField(0)
  late String cardNumber;

  @HiveField(1)
  late String driverName;

  @HiveField(2)
  late DateTime downloadDate;

  @HiveField(3)
  late Uint8List rawBytes;

  @HiveField(4)
  late bool isGen2;

  @HiveField(5)
  late String fileName;

  ArchiveRecord({
    required this.cardNumber,
    required this.driverName,
    required this.downloadDate,
    required this.rawBytes,
    required this.isGen2,
    required this.fileName,
  });
}
