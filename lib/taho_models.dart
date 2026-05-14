import 'dart:typed_data';

double convertLat(int value) {
  if (value == 0 || value == 0x7FFFFF) return 0.0;

  bool negative = value < 0;
  int v = value.abs();

  double ddmm = v / 10.0;

  int degrees = (ddmm / 100).floor();
  double minutes = ddmm - (degrees * 100);

  double result = degrees + (minutes / 60.0);

  return negative ? -result : result;
}

double convertLon(int value) {
  if (value == 0 || value == 0x7FFFFF) return 0.0;

  bool negative = value < 0;
  int v = value.abs();

  double dddmm = v / 10.0;

  int degrees = (dddmm / 100).floor();
  double minutes = dddmm - (degrees * 100);

  double result = degrees + (minutes / 60.0);

  return negative ? -result : result;
}


class LastDownload {
  final DateTime? lastDownload;

  LastDownload({this.lastDownload});

  String get formattedDate {
    if (lastDownload == null) return "Never";
    return "${lastDownload!.day.toString().padLeft(2, '0')}.${lastDownload!.month.toString().padLeft(2, '0')}.${lastDownload!.year} ${lastDownload!.hour.toString().padLeft(2, '0')}:${lastDownload!.minute.toString().padLeft(2, '0')}";
  }
}

class CardId {
  final String cardNumber;
  final String issuer;
  final DateTime dateIssued;
  final DateTime startDate;
  final DateTime expiryDate;
  final String surname;
  final String name;
  final List<int> birthdayRaw;
  final String country;

  CardId({
    required this.cardNumber,
    required this.issuer,
    required this.dateIssued,
    required this.startDate,
    required this.expiryDate,
    required this.surname,
    required this.name,
    required this.birthdayRaw,
    required this.country,
  });

  String get formattedBirthday {
    if (birthdayRaw.length < 4) return "Unknown";
    try {
      // Use BCD logic
      String year = birthdayRaw[0].toRadixString(16).padLeft(2, '0') +
          birthdayRaw[1].toRadixString(16).padLeft(2, '0');
      String month = birthdayRaw[2].toRadixString(16).padLeft(2, '0');
      String day = birthdayRaw[3].toRadixString(16).padLeft(2, '0');
      return "$day.$month.$year";
    } catch (_) {
      return "Unknown";
    }
  }
}

class DriverLicense {
  final String issuingAuthority;
  final String issuingNation;
  final String licenseNumber;

  DriverLicense({
    required this.issuingAuthority,
    required this.issuingNation,
    required this.licenseNumber,
  });
}

class VehicleRecord {
  final int no;
  final int startKm;
  final int endKm;
  final DateTime startTime;
  final DateTime endTime;
  final String registration;

  VehicleRecord({
    required this.no,
    required this.startKm,
    required this.endKm,
    required this.startTime,
    required this.endTime,
    required this.registration,
  });
}

class DailyVehicles {
  final DateTime date;
  final List<VehicleRecord> vehicles;

  DailyVehicles({
    required this.date,
    required this.vehicles,
  });
}

class ActivityDayHeader {
  final int prevLength;
  final int currLength;
  final DateTime time;
  final int noActivity;
  final int km;

  ActivityDayHeader({
    required this.prevLength,
    required this.currLength,
    required this.time,
    required this.noActivity,
    required this.km,
  });
}

class ActivityRecord {
  final int slot;
  final int crew;
  final int card;
  final int activity;
  final int time;

  ActivityRecord({
    required this.slot,
    required this.crew,
    required this.card,
    required this.activity,
    required this.time,
  });
}

class DailyActivities {
  final ActivityDayHeader header;
  final List<ActivityRecord> activities;

  DailyActivities({
    required this.header,
    required this.activities,
  });

  DateTime get date => header.time;
}

class TahoGen1Card {
  final Uint8List iccData;
  final Uint8List icData;
  final Uint8List cardCertDATAptr;
  final Uint8List CACertDATAptr;
  final Uint8List idData;
  final Uint8List driverLicenseDATAptr;
  final Uint8List activitiesDATAptr;
  final Uint8List vehiclesDATAptr;
  final Uint8List appIdentification;
  final Uint8List cardDownload;
  final Uint8List eventsData;
  final Uint8List faultsData;
  final Uint8List places;
  final Uint8List currentUsage;
  final Uint8List controlActivityData;
  final Uint8List specificConditions;

  TahoGen1Card({
    required this.iccData,
    required this.icData,
    required this.cardCertDATAptr,
    required this.CACertDATAptr,
    required this.idData,
    required this.driverLicenseDATAptr,
    required this.activitiesDATAptr,
    required this.vehiclesDATAptr,
    required this.appIdentification,
    required this.cardDownload,
    required this.eventsData,
    required this.faultsData,
    required this.places,
    required this.currentUsage,
    required this.controlActivityData,
    required this.specificConditions,
  });
}

class TahoGen2Card {
  final Uint8List appIdentification;
  final Uint8List cardCertDATAptr;
  final Uint8List cardSignCertificate;
  final Uint8List CACertDATAptr;
  final Uint8List linkCertificate;
  final Uint8List idData;
  final Uint8List cardDownload;
  final Uint8List driverLicenseDATAptr;
  final Uint8List eventsData;
  final Uint8List faultsData;
  final Uint8List activitiesDATAptr;
  final Uint8List vehiclesDATAptr;
  final Uint8List places;
  final Uint8List currentUsage;
  final Uint8List controlActivityData;
  final Uint8List specificConditions;
  final Uint8List vehicleUnitsUsed;
  final Uint8List GNSS;

  TahoGen2Card({
    required this.appIdentification,
    required this.cardCertDATAptr,
    required this.cardSignCertificate,
    required this.CACertDATAptr,
    required this.linkCertificate,
    required this.idData,
    required this.cardDownload,
    required this.driverLicenseDATAptr,
    required this.eventsData,
    required this.faultsData,
    required this.activitiesDATAptr,
    required this.vehiclesDATAptr,
    required this.places,
    required this.currentUsage,
    required this.controlActivityData,
    required this.specificConditions,
    required this.vehicleUnitsUsed,
    required this.GNSS,
  });
}

class GnssRecord {
  final DateTime timestamp;
  final DateTime fixTime;
  final int accuracy;
  final int lat; // 24-bit integer s kartice
  final int lon; // 24-bit integer s kartice
  final int b1;
  final int b2;
  final int b3;

  GnssRecord({
    required this.timestamp,
    required this.fixTime,
    required this.accuracy,
    required this.lat,
    required this.lon,
    required this.b1,
    required this.b2,
    required this.b3,
  });

  double get latitude => convertLat(lat);
  double get longitude => convertLon(lon);

  String get formattedLat {
    if (lat == 0x7FFFFF || lat == 0) return "Unknown";
    String n = lat > 0 ? 'N' : (lat < 0 ? 'S' : '');
    int absSt = lat.abs();
    int dd = absSt ~/ 1000;
    int minutes = absSt % 1000;
    int m = minutes ~/ 100;
    int mm = (minutes % 100) ~/ 10;
    int sss = (((minutes % 100) % 10) * 60) ~/ 10;
    return "$dd°$m$mm′$sss″$n";
  }

  String get formattedLon {
    if (lon == 0x7FFFFF || lon == 0) return "Unknown";
    String n = lon > 0 ? 'E' : (lon < 0 ? 'W' : '');
    int absSt = lon.abs();
    int ddd = absSt ~/ 1000;
    int minutes = absSt % 1000;
    int m = minutes ~/ 100;
    int mm = (minutes % 100) ~/ 10;
    int sss = (((minutes % 100) % 10) * 60) ~/ 10;
    return "$ddd°$m$mm′$sss″$n";
  }
}

class TahoFault {
  final int type;
  final DateTime beginTime;
  final DateTime endTime;
  final int vehicleRegistrationNation;
  final String vehicleRegistrationNumber;

  TahoFault({
    required this.type,
    required this.beginTime,
    required this.endTime,
    required this.vehicleRegistrationNation,
    required this.vehicleRegistrationNumber,
  });
}

class ParsedTachoData {
  final CardId cardId;
  final List<DailyActivities> activities;
  final DriverLicense? driverLicense;
  final List<TahoFault> faults;
  final List<TahoFault> events;

  ParsedTachoData({
    required this.cardId,
    required this.activities,
    this.driverLicense,
    this.faults = const [],
    this.events = const [],
  });
}
