import 'package:hive/hive.dart';

part 'event_model.g.dart';

@HiveType(typeId: 0)
class DriverEvent extends HiveObject {
  @HiveField(0)
  late DateTime date;

  @HiveField(1)
  late String type;

  @HiveField(2)
  late String description;

  @HiveField(3)
  String? location;

  @HiveField(4)
  List<String>? tags;

  @HiveField(5)
  String? googleEventId;

  @HiveField(6)
  double? latitude;

  @HiveField(7)
  double? longitude;

  DriverEvent({
    required this.date,
    required this.type,
    required this.description,
    this.location,
    this.tags,
    this.googleEventId,
    this.latitude,
    this.longitude,
  });
}
