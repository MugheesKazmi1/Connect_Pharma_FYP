import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:maps_launcher/maps_launcher.dart';

class SelfPickupScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const SelfPickupScreen({
    super.key, 
    required this.requestData, 
    required this.requestId
  });

  @override
  State<SelfPickupScreen> createState() => _SelfPickupScreenState();
}

class _SelfPickupScreenState extends State<SelfPickupScreen> {
  late mapbox.Point _pharmacyPosition;

  @override
  void initState() {
    super.initState();
    // Use the coordinates shared by the pharmacist
    final lat = widget.requestData['pharmacyLat'] as double? ?? 24.8607;
    final lng = widget.requestData['pharmacyLng'] as double? ?? 67.0011;
    _pharmacyPosition = mapbox.Point(coordinates: mapbox.Position(lng, lat));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Self Pickup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.store, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              'Ready for Pickup',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please visit the pharmacy to collect your medicine.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 30),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.store_mall_directory),
                      title: const Text('Pharmacy Location'),
                      subtitle: Text('ID: ${widget.requestData['acceptedBy'] ?? 'Unknown'}'),
                    ),
                    const Divider(),
                    ElevatedButton.icon(
                      onPressed: () {
                        MapsLauncher.launchCoordinates(
                          _pharmacyPosition.coordinates.lat.toDouble(),
                          _pharmacyPosition.coordinates.lng.toDouble(),
                          'Pharmacy Location',
                        );
                      },
                      icon: const Icon(Icons.navigation),
                      label: const Text('Get Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Map to Pharmacy
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                  ? Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront, color: Colors.grey),
                            Text('Map not available on Web', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  : mapbox.MapWidget(
                      onMapCreated: (mapbox.MapboxMap mapboxMap) async {
                        final annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                        annotationManager.create(mapbox.PointAnnotationOptions(
                          geometry: _pharmacyPosition,
                          textField: 'Pharmacy Location',
                          iconImage: "marker-15",
                          iconSize: 2.0,
                        ));
                        mapboxMap.setCamera(mapbox.CameraOptions(
                          center: _pharmacyPosition,
                          zoom: 15,
                        ));
                      },
                    ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                 Navigator.pop(context);
              },
              child: const Text('I have picked it up'),
            ),
          ],
        ),
      ),
    );
  }
}
