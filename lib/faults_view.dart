import 'package:flutter/material.dart';
import 'taho_models.dart';

class FaultsView extends StatefulWidget {
  final List<TahoFault> vehicleFaults;
  final List<TahoFault> driverEvents;
  final List<TahoFault> detectedEvents;

  const FaultsView({
    super.key,
    required this.vehicleFaults,
    required this.driverEvents,
    this.detectedEvents = const [],
  });

  @override
  State<FaultsView> createState() => _FaultsViewState();
}

enum _FaultViewMode { vehicle, driver, appDetected }

class _FaultsViewState extends State<FaultsView> {
  _FaultViewMode _viewMode = _FaultViewMode.vehicle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryGreen = theme.primaryColor;
    
    return Column(
      children: [
        // Toggle Selector (Same style as ActivityTimeline)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildToggleItem(
                  context,
                  "Vehicle", 
                  _viewMode == _FaultViewMode.vehicle, 
                  () => setState(() => _viewMode = _FaultViewMode.vehicle), 
                  primaryGreen
                ),
                _buildToggleItem(
                  context,
                  "Driver", 
                  _viewMode == _FaultViewMode.driver, 
                  () => setState(() => _viewMode = _FaultViewMode.driver), 
                  primaryGreen
                ),
                _buildToggleItem(
                  context,
                  "Overdrive",
                  _viewMode == _FaultViewMode.appDetected, 
                  () => setState(() => _viewMode = _FaultViewMode.appDetected), 
                  primaryGreen
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    switch (_viewMode) {
      case _FaultViewMode.vehicle:
        return widget.vehicleFaults.isEmpty
            ? _buildEmptyState(context, "No technical faults found.")
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: widget.vehicleFaults.length,
                itemBuilder: (context, index) => _buildFaultCard(context, widget.vehicleFaults[index]),
              );
      case _FaultViewMode.driver:
        return widget.driverEvents.isEmpty
            ? _buildEmptyState(context, "No driver events found.")
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: widget.driverEvents.length,
                itemBuilder: (context, index) => _buildFaultCard(context, widget.driverEvents[index]),
              );
      case _FaultViewMode.appDetected:
        final colorScheme = Theme.of(context).colorScheme;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "NOTE: This overdrive detection is not applicable for journeys within a 50 km radius of the base, as they are exempt from standard driving time regulations.",
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Expanded(
              child: widget.detectedEvents.isEmpty
                  ? _buildEmptyState(context, "No detected events found.")
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: widget.detectedEvents.length,
                      itemBuilder: (context, index) => _buildFaultCard(context, widget.detectedEvents[index]),
                    ),
            ),
          ],
        );
    }
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Center(
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildToggleItem(BuildContext context, String label, bool isSelected, VoidCallback onTap, Color primaryGreen) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFaultCard(BuildContext context, TahoFault fault) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _getFaultTitle(fault.type);
    final isSecurity = fault.type >= 0x10 && fault.type <= 0x2F;
    final isOverdrive = fault.type == 0xFF;
    final isFault = !isOverdrive && fault.type >= 0x30;

    final iconColor = isOverdrive || isSecurity ? Colors.red : (isFault ? Colors.orange : Colors.blue);
    final icon = isOverdrive ? Icons.warning_amber_rounded : (isSecurity ? Icons.security : (isFault ? Icons.error_outline : Icons.info_outline));

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: colorScheme.surface,
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
                  child: Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: colorScheme.onSurface),
                  ),
                ),
                Text(
                  "0x${fault.type.toRadixString(16).padLeft(2, '0').toUpperCase()}",
                  style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            if (isOverdrive)
              _faultDetailRow(context, Icons.calendar_today, "Date", fault.beginTime.toLocal().toString().split(' ')[0])
            else ...[
              _faultDetailRow(context, Icons.access_time, "Start", fault.beginTime.toLocal().toString().split('.')[0]),
              _faultDetailRow(context, Icons.timer_off, "End", fault.endTime.toLocal().toString().split('.')[0]),
              _faultDetailRow(context, Icons.directions_car, "Vehicle", fault.vehicleRegistrationNumber),
            ],
          ],
        ),
      ),
    );
  }

  Widget _faultDetailRow(BuildContext context, IconData icon, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: colorScheme.onSurface)),
        ],
      ),
    );
  }

  String _getFaultTitle(int type) {
    if (type == 0xFF) return "Overdrive Detected";
    switch (type) {
      case 0x00: return "General Event (No details)";
      case 0x01: return "Insertion of non-valid card";
      case 0x02: return "Card conflict";
      case 0x03: return "Time overlap";
      case 0x04: return "Driving without appropriate card";
      case 0x05: return "Card insertion while driving";
      case 0x06: return "Last card session not correctly closed";
      case 0x07: return "Over speeding";
      case 0x08: return "Power supply interruption";
      case 0x09: return "Motion data error";
      case 0x0A: return "Vehicle Motion Conflict";
      case 0x0B: return "Time conflict (GNSS vs VU)";
      case 0x10: return "Security breach (No details)";
      case 0x11: return "Motion sensor authentication failure";
      case 0x12: return "Card authentication failure";
      case 0x13: return "Unauthorised change of sensor";
      case 0x14: return "Card data integrity error";
      case 0x15: return "Stored data integrity error";
      case 0x16: return "Internal data transfer error";
      case 0x17: return "Unauthorised case opening";
      case 0x18: return "Hardware sabotage";
      case 0x20: return "Sensor security breach";
      case 0x30: return "Recording equipment fault";
      case 0x31: return "VU internal fault";
      case 0x32: return "Printer fault";
      case 0x33: return "Display fault";
      case 0x34: return "Downloading fault";
      case 0x35: return "Sensor fault";
      case 0x40: return "Card fault";
      case 0x50: return "GNSS fault";
      case 0x51: return "Internal GNSS receiver fault";
      case 0x52: return "External GNSS receiver fault";
      case 0x53: return "GNSS communication fault";
      case 0x54: return "No GNSS position data";
      case 0x55: return "Tamper detection of GNSS";
      case 0x56: return "GNSS certificate expired";
      case 0x60: return "Remote communication fault";
      case 0x61: return "Remote module fault";
      case 0x62: return "Remote communication error";
      case 0x70: return "ITS interface fault";
      default: return "Unknown Fault (0x${type.toRadixString(16)})";
    }
  }
}
