import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'taho_models.dart';
import 'event_model.dart';
import 'openstreetmap.dart';

class LogsView extends StatefulWidget {
  final List<DailyVehicles> vehicles;
  final List<PlaceRecord> places;
  final List<DailyVehiclesG2> vehiclesG2;
  final List<PlaceRecordG2> placesG2;
  final List<GnssRecord> gnssRecords;
  final Function(double lat, double lon)? onJumpToMap;

  const LogsView({
    super.key,
    required this.vehicles,
    required this.places,
    required this.vehiclesG2,
    required this.placesG2,
    required this.gnssRecords,
    this.onJumpToMap,
  });

  @override
  State<LogsView> createState() => _LogsViewState();
}

enum _LogViewMode { vehicles, places, events }

class _LogsViewState extends State<LogsView> {
  _LogViewMode _viewMode = _LogViewMode.vehicles;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isSmallScreen = screenWidth < 360;

    return Column(
      children: [
        // Toggle Selector
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: SegmentedButton<_LogViewMode>(
            segments: [
              ButtonSegment(
                value: _LogViewMode.vehicles,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Vehicles',
                    style: TextStyle(fontSize: isSmallScreen ? 10 : 14),
                  ),
                ),
                icon: const Icon(Icons.directions_car),
              ),
              ButtonSegment(
                value: _LogViewMode.places,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Places',
                    style: TextStyle(fontSize: isSmallScreen ? 10 : 14),
                  ),
                ),
                icon: const Icon(Icons.location_on),
              ),
              ButtonSegment(
                value: _LogViewMode.events,
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Events',
                    style: TextStyle(fontSize: isSmallScreen ? 10 : 14),
                  ),
                ),
                icon: const Icon(Icons.event_note),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (Set<_LogViewMode> newSelection) {
              setState(() {
                _viewMode = newSelection.first;
              });
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: theme.primaryColor,
              selectedForegroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 4 : 12,
                vertical: 8,
              ),
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
    if (_viewMode == _LogViewMode.vehicles) {
      return (widget.vehiclesG2.isNotEmpty
          ? ListView.builder(
              itemCount: widget.vehiclesG2.length,
              itemBuilder: (context, index) => _buildDayCardG2(widget.vehiclesG2[index]),
            )
          : widget.vehicles.isEmpty
              ? _buildEmptyState("No vehicle data found.")
              : ListView.builder(
                  itemCount: widget.vehicles.length,
                  itemBuilder: (context, index) => _buildDayCard(widget.vehicles[index]),
                ));
    } else if (_viewMode == _LogViewMode.places) {
      return (widget.placesG2.isNotEmpty
          ? _buildPlacesListG2()
          : widget.places.isEmpty
              ? _buildEmptyState("No place records found.")
              : _buildPlacesList());
    } else {
      return _buildEventsList();
    }
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildDayCard(DailyVehicles day) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  day.date.toLocal().toString().split(' ').first,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const Divider(height: 24),
            ...day.vehicles.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(v.registration, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                      Text("${v.endKm - v.startKm} km", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _detailRow(Icons.access_time, "Duration", "${v.startTime.toLocal().toString().split(' ')[1].substring(0, 5)} - ${v.endTime.toLocal().toString().split(' ')[1].substring(0, 5)}"),
                  _detailRow(Icons.speed, "Odometer", "${v.startKm} - ${v.endKm} km"),
                  if (day.vehicles.last != v) const Divider(height: 20, thickness: 0.5),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCardG2(DailyVehiclesG2 day) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    day.date.toLocal().toString().split(' ').first,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text("GEN 2", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 24),
            ...day.vehicles.map((v) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(v.registrationNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                            child: Text(_getCountryCode(v.registrationNation), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      Text("${v.odometerEnd - v.odometerBegin} km", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _detailRow(Icons.access_time, "Duration", "${v.firstUse.toLocal().toString().split(' ')[1].substring(0, 5)} - ${v.lastUse.toLocal().toString().split(' ')[1].substring(0, 5)}"),
                  _detailRow(Icons.speed, "Odometer", "${v.odometerBegin} - ${v.odometerEnd} km"),
                  _detailRow(Icons.fingerprint, "VIN", v.vin),
                  if (day.vehicles.last != v) const Divider(height: 20, thickness: 0.5),
                ],
              ),
            )),
          ],
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

  Widget _buildPlacesListG2() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: widget.placesG2.length,
      itemBuilder: (context, index) => _buildPlaceCardG2(widget.placesG2[index]),
    );
  }

  Widget _buildPlaceCard(PlaceRecord place) {
    final theme = Theme.of(context);
    final typeInfo = _getEntryTypeInfo(place.entryTypeDailyWorkPeriod);
    final isBegin = place.entryTypeDailyWorkPeriod % 2 == 0;
    final iconColor = isBegin ? Colors.green : Colors.orange;
    final icon = isBegin ? Icons.login : Icons.logout;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: theme.colorScheme.surface,
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
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(height: 24, color: theme.dividerColor.withValues(alpha: 0.1)),
            _detailRow(Icons.access_time, "Time", place.entryTime.toLocal().toString().split('.')[0]),
            _detailRow(Icons.speed, "Odometer", "${place.vehicleOdometerValue} km"),
            _detailRow(Icons.public, "Country", _getCountryCode(place.dailyWorkPeriodCountry)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceCardG2(PlaceRecordG2 place) {
    final theme = Theme.of(context);
    final typeInfo = _getEntryTypeInfo(place.entryTypeDailyWorkPeriod);
    final isBegin = place.entryTypeDailyWorkPeriod % 2 == 0;
    final iconColor = isBegin ? Colors.green : Colors.orange;
    final icon = isBegin ? Icons.login : Icons.logout;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: theme.colorScheme.surface,
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
                      Row(
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
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: const Text("G2", style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
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
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Divider(height: 24, color: theme.dividerColor.withValues(alpha: 0.1)),
            _detailRow(Icons.access_time, "Time", place.entryTime.toLocal().toString().split('.')[0]),
            _detailRow(Icons.speed, "Odometer", "${place.vehicleOdometerValue} km"),
            _detailRow(Icons.public, "Country", _getCountryCode(place.dailyWorkPeriodCountry)),
            if (place.lat != 0x7FFFFF && place.lon != 0x7FFFFF) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "GNSS: ${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}",
                          style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          "Accuracy: ${place.gnssAccuracy}m",
                          style: TextStyle(fontSize: 11, color: _getAccuracyColor(place.gnssAccuracy)),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      if (widget.onJumpToMap != null) {
                        widget.onJumpToMap!(place.latitude, place.longitude);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("GNSS location tapped. Use the GNSS tab to see all points.")),
                        );
                      }
                    },
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text("MAP"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getAccuracyColor(int accuracy) {
    if (accuracy <= 10) return Colors.green;
    if (accuracy <= 30) return Colors.orange;
    return Colors.red;
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text("$label: ", style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
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
      case 253: name = "EC"; break;
      case 254: name = "EUR"; break;
      case 255: name = "WLD"; break; // apparently UNK has same value as WLD
      default:
        return "Unknown ($code)";
    }
    return name;
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

  Widget _buildEventsList() {
    final box = Hive.box<DriverEvent>('driver_events');
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkResponse(
                onTap: () => _showEventDialog(),
                radius: 25,
                highlightColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                splashColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                child: Text(
                  "+",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w200,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _exportAllEventsToCalendar,
                icon: const Icon(Icons.ios_share),
                tooltip: "Export all to ICS",
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<DriverEvent> box, _) {
              if (box.values.isEmpty) {
                return _buildEmptyState("No events recorded yet.");
              }

              final events = box.values.toList().cast<DriverEvent>();
              // Sort by date descending
              events.sort((a, b) => b.date.compareTo(a.date));

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: events.length,
                itemBuilder: (context, index) => _buildEventCard(events[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(DriverEvent event) {
    final theme = Theme.of(context);
    final color = _getEventColor(event.type);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_note, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.type.isNotEmpty ? event.type : "UNNAMED EVENT",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        "${event.date.toLocal().toString().split('.')[0]}${event.endDate != null ? ' - ${event.endDate!.toLocal().toString().split(' ')[1].substring(0, 5)}' : ''}",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _showEventDialog(event: event),
                  icon: const Icon(Icons.edit_outlined, color: Colors.orange, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _exportToCalendar(event),
                  icon: const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => event.delete(),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (event.description.isNotEmpty || (event.location != null && event.location!.isNotEmpty) || (event.latitude != null))
              Divider(height: 24, color: theme.dividerColor.withValues(alpha: 0.1)),
            
            if (event.description.isNotEmpty) ...[
              const Text("DESCRIPTION", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(event.description, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
            ],

            if (event.location != null && event.location!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(event.location!, style: const TextStyle(fontSize: 13))),
                ],
              ),
              const SizedBox(height: 8),
            ],

            if (event.latitude != null && event.longitude != null) ...[
              Row(
                children: [
                  const Icon(Icons.map, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    "Lat: ${event.latitude!.toStringAsFixed(5)}, Lon: ${event.longitude!.toStringAsFixed(5)}",
                    style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => widget.onJumpToMap?.call(event.latitude!, event.longitude!),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text("SHOW ON MAP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],

            if (event.tags != null && event.tags!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: event.tags!.map((tag) => Text(
                  "#$tag",
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getEventColor(String type) {
    switch (type.toLowerCase()) {
      case 'operational events': return Colors.blue;
      case 'driver observations': return Colors.teal;
      case 'compliance events': return Colors.red;
      case 'personal events': return Colors.green;
      case 'security events': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String _buildIcsEventBlock(DriverEvent event, String nowTime) {
    final startTime = "${event.date.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z";
    final endDateTime = event.endDate ?? event.date.add(const Duration(hours: 1));
    final endTime = "${endDateTime.toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z";

    final summary = event.type.replaceAll('\n', ' ');
    final description = event.description.replaceAll('\n', '\\n');
    final location = (event.location ?? "").replaceAll('\n', ' ');

    return [
      'BEGIN:VEVENT',
      'DTSTAMP:$nowTime',
      'DTSTART:$startTime',
      'DTEND:$endTime',
      'SUMMARY:$summary',
      'DESCRIPTION:$description',
      'LOCATION:$location',
      'UID:${event.date.millisecondsSinceEpoch}@tahoreader.app',
      'END:VEVENT',
    ].join('\r\n');
  }

  Future<void> _exportToCalendar(DriverEvent event) async {
    final nowTime = "${DateTime.now().toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z";
    
    // Create ICS content
    final icsContent = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//TahoReader//DriverEvent//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      _buildIcsEventBlock(event, nowTime),
      'END:VCALENDAR',
    ].join('\r\n');

    await _saveAndOpenIcs(icsContent, "event.ics");
  }

  Future<void> _exportAllEventsToCalendar() async {
    try {
      final box = Hive.box<DriverEvent>('driver_events');
      if (box.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No events to export.")),
          );
        }
        return;
      }

      final nowTime = "${DateTime.now().toUtc().toIso8601String().replaceAll('-', '').replaceAll(':', '').split('.').first}Z";
      final events = box.values.toList().cast<DriverEvent>();

      final List<String> icsLines = [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'PRODID:-//TahoReader//DriverEventsAll//EN',
        'CALSCALE:GREGORIAN',
        'METHOD:PUBLISH',
      ];

      for (var event in events) {
        icsLines.add(_buildIcsEventBlock(event, nowTime));
      }

      icsLines.add('END:VCALENDAR');
      final icsContent = icsLines.join('\r\n');

      await _saveAndOpenIcs(icsContent, "all_events.ics");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting all events: $e")),
        );
      }
    }
  }

  Future<void> _saveAndOpenIcs(String content, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      final result = await OpenFile.open(file.path, type: 'text/calendar');
      
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open calendar: ${result.message}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error exporting events: $e")),
        );
      }
    }
  }

  void _showEventDialog({DriverEvent? event}) {
    final typeController = TextEditingController(text: event?.type ?? "");
    final descController = TextEditingController(text: event?.description ?? "");
    final locController = TextEditingController(text: event?.location ?? "");
    final tagsController = TextEditingController(text: event?.tags?.join(' ') ?? "");
    DateTime selectedDate = event?.date ?? DateTime.now();
    DateTime? selectedEndDate = event?.endDate;
    double? selectedLat = event?.latitude;
    double? selectedLon = event?.longitude;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(event == null ? "New Event" : "Edit Event"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: "Event Name",
                    counterText: "",
                  ),
                  maxLength: 50,
                ),
                const SizedBox(height: 16),
                // Start Date & Time
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                          // Ensure end date is after start date
                          if (selectedEndDate != null && selectedEndDate!.isBefore(selectedDate)) {
                            selectedEndDate = selectedDate.add(const Duration(hours: 1));
                          }
                        });
                      }
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "Start Date & Time"),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedDate.toLocal().toString().split('.')[0].substring(0, 16)),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // End Date & Time
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedEndDate ?? selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(selectedEndDate ?? selectedDate.add(const Duration(hours: 1))),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedEndDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: "End Date & Time (Optional)"),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(selectedEndDate != null 
                          ? selectedEndDate!.toLocal().toString().split('.')[0].substring(0, 16)
                          : "Not set (default 1h)"),
                        const Icon(Icons.event_available, size: 18, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    final LatLng? picked = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OpenStreetMapScreen(
                          records: widget.gnssRecords,
                          isPicker: true,
                          initialCenter: selectedLat != null 
                              ? LatLng(selectedLat!, selectedLon!)
                              : (widget.gnssRecords.isNotEmpty 
                                  ? LatLng(widget.gnssRecords.last.latitude, widget.gnssRecords.last.longitude)
                                  : null),
                        ),
                      ),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedLat = picked.latitude;
                        selectedLon = picked.longitude;
                      });
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: Text(selectedLat != null ? "Location Selected" : "Pick Location on Map"),
                ),
                if (selectedLat != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("Lat: ${selectedLat!.toStringAsFixed(4)}, Lon: ${selectedLon!.toStringAsFixed(4)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    helperText: "max 250 chars",
                    counterText: "",
                  ),
                  maxLength: 250,
                  maxLines: 3,
                ),
                TextField(
                  controller: locController,
                  decoration: const InputDecoration(labelText: "Location Name (Optional)"),
                ),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(labelText: "Tags (space separated)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                if (event == null) {
                  final newEvent = DriverEvent(
                    date: selectedDate,
                    type: typeController.text,
                    description: descController.text,
                    location: locController.text,
                    tags: tagsController.text.split(' ').where((t) => t.isNotEmpty).toList(),
                    latitude: selectedLat,
                    longitude: selectedLon,
                    endDate: selectedEndDate,
                  );
                  Hive.box<DriverEvent>('driver_events').add(newEvent);
                } else {
                  event.date = selectedDate;
                  event.type = typeController.text;
                  event.description = descController.text;
                  event.location = locController.text;
                  event.tags = tagsController.text.split(' ').where((t) => t.isNotEmpty).toList();
                  event.latitude = selectedLat;
                  event.longitude = selectedLon;
                  event.endDate = selectedEndDate;
                  event.save();
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              child: const Text("SAVE"),
            ),
          ],
        ),
      ),
    );
  }
}
