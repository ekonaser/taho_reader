import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

import 'taho_models.dart';
import 'taho_parser.dart';
import 'taho_reader.dart';
import 'openstreetmap.dart';
import 'activity_timeline.dart';

void main() {
  runApp(const TahoApp());
}

class TahoApp extends StatelessWidget {
  const TahoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taho Reader',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 2,
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
  List<DailyVehicles> vehicles = [];
  List<GnssRecord> gnssRecords = [];
  List<DailyActivities> activities = [];
  List<Violation> violations = [];
  TahoGen2Card? gen2Card;
  TahoGen1Card? gen1Card;
  DateTime? _selectedActivityDate;
  bool isLoading = false;
  int _selectedTabIndex = 0;
  int utcOffset = 0; // UTC offset v minutah (npr. 60 za UTC+1)

  final TahoReader _tahoReader = TahoReader();
  static const primaryGreen = Color(0xFF28B52F);

  @override
  void initState() {
    super.initState();
  }

  Map<String, Uint8List> _extractEFSections(Uint8List bytes) {
    final Map<String, Uint8List> out = {};

    Uint8List? findSection(int b1, int b2, int gen, int l1, int l2) {
      // Iščemo natančen 5-bajtni header: [ID1, ID2, GEN, LEN_H, LEN_L]
      for (int i = 0; i <= bytes.length - 5; i++) {
        if (bytes[i] == b1 &&
            bytes[i + 1] == b2 &&
            bytes[i + 2] == gen &&
            bytes[i + 3] == l1 &&
            bytes[i + 4] == l2) {

          final int len = (l1 << 8) | l2;
          final int start = i + 5;

          if (start + len <= bytes.length) {
            print("Sekcija 0x${b1.toRadixString(16).padLeft(2, '0')} 0x${b2.toRadixString(16).padLeft(2, '0')}");
            print("Dolzina sekcije: ${(l1 << 8) | l2}");
            return bytes.sublist(start, start + len);
          }
        }
      }
      return null;
    }

    // Iskanje sekcij z natančnimi headerji iz tvoje C++ kodo (WriteDDD)

    // Identification (05 20) - 143 bajtov (00 8F)
    final id = findSection(0x05, 0x20, 0x00, 0x00, 0x8F) ??
        findSection(0x05, 0x20, 0x02, 0x00, 0x8F);
    if (id != null) out['id'] = id;

    // Vehicles (05 05) - Gen1: 6202 (18 3A), Gen2: 9602 (25 82)
    final veh = findSection(0x05, 0x05, 0x00, 0x18, 0x3A) ??
        findSection(0x05, 0x05, 0x02, 0x25, 0x82);
    if (veh != null) out['veh'] = veh;

    // Activities (05 04) - 13780 bajtov (35 D4)
    final act = findSection(0x05, 0x04, 0x00, 0x35, 0xD4) ??
        findSection(0x05, 0x04, 0x02, 0x35, 0xD4);
    if (act != null) out['act'] = act;

    // GNSS (05 24) - 5042 bajtov (13 B2)
    final gnss = findSection(0x05, 0x24, 0x02, 0x13, 0xB2);
    if (gnss != null) out['gnss'] = gnss;

    return out;
  }

  Future<void> _pickAndParseFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;

      setState(() => isLoading = true);

      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();

      final ef = _extractEFSections(bytes);
      final parser = TahoParser();

      if (ef.containsKey('id')) {
        setState(() {
          cardId = parser.parseCardId(ef['id']!);
        });
      }

      if (ef.containsKey('act')) {
        setState(() {
          activities = parser.parseActivities(ef['act']!);
        });
      }

      if (ef.containsKey('veh')) {
        setState(() {
          vehicles = parser.parseVehicles(ef['veh']!);
        });
      }

      if (ef.containsKey('gnss')) {
        setState(() {
          gnssRecords = parser.parseGnss(ef['gnss']!);
        });
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _readTachoCard() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final available = await _tahoReader.init();
      if (!available) throw 'USB reader not available';
      await _tahoReader.getATR(); // To bo zdaj sprožilo powerOnCard v Kotlinu

      final connected = await _tahoReader.isConnected();
      if (!connected) throw 'USB reader is not connected';

      final cardPresent = await _tahoReader.isCardPresent();
      if (!cardPresent) throw 'No card detected';

      // Reset data
      setState(() {
        cardId = null;
        vehicles = [];
        activities = [];
        violations = [];
        gnssRecords = [];
      });

      // 1. Always try to read Gen 1 data (the main data we parse)
      try {
        gen1Card = await _readGen1Card();
        final parser = TahoParser();
        
        final parsedCardId = parser.parseCardId(gen1Card!.idData);
        final parsedVehicles = parser.parseVehicles(gen1Card!.vehiclesDATAptr);
        final parsedActivities = parser.parseActivities(gen1Card!.activitiesDATAptr);
        final parsedViolations = parser.findViolations(parsedActivities);

        setState(() {
          cardId = parsedCardId;
          vehicles = parsedVehicles;
          activities = parsedActivities;
          violations = parsedViolations;
        });
      } catch (e) {
        developer.log("Error reading Gen 1: $e");
      }

      // 2. Always try to read Gen 2 GNSS data
      try {
        gen2Card = await _readGen2Card();
        final parsedGnss = TahoParser().parseGnss(gen2Card!.GNSS);
        setState(() {
          gnssRecords = parsedGnss;
        });
      } catch (e) {
        developer.log("Not a Gen 2 card or error reading Gen 2 GNSS: $e");
      }

      if (cardId == null && gnssRecords.isEmpty) {
        throw "Failed to read any valid data from card";
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<TahoGen1Card> _readGen1Card() async {
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
    // Select SMRDT DF
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C, 0x06, 0xFF, 0x53, 0x4D, 0x52, 0x44, 0x54]));

    // Read ONLY GNSS (0x0524) for coordinates
    await _tahoReader.selectFile(Uint8List.fromList([0x00, 0xA4, 0x02, 0x0C, 0x02, 0x05, 0x24]));
    final gnssData = await _tahoReader.readData(5042);

    return TahoGen2Card(
      appIdentification: Uint8List(0),
      cardCertDATAptr: Uint8List(0),
      cardSignCertificate: Uint8List(0),
      CACertDATAptr: Uint8List(0),
      linkCertificate: Uint8List(0),
      idData: Uint8List(0),
      cardDownload: Uint8List(0),
      driverLicenseDATAptr: Uint8List(0),
      eventsData: Uint8List(0),
      faultsData: Uint8List(0),
      activitiesDATAptr: Uint8List(0),
      places: Uint8List(0),
      currentUsage: Uint8List(0),
      controlActivityData: Uint8List(0),
      specificConditions: Uint8List(0),
      vehicleUnitsUsed: Uint8List(0),
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
    final int? result = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(currentUtcOffset: utcOffset)),
    );
    if (result != null) {
      setState(() => utcOffset = result);
    }
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
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit'),
            content: const Text('Are you sure you want to exit? All read data will be lost.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('YES')),
            ],
          ),
        );
        if (shouldPop ?? false) exit(0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_getTabTitle()),
          actions: [
            IconButton(icon: const Icon(Icons.file_open), onPressed: _pickAndParseFile),
            IconButton(icon: const Icon(Icons.list_alt), onPressed: _showLogs),
            IconButton(icon: const Icon(Icons.usb), onPressed: _readTachoCard),
            IconButton(icon: const Icon(Icons.settings), onPressed: _showSettings),
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
          backgroundColor: Colors.white,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.directions_car), label: 'Vehicles'),
            BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Activity'),
            BottomNavigationBarItem(icon: Icon(Icons.warning_amber), label: 'Foul'),
            BottomNavigationBarItem(icon: Icon(Icons.map), label: 'GNSS'),
          ],
        ),
      ),
    );
  }

  String _getTabTitle() {
    switch (_selectedTabIndex) {
      case 0: return 'Driver Details';
      case 1: return 'Vehicle History';
      case 2: return 'Activities';
      case 3: return 'Violations';
      case 4: return 'GNSS Location';
      default: return 'Taho Reader';
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0: return _buildHomeTab();
      case 1: return _buildVehiclesTab();
      case 2:
        final filtered = _selectedActivityDate == null
            ? activities
            : activities.where((a) =>
        a.date.year == _selectedActivityDate!.year &&
            a.date.month == _selectedActivityDate!.month &&
            a.date.day == _selectedActivityDate!.day).toList();
        return ActivityTimeline(activities: filtered, onDateTap: _selectActivityDate);
      case 3: return _buildViolationsTab();
      case 4: return OpenStreetMapScreen(records: gnssRecords);
      default: return const SizedBox();
    }
  }

  Widget _buildViolationsTab() {
    if (violations.isEmpty) {
      return const Center(child: Text("No violations detected. Good job!"));
    }
    return ListView.builder(
      itemCount: violations.length,
      itemBuilder: (context, index) {
        final v = violations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.warning, color: Colors.orange),
            title: Text(v.type),
            subtitle: Text("${v.time.toLocal()}\n${v.description}"),
          ),
        );
      },
    );
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
    if (vehicles.isEmpty) return const Center(child: Text("No vehicle data found.", textAlign: TextAlign.center));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
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
          _idRow(Icons.badge, 'Driver License', '0'),
          _idRow(Icons.public, 'Country', id.country),
          _idRow(Icons.business, 'Issuer', id.issuer),
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
      child: ExpansionTile(
        title: Text(day.date.toLocal().toString().split(' ').first, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: const Icon(Icons.calendar_month, color: primaryGreen),
        children: day.vehicles.map((v) => ListTile(
          dense: true, title: Text(v.registration), subtitle: Text("${v.startTime.toLocal().toString().split(' ')[1].substring(0, 5)} - ${v.endTime.toLocal().toString().split(' ')[1].substring(0, 5)}"),
          trailing: Text("${v.endKm - v.startKm} km"),
        )).toList(),
      ),
    );
  }

  Future<void> _showLogs() async {
    final logs = await _tahoReader.getLogs();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6, expand: false,
        builder: (context, scrollController) => ListView.builder(
          controller: scrollController, itemCount: logs.length,
          itemBuilder: (context, index) => Padding(padding: const EdgeInsets.all(8), child: Text(logs[index], style: const TextStyle(fontSize: 10))),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final int currentUtcOffset;
  const SettingsScreen({super.key, required this.currentUtcOffset});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);
    final List<Map<String, dynamic>> options = [
      {'label': 'UTC +0 (London)', 'value': 0},
      {'label': 'UTC +1 (Ljubljana/Berlin)', 'value': 60},
      {'label': 'UTC +2 (Athens/Kiev)', 'value': 120},
      {'label': 'UTC +3 (Istanbul)', 'value': 180},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text("Time Zone (UTC Offset)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          ...options.map((opt) => RadioListTile<int>(
            title: Text(opt['label']), value: opt['value'], groupValue: currentUtcOffset,
            activeColor: primaryGreen, onChanged: (val) => Navigator.pop(context, val),
          )),
          const Divider(),
          const ListTile(title: Text("Version"), trailing: Text("1.0.0")),
        ],
      ),
    );
  }
}