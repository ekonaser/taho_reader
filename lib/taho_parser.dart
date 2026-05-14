import 'dart:typed_data';
import 'taho_models.dart';

class TahoParser {
  DateTime _epoch(int sec) =>
      DateTime.fromMillisecondsSinceEpoch(sec * 1000, isUtc: true);

  String _str(Uint8List section, int offset, int len) {
    if (offset + len > section.length) len = section.length - offset;
    if (len <= 0) return "";
    final sub = section.sublist(offset, offset + len);
    return String.fromCharCodes(sub).replaceAll('\x00', '').trim();
  }

  int _u16(Uint8List section, int offset) {
    if (offset + 2 > section.length) return 0;
    final bd = ByteData.sublistView(section, offset, offset + 2);
    return bd.getUint16(0, Endian.big);
  }

  int _u8(Uint8List section, int offset) {
    if (offset >= section.length) return 0;
    return section[offset];
  }

  int _u32(Uint8List section, int offset) {
    if (offset + 4 > section.length) return 0;
    final bd = ByteData.sublistView(section, offset, offset + 4);
    return bd.getUint32(0, Endian.big);
  }

  int _u24(Uint8List section, int offset) {
    if (offset + 3 > section.length) return 0;
    int val = (section[offset] << 16) |
    (section[offset + 1] << 8) |
    section[offset + 2];
    return val.toSigned(24);
  }

  LastDownload parseLastDownload(Uint8List section) {
    if (section.length < 4) return LastDownload(lastDownload: null);
    int ts = _u32(section, 0);
    if (ts == 0 || ts == 0xFFFFFFFF) return LastDownload(lastDownload: null);
    return LastDownload(lastDownload: _epoch(ts));
  }

  CardId parseCardId(Uint8List section) {
    return CardId(
      cardNumber: _str(section, 1, 16),
      issuer: _str(section, 18, 35),
      dateIssued: _epoch(_u32(section, 53)),
      startDate: _epoch(_u32(section, 57)),
      expiryDate: _epoch(_u32(section, 61)),
      surname: _str(section, 66, 35),
      name: _str(section, 102, 35),
      birthdayRaw: section.length >= 141
          ? section.sublist(137, 141).toList()
          : [0, 0, 0, 0],
      country: _str(section, 141, 2),
    );
  }

  DriverLicense parseDriverLicense(Uint8List section) {
    if (section.length < 53) {
      return DriverLicense(
        issuingAuthority: "",
        issuingNation: "",
        licenseNumber: "",
      );
    }
    return DriverLicense(
      issuingAuthority: _str(section, 0, 36),
      issuingNation: _str(section, 36, 1),
      licenseNumber: _str(section, 37, 16),
    );
  }

  List<DailyVehicles> parseVehicles(Uint8List section) {
    if (section.length < 35) return [];
    final bd = ByteData.sublistView(section);
    Map<String, List<VehicleRecord>> grouped = {};

    for (int i = 0; i <= section.length - 31; i += 31) {
      int no = (section[i] << 8) | section[i + 1];
      int startKm = (section[i + 2] << 16) | (section[i + 3] << 8) | section[i + 4];
      int endKm = (section[i + 5] << 16) | (section[i + 6] << 8) | section[i + 7];
      int sTimeRaw = bd.getUint32(i + 8, Endian.big);
      int eTimeRaw = bd.getUint32(i + 12, Endian.big);
      String reg = _str(section, i + 18, 13);

      if (sTimeRaw > 0 && sTimeRaw < 0xFFFFFFFF) {
        DateTime sTime = _epoch(sTimeRaw);
        if (sTime.year > 2000 && sTime.year < 2100) {
          String dateKey = sTime.toLocal().toString().split(' ').first;
          grouped.putIfAbsent(dateKey, () => []);
          grouped[dateKey]!.add(VehicleRecord(
            no: no,
            startKm: startKm,
            endKm: endKm,
            startTime: sTime,
            endTime: _epoch(eTimeRaw),
            registration: reg,
          ));
        }
      }
    }
    for (var list in grouped.values) {
      list.sort((a, b) => b.startTime.compareTo(a.startTime));
    }
    return grouped.entries.map((e) => DailyVehicles(
      date: DateTime.parse(e.key),
      vehicles: e.value,
    )).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<TahoFault> parseFaults(Uint8List section) {
    if (section.length < 24) return [];
    final List<TahoFault> faults = [];
    for (int i = 0; i <= section.length - 24; i += 24) {
      int type = _u8(section, i);
      int beginTs = _u32(section, i + 1);
      int endTs = _u32(section, i + 5);

      if (beginTs == 0 || beginTs == 0xFFFFFFFF) continue;

      faults.add(TahoFault(
        type: type,
        beginTime: _epoch(beginTs),
        endTime: _epoch(endTs),
        vehicleRegistrationNation: _u8(section, i + 9),
        vehicleRegistrationNumber: _str(section, i + 10, 14),
      ));
    }
    faults.sort((a, b) => a.beginTime.compareTo(b.beginTime));
    return faults;
  }

  List<DailyActivities> parseActivities(Uint8List rawData) {
    if (rawData.length < 13780) return [];

    int k1 = (rawData[0] << 8) | rawData[1];
    int k2 = (rawData[2] << 8) | rawData[3];

    Uint8List buffer = rawData.sublist(4, 4 + 13776);
    int size = 13776;

    Map<String, DailyActivities> result = {};

    while (k2 != k1) {
      ActivityDayHeader header = ActivityDayHeader(
        prevLength: (buffer[k2 % size] << 8) | buffer[(k2 + 1) % size],
        currLength: (buffer[(k2 + 2) % size] << 8) | buffer[(k2 + 3) % size],
        time: _epoch(
            (buffer[(k2 + 4) % size] << 24) |
            (buffer[(k2 + 5) % size] << 16) |
            (buffer[(k2 + 6) % size] << 8)  |
            buffer[(k2 + 7) % size]
        ),
        noActivity: (buffer[(k2 + 8) % size] << 8) | buffer[(k2 + 9) % size],
        km: (buffer[(k2 + 10) % size] << 8) | buffer[(k2 + 11) % size],
      );

      List<ActivityRecord> activities = [];

      for (int j = 0; j < header.currLength - 14; j += 2) {
        int b1 = (k2 + 14 + j) % size;
        int b2 = (k2 + 14 + j + 1) % size;

        int val = (buffer[b1] << 8) | buffer[b2];

        int slot = (val & (1 << 15)) != 0 ? 1 : 0;
        int crew = (val & (1 << 14)) != 0 ? 1 : 0;
        int card = (val & (1 << 13)) != 0 ? 0 : 1;
        int activity = (val >> 11) & 0x03;

        int minutes = val & 0x07FF;
        minutes = minutes % 1440;

        activities.add(ActivityRecord(
          slot: slot,
          crew: crew,
          card: card,
          activity: activity,
          time: minutes,
        ));
      }

      String key = header.time.toLocal().toString().split(' ').first;
      result[key] = DailyActivities(header: header, activities: activities);

      k2 -= header.prevLength;
      if (k2 < 0) k2 += size;
    }

    return result.values.toList();
  }
}

class TahoParserG2 extends TahoParser {
  List<GnssRecord> parseGnss(Uint8List section) {
    if (section.length < 18) return [];
    final List<GnssRecord> records = [];
    for (int i = 2; i <= section.length - 18; i += 18) {
      int d1 = _u32(section, i);
      if (d1 == 0 || d1 == 0xFFFFFFFF) continue;
      records.add(GnssRecord(
        timestamp: _epoch(d1),
        fixTime: _epoch(_u32(section, i + 4)),
        accuracy: section[i + 8],
        lat: _u24(section, i + 9),
        lon: _u24(section, i + 12),
        b1: section[i + 15],
        b2: section[i + 16],
        b3: section[i + 17],
      ));
    }
    records.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return records;
  }
}
