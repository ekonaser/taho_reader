import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'taho_models.dart';

class OpenStreetMapScreen extends StatefulWidget {
  final List<GnssRecord> records;
  const OpenStreetMapScreen({super.key, required this.records});

  @override
  State<OpenStreetMapScreen> createState() => _OpenStreetMapScreenState();
}

class _OpenStreetMapScreenState extends State<OpenStreetMapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF28B52F);
    
    // Center na sredino Evrope in nizek zoom, da se vidi celotna celina
    const LatLng center = LatLng(50.0, 10.0);
    const double zoom = 3.5;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.taho_reader',
              ),
              MarkerLayer(
                markers: widget.records.map((r) => Marker(
                  point: LatLng(r.latitude, r.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Time: ${r.timestamp.toLocal()}\nLat: ${r.formattedLat}\nLon: ${r.formattedLon}")),
                      );
                    },
                    child: const Icon(
                      Icons.location_pin,
                      color: Color(0xFF00C853),
                      size: 40,
                    ),
                  ),
                )).toList(),
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
