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
      itemCount: widget.places.length,
      itemBuilder: (context, index) {
        final place = widget.places[index];
        return ListTile(
          title: Text("Place ${place.dailyWorkPeriodCountry}"),
          subtitle: Text(place.entryTime.toString()),
        );
      },
    );
  }
}
