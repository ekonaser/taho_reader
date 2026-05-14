import 'package:flutter/material.dart';
import 'taho_models.dart';

class FaultsView extends StatefulWidget {
  final List<TahoFault> vehicleFaults;
  final List<TahoFault> driverEvents;

  const FaultsView({
    super.key,
    required this.vehicleFaults,
    required this.driverEvents,
  });

  @override
  State<FaultsView> createState() => _FaultsViewState();
}

enum _FaultViewMode { vehicle, driver }

class _FaultsViewState extends State<FaultsView> {
  _FaultViewMode _viewMode = _FaultViewMode.vehicle;

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);
    
    return Column(
      children: [
        // Toggle Selector (Same style as ActivityTimeline)
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
                  "Vehicle", 
                  _viewMode == _FaultViewMode.vehicle, 
                  () => setState(() => _viewMode = _FaultViewMode.vehicle), 
                  primaryGreen
                ),
                _buildToggleItem(
                  "Driver", 
                  _viewMode == _FaultViewMode.driver, 
                  () => setState(() => _viewMode = _FaultViewMode.driver), 
                  primaryGreen
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _viewMode == _FaultViewMode.vehicle
              ? (widget.vehicleFaults.isEmpty
                  ? _buildEmptyState("No technical faults found.")
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: widget.vehicleFaults.length,
                      itemBuilder: (context, index) => _buildFaultCard(widget.vehicleFaults[index]),
                    ))
              : (widget.driverEvents.isEmpty
                  ? _buildEmptyState("No driver events found.")
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: widget.driverEvents.length,
                      itemBuilder: (context, index) => _buildFaultCard(widget.driverEvents[index]),
                    )),
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
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
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

  Widget _buildFaultCard(TahoFault fault) {
    final title = _getFaultTitle(fault.type);
    final isSecurity = fault.type >= 0x10 && fault.type <= 0x2F;
    final isFault = fault.type >= 0x30;
    
    final iconColor = isSecurity ? Colors.red : (isFault ? Colors.orange : Colors.blue);
    final icon = isSecurity ? Icons.security : (isFault ? Icons.error_outline : Icons.info_outline);

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
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text(
                  "0x${fault.type.toRadixString(16).padLeft(2, '0').toUpperCase()}",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _faultDetailRow(Icons.access_time, "Start", fault.beginTime.toLocal().toString().split('.')[0]),
            _faultDetailRow(Icons.timer_off, "End", fault.endTime.toLocal().toString().split('.')[0]),
            _faultDetailRow(Icons.directions_car, "Vehicle", fault.vehicleRegistrationNumber),
          ],
        ),
      ),
    );
  }

  Widget _faultDetailRow(IconData icon, String label, String value) {
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

  String _getFaultTitle(int type) {
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
