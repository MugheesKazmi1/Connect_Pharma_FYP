import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:connect_pharma/screens/ChatScreen.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:geolocator/geolocator.dart' as geo;

class DeliveryScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;
  final String requestId;

  const DeliveryScreen({
    super.key, 
    required this.requestData, 
    required this.requestId
  });

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late mapbox.Point _deliveryPosition;
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _annotationManager;
  mapbox.PointAnnotation? _userLocationAnnotation;

  @override
  void initState() {
    super.initState();
    // Use the exact coordinates captured during request creation
    final lat = widget.requestData['userLat'] as double? ?? 24.8607;
    final lng = widget.requestData['userLng'] as double? ?? 67.0011;
    _deliveryPosition = mapbox.Point(coordinates: mapbox.Position(lng, lat));
    _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      _updateUserPinpoint(position);
      
      // Also listen for updates
      geo.Geolocator.getPositionStream().listen((pos) {
        if (mounted) _updateUserPinpoint(pos);
      });
    } catch (e) {
      debugPrint('Error tracking location: $e');
    }
  }

  Future<void> _updateUserPinpoint(geo.Position pos) async {
    if (_annotationManager == null) return;
    
    final point = mapbox.Point(coordinates: mapbox.Position(pos.longitude, pos.latitude));
    
    if (_userLocationAnnotation != null) {
      await _annotationManager?.delete(_userLocationAnnotation!);
    }
    
    _userLocationAnnotation = await _annotationManager?.create(mapbox.PointAnnotationOptions(
      geometry: point,
      textField: "You are here",
      textColor: Colors.blue.value,
      iconImage: "marker-15",
      iconSize: 2.0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Details')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.delivery_dining, size: 60, color: Colors.blue),
              const SizedBox(height: 12),
              const Text(
                'Delivery Requested',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'A rider will be assigned to pick up your medicine shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                       ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.blue),
                        title: const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Your current location'),
                        trailing: IconButton(
                          icon: const Icon(Icons.navigation, color: Colors.blue),
                          onPressed: () {
                            MapsLauncher.launchCoordinates(
                              _deliveryPosition.coordinates.lat.toDouble(),
                              _deliveryPosition.coordinates.lng.toDouble(),
                              'Delivery Address',
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.medication, color: Colors.blue),
                        title: Text(widget.requestData['medicineName'] ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Package ready at pharmacy'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Map showing delivery location - Increased height for "economical" view
              Container(
                height: 350,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: kIsWeb
                    ? Container(
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off, color: Colors.grey),
                              Text('Map not available on Web', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    : mapbox.MapWidget(
                        onMapCreated: (mapbox.MapboxMap mapboxMap) async {
                          _mapboxMap = mapboxMap;
                          _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
                          
                          // Destination Pin
                          _annotationManager?.create(mapbox.PointAnnotationOptions(
                            geometry: _deliveryPosition,
                            textField: 'Delivery Address',
                            iconImage: "marker-15",
                            iconSize: 2.5,
                          ));

                          // Initial User Pin if already fetched
                          final pos = await geo.Geolocator.getLastKnownPosition();
                          if (pos != null) _updateUserPinpoint(pos);

                          mapboxMap.setCamera(mapbox.CameraOptions(
                            center: _deliveryPosition,
                            zoom: 14,
                          ));
                        },
                      ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: '${widget.requestId}_rider',
                        title: 'Chat with Rider',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.two_wheeler),
                label: const Text('Chat with Rider'),
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.orange,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chatId: widget.requestId,
                        title: 'Chat with Pharmacist',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('Chat with Pharmacist'),
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.green,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
