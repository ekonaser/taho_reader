import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'activity_timeline.dart';
import 'faults_view.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'event_model.dart';
import 'archive_model.dart';
import 'logs_view.dart';
import 'taho_models.dart';
import 'taho_parser.dart';
import 'taho_reader.dart';
import 'taho_exporter.dart';
import 'openstreetmap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(DriverEventAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ArchiveRecordAdapter());
  }
  await Hive.openBox<DriverEvent>('driver_events');
  await Hive.openBox<ArchiveRecord>('archive_records');
  runApp(const TahoApp());
}

class TahoApp extends StatelessWidget {
  const TahoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tacho Reader',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF28B52F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF28B52F),
          primary: const Color(0xFF28B52F),
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF28B52F),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF28B52F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF28B52F),
          brightness: Brightness.dark,
          primary: const Color(0xFF28B52F),
          surface: const Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const TahoDashboard(),
    );
  }
}

class TahoDashboard extends StatefulWidget {
  const TahoDashboard({super.key});

  @override
  State<TahoDashboard> createState() => _TahoDashboardState();
}

class _TahoDashboardState extends State<TahoDashboard> {
  CardId? cardId;
  DriverLicense? driverLicense;
  LastDownload? lastDownload;
  List<DailyVehicles> vehicles = [];
  List<PlaceRecord> places = [];
  List<DailyVehiclesG2> vehiclesG2 = [];
  List<PlaceRecordG2> placesG2 = [];
  List<GnssRecord> gnssRecords = [];
  List<DailyActivities> activities = [];
  List<TahoFault> vehicleFaults = [];
  List<TahoFault> driverEvents = [];
  List<TahoFault> detectedEvents = [];
  TahoGen2Card? gen2Card;
  TahoGen1Card? gen1Card;
  bool _isGen2View = false;
  bool _under50km = false;
  DateTime? _selectedActivityDate;
  bool isLoading = false;
  double _loadingProgress = 0.0;
  String _loadingStatus = "";
  int _selectedTabIndex = 0;
  int _homeSubTabIndex = 0; // 0: Card ID, 1: Archive
  int _utcOffset = 0;
  LatLng? _mapInitialCenter;
  double? _mapInitialZoom;

  final TahoReader _tahoReader = TahoReader();
  static const primaryGreen = Color(0xFF28B52F);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGen2View = prefs.getBool('isGen2View') ?? false;
      _under50km = prefs.getBool('under50km') ?? false;
    });
    if (gen1Card != null || gen2Card != null) {
      _updateParsedData();
    }
  }

  Future<void> _toggleGen2View(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isGen2View', value);
    setState(() {
      _isGen2View = value;
    });
    _updateParsedData();
  }

  void _updateParsedData() {
    final parser = TahoParser();
    final parserG2 = TahoParserG2();

    setState(() {
      _mapInitialCenter = null;
      _mapInitialZoom = null;

      if (_isGen2View) {
        if (gen2Card != null) {
          cardId = gen2Card!.idData.isNotEmpty ? parserG2.parseCardId(gen2Card!.idData) : null;
          driverLicense = gen2Card!.driverLicenseDATAptr.isNotEmpty ? parserG2.parseDriverLicense(gen2Card!.driverLicenseDATAptr) : null;
          lastDownload = gen2Card!.cardDownload.isNotEmpty ? parserG2.parseLastDownload(gen2Card!.cardDownload) : null;
          activities = gen2Card!.activitiesDATAptr.isNotEmpty ? parserG2.parseActivities(gen2Card!.activitiesDATAptr) : [];
          activities.sort((a, b) => b.date.compareTo(a.date));
          gnssRecords = parserG2.parseGnss(gen2Card!.GNSS);
          vehicleFaults = parserG2.parseFaults(gen2Card!.faultsData); // 0503
          driverEvents = parserG2.parseFaults(gen2Card!.eventsData);   // 0502
          vehiclesG2 = parserG2.parseVehiclesG2(gen2Card!.vehiclesDATAptr);
          placesG2 = parserG2.parsePlacesG2(gen2Card!.places);
          vehicles = [];
          places = [];
        } else {
          // Reset view if no Gen 2 data is available
          cardId = null;
          driverLicense = null;
          lastDownload = null;
          activities = [];
          gnssRecords = [];
          vehicleFaults = [];
          driverEvents = [];
          vehicles = [];
          places = [];
          vehiclesG2 = [];
          placesG2 = [];
        }
      } else {
        if (gen1Card != null) {
          cardId = parser.parseCardId(gen1Card!.idData);
          driverLicense = parser.parseDriverLicense(gen1Card!.driverLicenseDATAptr);
          lastDownload = parser.parseLastDownload(gen1Card!.cardDownload);
          vehicles = parser.parseVehicles(gen1Card!.vehiclesDATAptr);
          places = parser.parsePlaces(gen1Card!.places);
          activities = parser.parseActivities(gen1Card!.activitiesDATAptr);
          activities.sort((a, b) => b.date.compareTo(a.date));
          vehicleFaults = parser.parseFaults(gen1Card!.faultsData); // 0503
          driverEvents = parser.parseFaults(gen1Card!.eventsData);   // 0502
          gnssRecords = [];
          vehiclesG2 = [];
          placesG2 = [];
        } else {
          // Reset view if no Gen 1 data is available
          cardId = null;
          driverLicense = null;
          lastDownload = null;
          vehicles = [];
          places = [];
          activities = [];
          vehicleFaults = [];
          driverEvents = [];
          gnssRecords = [];
          vehiclesG2 = [];
          placesG2 = [];
        }
      }

      detectedEvents = [];
      if (!_under50km) {
        for (var day in activities) {
          _detectOverdriveForDay(day);
        }
      }
    });
  }

  void _detectOverdriveForDay(DailyActivities day) {
    if (day.activities.isEmpty) return;

    int accumulatedDriving = 0;
    bool hasFirstBreakPart = false;

    for (int i = 1; i < day.activities.length; i++) {
      final prev = day.activities[i - 1];
      final curr = day.activities[i];
      final duration = curr.time - prev.time;
      if (duration <= 0) continue;

      // Reset if no card inserted (New session or card removed)
      if (prev.card == 0) {
        accumulatedDriving = 0;
        hasFirstBreakPart = false;
      }

      if (prev.activity == 0 || prev.activity == 1) { // Rest or Availability
        if (duration >= 45 || (duration >= 30 && hasFirstBreakPart)) {
          accumulatedDriving = 0;
          hasFirstBreakPart = false;
        } else if (duration >= 15 && !hasFirstBreakPart) {
          hasFirstBreakPart = true;
        }
      } else if (prev.activity == 3) { // Driving
        int oldAccumulated = accumulatedDriving;
        accumulatedDriving += duration;
        if (accumulatedDriving > 270) {
          int startOfOverdriveInThisSegment = max(0, 270 - oldAccumulated);
          final begin = day.date.add(Duration(minutes: prev.time + startOfOverdriveInThisSegment));
          final end = day.date.add(Duration(minutes: curr.time));

          detectedEvents.add(TahoFault(
            type: 0xFF, // Custom Overdrive type
            beginTime: begin,
            endTime: end,
            vehicleRegistrationNation: 0,
            vehicleRegistrationNumber: "Detected",
          ));
          accumulatedDriving = 270;
        }
      }
    }
  }

  Map<String, Uint8List> _extractAllSections(Uint8List bytes) {
    final Map<String, Uint8List> sections = {};
    int i = 0;
    while (i <= bytes.length - 5) {
      int b1 = bytes[i];
      int b2 = bytes[i + 1];
      int gen = bytes[i + 2];
      int len = (bytes[i + 3] << 8) | bytes[i + 4];
      
      if (i + 5 + len <= bytes.length) {
        String key = "${b1.toRadixString(16).padLeft(2, '0')}${b2.toRadixString(16).padLeft(2, '0')}_$gen";
        sections[key] = bytes.sublist(i + 5, i + 5 + len);
        i += 5 + len;
      } else {
        i++;
      }
    }
    return sections;
  }

  Future<void> _pickAndParseFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;

      setState(() => isLoading = true);

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      final s = _extractAllSections(bytes);

      // Reconstruct Gen 1
      final g1 = TahoGen1Card(
        iccData: s['0002_0'] ?? Uint8List(0),
        icData: s['0005_0'] ?? Uint8List(0),
        cardCertDATAptr: s['c100_0'] ?? Uint8List(0),
        CACertDATAptr: s['c108_0'] ?? Uint8List(0),
        idData: s['0520_0'] ?? Uint8List(0),
        driverLicenseDATAptr: s['0521_0'] ?? Uint8List(0),
        activitiesDATAptr: s['0504_0'] ?? Uint8List(0),
        vehiclesDATAptr: s['0505_0'] ?? Uint8List(0),
        appIdentification: s['0501_0'] ?? Uint8List(0),
        cardDownload: s['050e_0'] ?? Uint8List(0),
        eventsData: s['0502_0'] ?? Uint8List(0),
        faultsData: s['0503_0'] ?? Uint8List(0),
        places: s['0506_0'] ?? Uint8List(0),
        currentUsage: s['0507_0'] ?? Uint8List(0),
        controlActivityData: s['0508_0'] ?? Uint8List(0),
        specificConditions: s['0522_0'] ?? Uint8List(0),
      );

      // Reconstruct Gen 2
      final g2 = TahoGen2Card(
        appIdentification: s['0501_2'] ?? Uint8List(0),
        cardCertDATAptr: s['c100_2'] ?? Uint8List(0),
        cardSignCertificate: s['c101_2'] ?? Uint8List(0),
        CACertDATAptr: s['c108_2'] ?? Uint8List(0),
        linkCertificate: s['c109_2'] ?? Uint8List(0),
        idData: s['0520_2'] ?? Uint8List(0),
        cardDownload: s['050e_2'] ?? Uint8List(0),
        driverLicenseDATAptr: s['0521_2'] ?? Uint8List(0),
        eventsData: s['0502_2'] ?? Uint8List(0),
        faultsData: s['0503_2'] ?? Uint8List(0),
        activitiesDATAptr: s['0504_2'] ?? Uint8List(0),
        vehiclesDATAptr: s['0505_2'] ?? Uint8List(0),
        places: s['0506_2'] ?? Uint8List(0),
        currentUsage: s['0507_2'] ?? Uint8List(0),
        controlActivityData: s['0508_2'] ?? Uint8List(0),
        specificConditions: s['0522_2'] ?? Uint8List(0),
        vehicleUnitsUsed: s['0523_2'] ?? Uint8List(0),
        GNSS: s['0524_2'] ?? Uint8List(0),
      );

      setState(() {
        gen1Card = g1.idData.isNotEmpty ? g1 : null;
        gen2Card = g2.idData.isNotEmpty ? g2 : null;
        _updateParsedData();
        _saveToArchive();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _readTachoCard() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        _loadingProgress = 0.0;
        _loadingStatus = "Connecting to reader...";
      });

      if (!await _tahoReader.init()) throw 'USB reader not available';
      setState(() => _loadingStatus = "Resetting card...");
      await _tahoReader.getATR(); 
      if (!await _tahoReader.isConnected()) throw 'Reader not connected';
      if (!await _tahoReader.isCardPresent()) throw 'Card not detected';

      setState(() {
        _loadingStatus = "Initializing data...";
        cardId = null;
        driverLicense = null;
        vehicles = [];
        places = [];
        vehiclesG2 = [];
        placesG2 = [];
        activities = [];
        vehicleFaults = [];
        driverEvents = [];
        gnssRecords = [];
        gen1Card = null;
        gen2Card = null;
        _mapInitialCenter = null;
        _mapInitialZoom = null;
      });

      try {
        gen1Card = await _readGen1Card();
      } catch (e) {
        developer.log("Gen 1 reading failed: $e");
      }

      try {
        gen2Card = await _readGen2Card();
      } catch (e) {
        developer.log("Gen 2 reading failed: $e");
      }

      if (gen1Card == null && gen2Card == null) {
        throw "Reading did not return any valid data.";
      }

      _updateParsedData();
      _saveToArchive();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<TahoGen1Card> _readGen1Card() async {
    const int grandTotal = 63521;
    int current = 0;

    void update(int len, String status) {
      current += len;
      if (mounted) {
        setState(() {
          _loadingStatus = status;
          _loadingProgress = current / grandTotal;
        });
      }
    }

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x00, 0x02]));
    update(0, "Reading ICC (Gen 1)...");
    final iccData = await _tahoReader.readData(25);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x00, 0x05]));
    update(25, "Reading IC (Gen 1)...");
    final icData = await _tahoReader.readData(8);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C, 0x06, 0xFF, 0x54, 0x41, 0x43, 0x48, 0x4F]));
    update(8, "Selecting Tacho App...");
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x00]));
    update(0, "Reading Card Certificate...");
    final cardCert = await _tahoReader.readData(194);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x08]));
    update(194, "Reading CA Certificate...");
    final caCert = await _tahoReader.readData(194);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x20]));
    update(194, "Reading Identification...");
    final idData = await _tahoReader.readData(143);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x21]));
    update(143, "Reading Driver License...");
    final license = await _tahoReader.readData(53);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x04]));
    update(53, "Reading Activities...");
    final activities = await _tahoReader.readData(13780);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x05]));
    update(13780, "Reading Vehicles Used...");
    final vehicles = await _tahoReader.readData(6202);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x01]));
    update(6202, "Reading App Identification...");
    final appId = await _tahoReader.readData(10);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x0E]));
    update(10, "Reading Download Status...");
    final download = await _tahoReader.readData(4);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x02]));
    update(4, "Reading Events...");
    final events = await _tahoReader.readData(1728);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x03]));
    update(1728, "Reading Faults...");
    final faults = await _tahoReader.readData(1152);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x06]));
    update(1152, "Reading Places...");
    final places = await _tahoReader.readData(1121);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x07]));
    update(1121, "Reading Current Usage...");
    final usage = await _tahoReader.readData(19);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x08]));
    update(19, "Reading Control Activity...");
    final control = await _tahoReader.readData(46);
    
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x22]));
    update(46, "Reading Specific Conditions...");
    final conditions = await _tahoReader.readData(280);
    update(280, "Gen 1 Reading Complete");

    return TahoGen1Card(
      iccData: iccData,
      icData: icData,
      cardCertDATAptr: cardCert,
      CACertDATAptr: caCert,
      idData: idData,
      driverLicenseDATAptr: license,
      activitiesDATAptr: activities,
      vehiclesDATAptr: vehicles,
      appIdentification: appId,
      cardDownload: download,
      eventsData: events,
      faultsData: faults,
      places: places,
      currentUsage: usage,
      controlActivityData: control,
      specificConditions: conditions,
    );
  }

  Future<TahoGen2Card> _readGen2Card() async {
    const int grandTotal = 63521;
    int current = 24959; // Start after Gen 1

    void update(int len, String status) {
      current += len;
      if (mounted) {
        setState(() {
          _loadingStatus = status;
          _loadingProgress = current / grandTotal;
        });
      }
    }

    // selecting SMRDT app
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C, 0x06, 0xFF, 0x53, 0x4D, 0x52, 0x44, 0x54]));
    update(0, "Selecting Gen 2 App...");

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x01]));
    update(0, "Reading App ID (Gen 2)...");
    final appId = await _tahoReader.readData(15);

    // CardMA Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x00]));
    update(15, "Reading Card MA Cert...");
    final cardCert = await _tahoReader.readData(205);

    // Card Sign Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x01]));
    update(205, "Reading Card Sign Cert...");
    final cardSignCert = await _tahoReader.readData(205);

    // CA Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x08]));
    update(205, "Reading CA Cert (G2)...");
    final caCert = await _tahoReader.readData(205);

    // Link Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x09]));
    update(205, "Reading Link Cert...");
    final linkCert = await _tahoReader.readData(205);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x20]));
    update(205, "Reading Identification (G2)...");
    final idData = await _tahoReader.readData(143);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x0E]));
    update(143, "Reading Download Status (G2)...");
    final download = await _tahoReader.readData(4);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x21]));
    update(4, "Reading Driver License (G2)...");
    final license = await _tahoReader.readData(53);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x02]));
    update(53, "Reading Events (G2)...");
    final events = await _tahoReader.readData(3168);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x03]));
    update(3168, "Reading Faults (G2)...");
    final faults = await _tahoReader.readData(1152);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x04]));
    update(1152, "Reading Activities (G2)...");
    final activities = await _tahoReader.readData(13780);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x05]));
    update(13780, "Reading Vehicles Used (G2)...");
    final vehicles = await _tahoReader.readData(9602);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x06]));
    update(9602, "Reading Places (G2)...");
    final places = await _tahoReader.readData(2354);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x07]));
    update(2354, "Reading Current Usage (G2)...");
    final usage = await _tahoReader.readData(19);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x08]));
    update(19, "Reading Control Activity (G2)...");
    final control = await _tahoReader.readData(46);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x22]));
    update(46, "Reading Specific Conditions (G2)...");
    final conditions = await _tahoReader.readData(562);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x23]));
    update(562, "Reading Vehicles Units (G2)...");
    final units = await _tahoReader.readData(2002);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x24]));
    update(2002, "Reading GNSS Records...");
    final gnssData = await _tahoReader.readData(5042);
    update(5042, "Gen 2 Reading Complete");

    return TahoGen2Card(
      appIdentification: appId,
      cardCertDATAptr: cardCert,
      cardSignCertificate: cardSignCert,
      CACertDATAptr: caCert,
      linkCertificate: linkCert,
      idData: idData,
      cardDownload: download,
      driverLicenseDATAptr: license,
      eventsData: events,
      faultsData: faults,
      activitiesDATAptr: activities,
      vehiclesDATAptr: vehicles,
      places: places,
      currentUsage: usage,
      controlActivityData: control,
      specificConditions: conditions,
      vehicleUnitsUsed: units,
      GNSS: gnssData,
    );
  }

  Future<void> _selectActivityDate() async {
    if (activities.isEmpty) return;
    final dates = activities.map((a) => a.date).toList();
    dates.sort();
    final firstDate = dates.first;
    final lastDate = dates.last;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedActivityDate ?? lastDate,
      firstDate: firstDate,
      lastDate: lastDate,
      selectableDayPredicate: (day) {
        return activities.any((a) =>
        a.date.year == day.year && a.date.month == day.month && a.date.day == day.day);
      },
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: primaryGreen, onPrimary: Colors.white, onSurface: Colors.black),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedActivityDate = picked);
    }
  }

  void _jumpToActivityDay(int delta) {
    if (activities.isEmpty) return;
    
    // Sort activities by date (descending: newest first)
    final sortedActivities = List<DailyActivities>.from(activities);
    sortedActivities.sort((a, b) => b.date.compareTo(a.date));

    // Find current index
    DateTime current = _selectedActivityDate ?? sortedActivities.first.date;
    int index = sortedActivities.indexWhere((a) =>
        a.date.year == current.year &&
        a.date.month == current.month &&
        a.date.day == current.day);

    if (index == -1) index = 0;

    // In a descending list: 
    // delta -1 (Next/Newer) means index decreases
    // delta +1 (Prev/Older) means index increases
    int newIndex = index + delta;
    
    if (newIndex >= 0 && newIndex < sortedActivities.length) {
      setState(() {
        _selectedActivityDate = sortedActivities[newIndex].date;
      });
    }
  }

  Future<void> _showSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          isGen2View: _isGen2View,
          onGen2ViewChanged: _toggleGen2View,
        ),
      ),
    );
    _loadSettings();
  }

  void _saveToDdd() {
    if (cardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No card data to save. Please read a card first.')),
      );
      return;
    }
    TahoExporter().saveToDdd(
      gen1Card: gen1Card,
      gen2Card: gen2Card,
      fileName: '${cardId!.name}_${cardId!.surname}'.replaceAll(' ', '_'),
    );
  }

  void _shareDdd() {
    if (cardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No card data to share. Please read a card first.')),
      );
      return;
    }
    TahoExporter().shareDdd(
      gen1Card: gen1Card,
      gen2Card: gen2Card,
      fileName: '${cardId!.name}_${cardId!.surname}'.replaceAll(' ', '_'),
    );
  }

  @override
  void dispose() {
    _tahoReader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final bool shouldPop = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit'),
            content: const Text('Are you sure you want to exit? All unsaved data will be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('NO')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('YES')),
            ],
          ),
        ) ?? false;
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getTabTitle()),
          actions: [
            ExpandingActionMenu(
              actions: [
                SpeedDialAction(
                  icon: Icons.settings,
                  label: 'Settings',
                  onPressed: _showSettings,
                ),
                SpeedDialAction(
                  icon: Icons.usb,
                  label: 'Read Card',
                  onPressed: _readTachoCard,
                ),
                SpeedDialAction(
                  icon: Icons.file_open,
                  label: 'Open .ddd',
                  onPressed: _pickAndParseFile,
                ),
                SpeedDialAction(
                  icon: Icons.share,
                  label: 'Share .ddd',
                  onPressed: _shareDdd,
                ),
                SpeedDialAction(
                  icon: Icons.save,
                  label: 'Save .ddd',
                  onPressed: _saveToDdd,
                ),
              ],
            ),
          ],
        ),
        body: isLoading 
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: _loadingProgress > 0 ? _loadingProgress : null,
                    color: primaryGreen,
                    strokeWidth: 6,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "${(_loadingProgress * 100).toInt()}%",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _loadingStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : _buildTabContent(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
              // Clear jump target if navigating away from GNSS tab
              if (index != 4) {
                _mapInitialCenter = null;
                _mapInitialZoom = null;
              }
            });
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryGreen,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'Logs'),
            BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Activities'),
            BottomNavigationBarItem(icon: Icon(Icons.warning_amber), label: 'Faults'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'GNSS'),
          ],
        ),
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTabIndex) {
      case 0: return _homeSubTabIndex == 0 ? 'Card ID' : 'Archive';
      case 1: return 'Logs';
      case 2: return 'Activities';
      case 3: return 'Faults';
      case 4: return 'GNSS';
      default: return 'Tacho Reader';
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: return _buildHomeTab();
      case 1:
        return LogsView(
          vehicles: vehicles,
          places: places,
          vehiclesG2: vehiclesG2,
          placesG2: placesG2,
          gnssRecords: gnssRecords,
          onJumpToMap: (lat, lon) {
            setState(() {
              _mapInitialCenter = LatLng(lat, lon);
              _mapInitialZoom = 15.0;
              _selectedTabIndex = 4; // GNSS Tab
            });
          },
        );
      case 2:
        return ValueListenableBuilder(
          valueListenable: Hive.box<DriverEvent>('driver_events').listenable(),
          builder: (context, Box<DriverEvent> box, _) {
            return ActivityTimeline(
              activities: activities,
              cardId: cardId,
              selectedDate: _selectedActivityDate,
              utcOffset: _utcOffset,
              onUtcOffsetChanged: (offset) => setState(() => _utcOffset = offset),
              onDateTap: _selectActivityDate,
              onPrevDay: () => _jumpToActivityDay(1), // Older
              onNextDay: () => _jumpToActivityDay(-1), // Newer
              under50km: _under50km,
              places: places,
              placesG2: placesG2,
              driverEvents: box.values.toList(),
            );
          },
        );
      case 3:
        return FaultsView(
          vehicleFaults: vehicleFaults,
          driverEvents: driverEvents,
          detectedEvents: detectedEvents,
          onNavigateToDay: (date) {
            setState(() {
              // Normalize to start of day to match Activities logic
              _selectedActivityDate = DateTime(date.year, date.month, date.day);
              _selectedTabIndex = 2; // Activities Tab
            });
          },
        );
      case 4:
        return OpenStreetMapScreen(
          key: ValueKey(_mapInitialCenter),
          records: gnssRecords,
          initialCenter: _mapInitialCenter,
          initialZoom: _mapInitialZoom,
        );
      default: return const SizedBox();
    }
  }

  Widget _buildHomeTab() {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 360;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Card ID',
                    style: TextStyle(fontSize: isSmallScreen ? 10 : 14),
                  ),
                ),
                icon: const Icon(Icons.badge_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Archive',
                    style: TextStyle(fontSize: isSmallScreen ? 10 : 14),
                  ),
                ),
                icon: const Icon(Icons.archive_outlined),
              ),
            ],
            selected: {_homeSubTabIndex},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _homeSubTabIndex = newSelection.first;
              });
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: primaryGreen,
              selectedForegroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 12,
                vertical: 8,
              ),
            ),
          ),
        ),
        Expanded(
          child: _homeSubTabIndex == 0 ? _buildCardIdView() : _buildArchiveView(),
        ),
      ],
    );
  }

  Widget _buildCardIdView() {
    if (cardId == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              onPressed: _pickAndParseFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('UPLOAD .DDD FILE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _readTachoCard,
              icon: const Icon(Icons.usb),
              label: const Text('READ CARD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(child: _buildIdCard());
  }

  void _saveToArchive() async {
    if (cardId == null) return;
    
    final bytes = TahoExporter().buildBytes(gen1Card: gen1Card, gen2Card: gen2Card);
    if (bytes.isEmpty) return;

    // Calculate MD5 hash of the bytes to use as a unique key
    final hash = md5.convert(bytes).toString();

    final archiveBox = Hive.box<ArchiveRecord>('archive_records');
    
    final record = ArchiveRecord(
      cardNumber: cardId!.cardNumber,
      driverName: '${cardId!.name} ${cardId!.surname}',
      downloadDate: DateTime.now(),
      rawBytes: bytes,
      isGen2: gen2Card != null,
      fileName: '${cardId!.name}_${cardId!.surname}'.replaceAll(' ', '_'),
    );
    
    // Use hash as key to automatically handle deduplication
    await archiveBox.put(hash, record);
  }

  Widget _buildArchiveView() {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ArchiveRecord>('archive_records').listenable(),
      builder: (context, Box<ArchiveRecord> box, _) {
        final records = box.values.toList().reversed.toList();
        
        if (records.isEmpty) {
          return const Center(child: Text("No archived files found."));
        }

        return ListView.builder(
          itemCount: records.length,
          itemBuilder: (context, index) {
            final record = records[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: primaryGreen.withOpacity(0.1),
                  child: Icon(record.isGen2 ? Icons.looks_two : Icons.looks_one, color: primaryGreen),
                ),
                title: Text(record.driverName),
                subtitle: Text("Added to archive: ${record.downloadDate.toLocal().toString().split('.')[0]}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => _loadFromArchive(record),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () async {
                        final bool confirm = await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Record'),
                            content: Text('Are you sure you want to delete the record for ${record.driverName}?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('CANCEL'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ) ?? false;
                        if (confirm) {
                          record.delete();
                        }
                      },
                    ),
                  ],
                ),
                onTap: () => _loadFromArchive(record),
              ),
            );
          },
        );
      },
    );
  }

  void _loadFromArchive(ArchiveRecord record) {
    setState(() => isLoading = true);
    
    final s = _extractAllSections(record.rawBytes);

    // Reconstruct Gen 1
    final g1 = TahoGen1Card(
      iccData: s['0002_0'] ?? Uint8List(0),
      icData: s['0005_0'] ?? Uint8List(0),
      cardCertDATAptr: s['c100_0'] ?? Uint8List(0),
      CACertDATAptr: s['c108_0'] ?? Uint8List(0),
      idData: s['0520_0'] ?? Uint8List(0),
      driverLicenseDATAptr: s['0521_0'] ?? Uint8List(0),
      activitiesDATAptr: s['0504_0'] ?? Uint8List(0),
      vehiclesDATAptr: s['0505_0'] ?? Uint8List(0),
      appIdentification: s['0501_0'] ?? Uint8List(0),
      cardDownload: s['050e_0'] ?? Uint8List(0),
      eventsData: s['0502_0'] ?? Uint8List(0),
      faultsData: s['0503_0'] ?? Uint8List(0),
      places: s['0506_0'] ?? Uint8List(0),
      currentUsage: s['0507_0'] ?? Uint8List(0),
      controlActivityData: s['0508_0'] ?? Uint8List(0),
      specificConditions: s['0522_0'] ?? Uint8List(0),
    );

    // Reconstruct Gen 2
    final g2 = TahoGen2Card(
      appIdentification: s['0501_2'] ?? Uint8List(0),
      cardCertDATAptr: s['c100_2'] ?? Uint8List(0),
      cardSignCertificate: s['c101_2'] ?? Uint8List(0),
      CACertDATAptr: s['c108_2'] ?? Uint8List(0),
      linkCertificate: s['c109_2'] ?? Uint8List(0),
      idData: s['0520_2'] ?? Uint8List(0),
      cardDownload: s['050e_2'] ?? Uint8List(0),
      driverLicenseDATAptr: s['0521_2'] ?? Uint8List(0),
      eventsData: s['0502_2'] ?? Uint8List(0),
      faultsData: s['0503_2'] ?? Uint8List(0),
      activitiesDATAptr: s['0504_2'] ?? Uint8List(0),
      vehiclesDATAptr: s['0505_2'] ?? Uint8List(0),
      places: s['0506_2'] ?? Uint8List(0),
      currentUsage: s['0507_2'] ?? Uint8List(0),
      controlActivityData: s['0508_2'] ?? Uint8List(0),
      specificConditions: s['0522_2'] ?? Uint8List(0),
      vehicleUnitsUsed: s['0523_2'] ?? Uint8List(0),
      GNSS: s['0524_2'] ?? Uint8List(0),
    );

    setState(() {
      gen1Card = g1.idData.isNotEmpty ? g1 : null;
      gen2Card = g2.idData.isNotEmpty ? g2 : null;
      _updateParsedData();
      _homeSubTabIndex = 0; // Switch to Card ID view to see loaded data
      isLoading = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded data for ${record.driverName}')),
    );
  }

  Widget _buildVehiclesTab() {
    if (vehicles.isEmpty) return const Center(child: Text("No vehicle data found."));
    return ListView.builder(
      itemCount: vehicles.length,
      itemBuilder: (context, index) => _buildDayCard(vehicles[index], index),
    );
  }

  Widget _buildIdCard() {
    final id = cardId!;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity, margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Text('${id.name} ${id.surname}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen))),
          const Divider(height: 30, thickness: 1),
          _idRow(Icons.credit_card, 'Card Number', id.cardNumber),
          _idRow(Icons.cake, 'Birthday', id.formattedBirthday),
          _idRow(Icons.calendar_today, 'Issue Date', id.startDate.toLocal().toString().split(' ').first),
          _idRow(Icons.calendar_today, 'Expiry Date', id.expiryDate.toLocal().toString().split(' ').first),
          _idRow(Icons.badge, 'Driver License', driverLicense?.licenseNumber ?? "/"),
          _idRow(Icons.public, 'Country', id.country),
          _idRow(Icons.business, 'Issuer', id.issuer),
          _idRow(Icons.history, 'Last Download', lastDownload?.formattedDate ?? '/'),
        ],
      ),
    );
  }

  Widget _idRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Text(value.isEmpty ? "/" : value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.onSurface)),
          ])),
        ],
      ),
    );
  }

  Widget _buildDayCard(DailyVehicles day, int index) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: theme.colorScheme.surface,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(day.date.toLocal().toString().split(' ').first, style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: const Icon(Icons.calendar_month, color: primaryGreen),
          children: day.vehicles.map((v) => ListTile(
            dense: true, title: Text(v.registration), subtitle: Text("${v.startTime.toLocal().toString().split(' ')[1].substring(0, 5)} - ${v.endTime.toLocal().toString().split(' ')[1].substring(0, 5)}"),
            trailing: Text("${v.endKm - v.startKm} km"),
          )).toList(),
        ),
      ),
    );
  }
}

// --- Custom Action Menu (Vertical Dropdown) ---

class ExpandingActionMenu extends StatelessWidget {
  final List<SpeedDialAction> actions;

  const ExpandingActionMenu({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      offset: const Offset(0, 45), // Odpre se tik pod vrstico
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (index) => actions[index].onPressed(),
      itemBuilder: (context) => List.generate(actions.length, (index) {
        final action = actions[index];
        return PopupMenuItem<int>(
          value: index,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: const Color(0xFF28B52F), size: 22),
              const SizedBox(width: 12),
              Text(
                action.label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class SpeedDialAction {
  final IconData icon;
  final VoidCallback onPressed;
  final String label;

  SpeedDialAction({
    required this.icon,
    required this.onPressed,
    required this.label,
  });
}

class SettingsScreen extends StatefulWidget {
  final bool isGen2View;
  final ValueChanged<bool> onGen2ViewChanged;

  const SettingsScreen({
    super.key,
    required this.isGen2View,
    required this.onGen2ViewChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _localIsGen2View;
  bool _under50km = false;

  @override
  void initState() {
    super.initState();
    _localIsGen2View = widget.isGen2View;
    _loadUnder50km();
  }

  Future<void> _loadUnder50km() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _under50km = prefs.getBool('under50km') ?? false;
    });
  }

  Future<void> _setUnder50km(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('under50km', value);
    setState(() {
      _under50km = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Data View Generation",
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B52F)),
            ),
          ),
          RadioListTile<bool>(
            title: const Text("Generation 1"),
            subtitle: const Text("Show standard data and vehicle usage"),
            value: false,
            groupValue: _localIsGen2View,
            onChanged: (val) {
              if (val != null) {
                setState(() => _localIsGen2View = val);
                widget.onGen2ViewChanged(val);
              }
            },
            activeColor: const Color(0xFF28B52F),
          ),
          RadioListTile<bool>(
            title: const Text("Generation 2"),
            subtitle: const Text("Show advanced data including GNSS records"),
            value: true,
            groupValue: _localIsGen2View,
            onChanged: (val) {
              if (val != null) {
                setState(() => _localIsGen2View = val);
                widget.onGen2ViewChanged(val);
              }
            },
            activeColor: const Color(0xFF28B52F),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Overdrive Settings",
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B52F)),
            ),
          ),
          SwitchListTile(
            title: const Text("Under 50 km"),
            value: _under50km,
            onChanged: _setUnder50km,
            activeColor: const Color(0xFF28B52F),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Text(
              "NOTE: For the application to correctly detect overdrive, the card must be inserted in the tachograph and kept under constant voltage, meaning that electrical power must be continuously supplied.",
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text("Privacy Policy"),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Privacy Policy"),
                  content: const SingleChildScrollView(
                    child: Text(
                      "This application processes all tachograph data locally on your device. "
                      "No personal data or card information is uploaded to any server. "
                      "Application uses only the device's USB and Internet permissions strictly for card reading and GNSS mapping.",
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE"),
                    ),
                  ],
                ),
              );
            },
          ),
          const ListTile(title: Text("Version"), trailing: Text("1.2.1")),
        ],
      ),
    );
  }
}
