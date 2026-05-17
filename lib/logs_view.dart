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
    final String name;
    switch (code) {
      case 1: name = "A"; break;
      case 2: name = "AL"; break;
      case 3: name = "AND"; break;
      case 4: name = "ARM"; break;
      case 5: name = "AZ"; break;
      case 6: name = "B"; break;
      case 7: name = "BG"; break;
      case 8: name = "BIH"; break;
      case 9: name = "BY"; break;
      case 10: name = "CH"; break;
      case 11: name = "CY"; break;
      case 12: name = "CZ"; break;
      case 13: name = "D"; break;
      case 14: name = "DK"; break;
      case 15: name = "E"; break;
      case 16: name = "EST"; break;
      case 17: name = "F"; break;
      case 18: name = "FIN"; break;
      case 19: name = "FL"; break;
      case 20: name = "FR, FO"; break;
      case 21: name = "UK"; break;
      case 22: name = "GE"; break;
      case 23: name = "GR"; break;
      case 24: name = "H"; break;
      case 25: name = "HR"; break;
      case 26: name = "I"; break;
      case 27: name = "IRL"; break;
      case 28: name = "IS"; break;
      case 29: name = "KZ"; break;
      case 30: name = "L"; break;
      case 31: name = "LT"; break;
      case 32: name = "LV"; break;
      case 33: name = "M"; break;
      case 34: name = "MC"; break;
      case 35: name = "MD"; break;
      case 36: name = "MK"; break;
      case 37: name = "N"; break;
      case 38: name = "NL"; break;
      case 39: name = "P"; break;
      case 40: name = "PL"; break;
      case 41: name = "RO"; break;
      case 42: name = "RSM"; break;
      case 43: name = "RUS"; break;
      case 44: name = "S"; break;
      case 45: name = "SK"; break;
      case 46: name = "SLO"; break;
      case 47: name = "TM"; break;
      case 48: name = "TR"; break;
      case 49: name = "UA"; break;
      case 50: name = "V"; break;
      case 51: name = "YU"; break;
      case 52: name = "MNE"; break;
      case 53: name = "SRB"; break;
      case 54: name = "UZ"; break;
      case 55: name = "UNK"; break; // currently unknown not the actual value 55
      case 253: name = "EC"; break;
      case 254: name = "EUR"; break;
      case 255: name = "WLD"; break;
      default:
        return "Unknown ($code)";
    }
    return "$name";
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
