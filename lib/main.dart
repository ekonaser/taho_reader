import 'dart:developer' as developer;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'activity_timeline.dart';
import 'openstreetmap.dart';
import 'taho_exporter.dart';
import 'taho_models.dart';
import 'taho_parser.dart';
import 'taho_reader.dart';

void main() {
  runApp(const TahoApp());
}

class TahoApp extends StatelessWidget {
  const TahoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tacho Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF28B52F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF28B52F),
          primary: const Color(0xFF28B52F),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF28B52F),
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
  List<GnssRecord> gnssRecords = [];
  List<DailyActivities> activities = [];
  List<Violation> violations = [];
  TahoGen2Card? gen2Card;
  TahoGen1Card? gen1Card;
  bool _isGen2View = false;
  DateTime? _selectedActivityDate;
  bool isLoading = false;
  int _selectedTabIndex = 0;
  int _utcOffset = 0;

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
      if (_isGen2View) {
        if (gen2Card != null) {
          cardId = gen2Card!.idData.isNotEmpty ? parserG2.parseCardId(gen2Card!.idData) : null;
          driverLicense = gen2Card!.driverLicenseDATAptr.isNotEmpty ? parserG2.parseDriverLicense(gen2Card!.driverLicenseDATAptr) : null;
          lastDownload = gen2Card!.cardDownload.isNotEmpty ? parserG2.parseLastDownload(gen2Card!.cardDownload) : null;
          activities = gen2Card!.activitiesDATAptr.isNotEmpty ? parserG2.parseActivities(gen2Card!.activitiesDATAptr) : [];
          gnssRecords = parserG2.parseGnss(gen2Card!.GNSS);
          vehicles = [];
        } else {
          // Reset view if no Gen 2 data is available
          cardId = null;
          driverLicense = null;
          lastDownload = null;
          activities = [];
          gnssRecords = [];
          vehicles = [];
        }
      } else {
        if (gen1Card != null) {
          cardId = parser.parseCardId(gen1Card!.idData);
          driverLicense = parser.parseDriverLicense(gen1Card!.driverLicenseDATAptr);
          lastDownload = parser.parseLastDownload(gen1Card!.cardDownload);
          vehicles = parser.parseVehicles(gen1Card!.vehiclesDATAptr);
          activities = parser.parseActivities(gen1Card!.activitiesDATAptr);
          gnssRecords = [];
        } else {
          // Reset view if no Gen 1 data is available
          cardId = null;
          driverLicense = null;
          lastDownload = null;
          vehicles = [];
          activities = [];
          gnssRecords = [];
        }
      }
    });
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
      setState(() => isLoading = true);

      if (!await _tahoReader.init()) throw 'USB reader not available';
      await _tahoReader.getATR(); 
      if (!await _tahoReader.isConnected()) throw 'Reader not connected';
      if (!await _tahoReader.isCardPresent()) throw 'Card not detected';

      setState(() {
        cardId = null;
        driverLicense = null;
        vehicles = [];
        activities = [];
        violations = [];
        gnssRecords = [];
        gen1Card = null;
        gen2Card = null;
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
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x00, 0x02]));
    final iccData = await _tahoReader.readData(25);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x00, 0x05]));
    final icData = await _tahoReader.readData(8);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C, 0x06, 0xFF, 0x54, 0x41, 0x43, 0x48, 0x4F]));
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x00]));
    final cardCert = await _tahoReader.readData(194);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x08]));
    final caCert = await _tahoReader.readData(194);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x20]));
    final idData = await _tahoReader.readData(143);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x21]));
    final license = await _tahoReader.readData(53);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x04]));
    final activities = await _tahoReader.readData(13780);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x05]));
    final vehicles = await _tahoReader.readData(6202);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x01]));
    final appId = await _tahoReader.readData(10);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x0E]));
    final download = await _tahoReader.readData(4);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x02]));
    final events = await _tahoReader.readData(1728);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x03]));
    final faults = await _tahoReader.readData(1152);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x06]));
    final places = await _tahoReader.readData(1121);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x07]));
    final usage = await _tahoReader.readData(19);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x08]));
    final control = await _tahoReader.readData(46);
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x22]));
    final conditions = await _tahoReader.readData(280);

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
    // selecting SMRDT app
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C, 0x06, 0xFF, 0x53, 0x4D, 0x52, 0x44, 0x54]));

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x01]));
    final appId = await _tahoReader.readData(15);

    // CardMA Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x00]));
    final cardCert = await _tahoReader.readData(205);

    // Card Sign Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x01]));
    final cardSignCert = await _tahoReader.readData(205);

    // CA Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x08]));
    final caCert = await _tahoReader.readData(205);

    // Link Certificate
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0xC1, 0x09]));
    final linkCert = await _tahoReader.readData(205);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x20]));
    final idData = await _tahoReader.readData(143);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x0E]));
    final download = await _tahoReader.readData(4);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x21]));
    final license = await _tahoReader.readData(53);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x02]));
    final events = await _tahoReader.readData(3168);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x03]));
    final faults = await _tahoReader.readData(1152);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x04]));
    final activities = await _tahoReader.readData(13780);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x05]));
    final vehicles = await _tahoReader.readData(9602);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x06]));
    final places = await _tahoReader.readData(2354);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x07]));
    final usage = await _tahoReader.readData(19);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x08]));
    final control = await _tahoReader.readData(46);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x22]));
    final conditions = await _tahoReader.readData(562);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x23]));
    final units = await _tahoReader.readData(2002);

    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x24]));
    final gnssData = await _tahoReader.readData(5042);

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
            IconButton(onPressed: _pickAndParseFile, icon: const Icon(Icons.file_open)),
            IconButton(onPressed: _saveToDdd, icon: const Icon(Icons.save)),
            IconButton(onPressed: _readTachoCard, icon: const Icon(Icons.usb)),
            IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings)),
          ],
        ),
        body: isLoading 
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : _buildTabContent(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTabIndex,
          onTap: (index) => setState(() => _selectedTabIndex = index),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryGreen,
          unselectedItemColor: Colors.grey,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Vehicles'),
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
      case 0: return 'Dashboard';
      case 1: return 'Vehicle Usage';
      case 2: return 'Activity Timeline';
      case 3: return 'Violations';
      case 4: return 'GNSS Map';
      default: return 'Tacho Reader';
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: return _buildHomeTab();
      case 1: return _buildVehiclesTab();
      case 2:
        return ActivityTimeline(
          activities: activities,
          cardId: cardId,
          selectedDate: _selectedActivityDate,
          utcOffset: _utcOffset,
          onUtcOffsetChanged: (offset) => setState(() => _utcOffset = offset),
          onDateTap: _selectActivityDate,
        );
      case 4: return OpenStreetMapScreen(records: gnssRecords);
      default: return const SizedBox();
    }
  }

  Widget _buildHomeTab() {
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
                backgroundColor: primaryGreen, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _readTachoCard,
              icon: const Icon(Icons.usb),
              label: const Text('READ TAHO CARD'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen, foregroundColor: Colors.white,
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

  Widget _buildVehiclesTab() {
    if (vehicles.isEmpty) return const Center(child: Text("No vehicle data found."));
    return ListView.builder(
      itemCount: vehicles.length,
      itemBuilder: (context, index) => _buildDayCard(vehicles[index], index),
    );
  }

  Widget _buildIdCard() {
    final id = cardId!;
    return Container(
      width: double.infinity, margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: primaryGreen.withOpacity(0.2)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            Text(value.isEmpty ? "/" : value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
          ])),
        ],
      ),
    );
  }

  Widget _buildDayCard(DailyVehicles day, int index) {
    return Card(
      elevation: 2, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
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

  @override
  void initState() {
    super.initState();
    _localIsGen2View = widget.isGen2View;
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
          const ListTile(title: Text("Version"), trailing: Text("1.0.0")),
        ],
      ),
    );
  }
}
