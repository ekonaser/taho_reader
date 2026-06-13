import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'taho_models.dart';

class OpenStreetMapScreen extends StatefulWidget {
  final List<GnssRecord> records;
  final LatLng? initialCenter;
  final double? initialZoom;
  final bool isPicker;

  const OpenStreetMapScreen({
    super.key,
    required this.records,
    this.initialCenter,
    this.initialZoom,
    this.isPicker = false,
  });

  @override
  State<OpenStreetMapScreen> createState() => _OpenStreetMapScreenState();
}

class _OpenStreetMapScreenState extends State<OpenStreetMapScreen> {
  late final MapController _mapController;
  LatLng? _selectedPoint;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);
    
    // Center na sredino Evrope in nizek zoom, če ni podano drugače
    final LatLng center = widget.initialCenter ?? const LatLng(50.0, 10.0);
    final double zoom = widget.initialZoom ?? (widget.initialCenter != null ? 13.0 : 3.5);

    return Scaffold(
      appBar: widget.isPicker ? AppBar(
        title: const Text("Select Location"),
        actions: [
          if (_selectedPoint != null)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () => Navigator.pop(context, _selectedPoint),
            ),
        ],
      ) : null,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              onTap: widget.isPicker ? (tapPosition, point) {
                setState(() {
                  _selectedPoint = point;
                });
              } : null,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.taho_reader',
              ),
              MarkerLayer(
                markers: [
                  ...widget.records.map((r) => Marker(
                    point: LatLng(r.latitude, r.longitude),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () {
                        if (widget.isPicker) {
                          setState(() {
                            _selectedPoint = LatLng(r.latitude, r.longitude);
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Time: ${r.timestamp.toLocal()}\nLat: ${r.formattedLat}\nLon: ${r.formattedLon}")),
                          );
                        }
                      },
                      child: const Icon(
                        Icons.location_pin,
                        color: Color(0xFF00C853),
                        size: 40,
                      ),
                    ),
                  )),
                  if (_selectedPoint != null)
                    Marker(
                      point: _selectedPoint!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Kontrole za zemljevid (Sever in Zoom) spodaj desno
          Positioned(
            right: 20,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: "north",
                  onPressed: () {
                    _mapController.rotate(0);
                  },
                  backgroundColor: Colors.white.withOpacity(0.8),
                  child: const Icon(Icons.explore, color: primaryGreen),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "zoom_in",
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                  },
                  backgroundColor: Colors.white.withOpacity(0.8),
                  child: const Icon(Icons.add, color: primaryGreen),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "zoom_out",
                  onPressed: () {
                    _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                  },
                  backgroundColor: Colors.white.withOpacity(0.8),
                  child: const Icon(Icons.remove, color: primaryGreen),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
