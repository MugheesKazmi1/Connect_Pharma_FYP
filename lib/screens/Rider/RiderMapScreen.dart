import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:maps_launcher/maps_launcher.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:ui' as ui;

class RiderMapScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const RiderMapScreen({super.key, required this.requestData});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  late mapbox.Point _pharmacyPosition;
  late mapbox.Point _deliveryPosition;
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _annotationManager;

  @override
  void initState() {
    super.initState();
    
    // Exact locations from request data
    final pharmaLat = widget.requestData['pharmacyLat'] as double? ?? 24.8607;
    final pharmaLng = widget.requestData['pharmacyLng'] as double? ?? 67.0011;
    _pharmacyPosition = mapbox.Point(coordinates: mapbox.Position(pharmaLng, pharmaLat));

    final userLat = widget.requestData['userLat'] as double? ?? 24.8707;
    final userLng = widget.requestData['userLng'] as double? ?? 67.0111;
    _deliveryPosition = mapbox.Point(coordinates: mapbox.Position(userLng, userLat));

    _getCurrentLocation();
  }

  void _addMarkers() async {
    if (_annotationManager == null) return;
    
    final markers = [
      mapbox.PointAnnotationOptions(
        geometry: _pharmacyPosition,
        textField: 'Pharmacy (Pickup)',
        textColor: Colors.green.value,
        iconImage: "marker-15",
        iconSize: 2.0,
      ),
      mapbox.PointAnnotationOptions(
        geometry: _deliveryPosition,
        textField: 'Delivery Address',
        textColor: Colors.red.value,
        iconImage: "marker-15",
        iconSize: 2.0,
      ),
    ];
    
    _annotationManager?.createMulti(markers);
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      
      if (permission == geo.LocationPermission.whileInUse || permission == geo.LocationPermission.always) {
        // Try last known first
        geo.Position? lastPosition = await geo.Geolocator.getLastKnownPosition();
        if (lastPosition != null && mounted) {
           _mapboxMap?.setCamera(mapbox.CameraOptions(
            center: mapbox.Point(coordinates: mapbox.Position(lastPosition.longitude, lastPosition.latitude)),
            zoom: 14,
          ));
        }

        // Fetch fresh position with timeout
        final position = await geo.Geolocator.getCurrentPosition(
          locationSettings: geo.LocationSettings(
            accuracy: geo.LocationAccuracy.best,
            timeLimit: const Duration(seconds: 10),
          ),
        );
         _mapboxMap?.setCamera(mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(position.longitude, position.latitude)),
          zoom: 14,
        ));
      }
    } catch (e) {
      debugPrint('Error getting rider location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
      ),
      body: Stack(
        children: [
          if (kIsWeb)
            Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Route Map not available on Web', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Please use an Android/iOS device to see the map.'),
                  ],
                ),
              ),
            )
          else
            mapbox.MapWidget(
              onMapCreated: (mapbox.MapboxMap mapboxMap) async {
                _mapboxMap = mapboxMap;
                _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                _addMarkers();
                
                mapboxMap.setCamera(mapbox.CameraOptions(
                  center: _pharmacyPosition,
                  zoom: 13,
                ));
              },
            ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    MapsLauncher.launchCoordinates(
                      _pharmacyPosition.coordinates.lat.toDouble(),
                      _pharmacyPosition.coordinates.lng.toDouble(),
                      'Pharmacy (Pickup)',
                    );
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('Navigate to Pharmacy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const ui.Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    MapsLauncher.launchCoordinates(
                      _deliveryPosition.coordinates.lat.toDouble(),
                      _deliveryPosition.coordinates.lng.toDouble(),
                      'User (Delivery)',
                    );
                  },
                  icon: const Icon(Icons.person_pin_circle),
                  label: const Text('Navigate to User'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const ui.Size(double.infinity, 50),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
