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
            title: Text(v.registration),
            subtitle: Text("${v.startTime.toLocal().toString().split(' ')[1].substring(0, 5)} - ${v.endTime.toLocal().toString().split(' ')[1].substring(0, 5)}"),
            trailing: Text("${v.endKm - v.startKm} km"),
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
            _detailRow(Icons.public, "Country", _getCountryName(place.dailyWorkPeriodCountry)),
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

  String _getCountryName(int code) {
    switch (code) {
      case 0: return "Undefined / Unknown";
      case 1: return "Albania";
      case 2: return "Andorra";
      case 3: return "Armenia";
      case 4: return "Austria";
      case 5: return "Azerbaijan";
      case 6: return "Belgium";
      case 7: return "Bosnia and Herzegovina";
      case 8: return "Bulgaria";
      case 9: return "Croatia";
      case 10: return "Cyprus";
      case 11: return "Czech Republic";
      case 12: return "Denmark";
      case 13: return "Estonia";
      case 14: return "Finland";
      case 15: return "France";
      case 16: return "Georgia";
      case 17: return "Germany";
      case 18: return "Greece";
      case 19: return "Hungary";
      case 20: return "Iceland";
      case 21: return "Ireland";
      case 22: return "Italy";
      case 23: return "Kazakhstan";
      case 24: return "Kosovo";
      case 25: return "Latvia";
      case 26: return "Liechtenstein";
      case 27: return "Lithuania";
      case 28: return "Luxembourg";
      case 29: return "Malta";
      case 30: return "Moldova";
      case 31: return "Monaco";
      case 32: return "Montenegro";
      case 33: return "Netherlands";
      case 34: return "North Macedonia";
      case 35: return "Norway";
      case 36: return "Poland";
      case 37: return "Portugal";
      case 38: return "Romania";
      case 39: return "Russian Federation";
      case 40: return "San Marino";
      case 41: return "Serbia";
      case 42: return "Slovakia";
      case 43: return "Spain";
      case 44: return "Sweden";
      case 45: return "Switzerland";
      case 46: return "Slovenia";
      case 47: return "Türkiye";
      case 48: return "Ukraine";
      case 49: return "United Kingdom";
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
