import 'package:flutter/material.dart';
import 'taho_models.dart';

class LogsView extends StatefulWidget {
  final List<DailyVehicles> vehicles;
  final List<PlaceRecord> places;

  const LogsView({
    super.key,
    required this.vehicles,
    required this.places,
  });

  @override
  State<LogsView> createState() => _LogsViewState();
}

enum _LogViewMode { vehicles, places }

class _LogsViewState extends State<LogsView> {
  _LogViewMode _viewMode = _LogViewMode.vehicles;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);

    return Column(
      children: [
        // Toggle Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildToggleItem(
                  "Vehicles",
                  _viewMode == _LogViewMode.vehicles,
                  () => setState(() => _viewMode = _LogViewMode.vehicles),
                  primaryGreen
                ),
                _buildToggleItem(
                  "Places",
                  _viewMode == _LogViewMode.places,
                  () => setState(() => _viewMode = _LogViewMode.places),
                  primaryGreen
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _viewMode == _LogViewMode.vehicles
              ? (widget.vehicles.isEmpty
                  ? _buildEmptyState("No vehicle data found.")
                  : ListView.builder(
                      itemCount: widget.vehicles.length,
                      itemBuilder: (context, index) => _buildDayCard(widget.vehicles[index]),
                    ))
              : (widget.places.isEmpty
                  ? _buildEmptyState("No place records found.")
                  : _buildPlacesList()),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isSelected, VoidCallback onTap, Color primaryGreen) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayCard(DailyVehicles day) {
    const primaryGreen = Color(0xFF28B52F);
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            dense: true,
            title: Text(v.registration, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              "${v.startTime.toLocal().toString().split(' ')[1].substring(0, 5)} - ${v.endTime.toLocal().toString().split(' ')[1].substring(0, 5)}\n"
              "${v.startKm} - ${v.endKm}",
            ),
            isThreeLine: true,
            trailing: Text(
              "${v.endKm - v.startKm} km",
              style: const TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildPlacesList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: widget.places.length,
      itemBuilder: (context, index) => _buildPlaceCard(widget.places[index]),
    );
  }

  Widget _buildPlaceCard(PlaceRecord place) {
    final typeInfo = _getEntryTypeInfo(place.entryTypeDailyWorkPeriod);
    final isBegin = place.entryTypeDailyWorkPeriod % 2 == 0;
    final iconColor = isBegin ? Colors.green : Colors.orange;
    final icon = isBegin ? Icons.login : Icons.logout;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBegin ? "BEGIN" : "END",
                        style: TextStyle(
                          color: iconColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        typeInfo,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Text(
                  "0x${place.entryTypeDailyWorkPeriod.toRadixString(16).padLeft(2, '0').toUpperCase()}",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _detailRow(Icons.access_time, "Time", place.entryTime.toLocal().toString().split('.')[0]),
            _detailRow(Icons.speed, "Odometer", "${place.vehicleOdometerValue} km"),
            _detailRow(Icons.public, "Country", _getCountryCode(place.dailyWorkPeriodCountry)),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  String _getCountryCode(int code) {
    switch (code) {
      case 1: return "A";
      case 2: return "AL";
      case 3: return "AND";
      case 4: return "ARM";
      case 5: return "AZ";
      case 6: return "B";
      case 7: return "BG";
      case 8: return "BIH";
      case 9: return "BY";
      case 10: return "CH";
      case 11: return "CY";
      case 12: return "CZ";
      case 13: return "D";
      case 14: return "DK";
      case 15: return "E";
      case 16: return "EC";
      case 17: return "EST";
      case 18: return "F";
      case 19: return "FIN";
      case 20: return "FL";
      case 21: return "FR";
      case 22: return "GE";
      case 23: return "GR";
      case 24: return "H";
      case 25: return "HR";
      case 26: return "I";
      case 27: return "IRL";
      case 28: return "IS";
      case 29: return "KZ";
      case 30: return "L";
      case 31: return "LT";
      case 32: return "LV";
      case 33: return "M";
      case 34: return "MC";
      case 35: return "MD";
      case 36: return "MK";
      case 37: return "N";
      case 38: return "NL";
      case 39: return "P";
      case 40: return "PL";
      case 41: return "RO";
      case 42: return "RSM";
      case 43: return "RUS";
      case 44: return "S";
      case 45: return "SK";
      case 46: return "SLO";
      case 47: return "TM";
      case 48: return "TR";
      case 49: return "UA";
      case 50: return "UK";
      case 51: return "UNK";
      case 52: return "V";
      case 53: return "WLD";
      case 54: return "YU";
      case 255: return "EUR";
      default: return "Unknown ($code)";
    }
  }

  String _getEntryTypeInfo(int type) {
    switch (type) {
      case 0: return "Card Insertion";
      case 1: return "Card Withdrawal";
      case 2: return "Manual Entry (Start)";
      case 3: return "Manual Entry (End)";
      case 4: return "Assumed by VU (Start)";
      case 5: return "Assumed by VU (End)";
      default: return "Unknown Entry Type";
    }
  }
}
