import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_spinkit/flutter_spinkit.dart';

void main() {
  runApp(const GeoLandApp());
}

class GeoLandApp extends StatelessWidget {
  const GeoLandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo-Land TS',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF2E7D32),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng _center = const LatLng(17.9689, 79.5941); // Default Warangal
  bool _isLoading = false;

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  Future<void> _findOwner() async {
    setState(() => _isLoading = true);

    try {
      // 1. Get current location with accuracy check
      Position position = await _getCurrentLocation();
      
      // Visual feedback if accuracy is poor (> 5m)
      if (position.accuracy > 5.0) {
        _showError("GPS Accuracy is ${position.accuracy.toStringAsFixed(1)}m. Waiting for a better signal (< 5m)...");
        setState(() => _isLoading = false);
        return;
      }

      // 2. Call Backend API
      final response = await http.post(
        Uri.parse('https://geo-land-ts-git-main-sriharisrihari164-netizens-projects.vercel.app/identify-land'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy': position.accuracy,
          'device_id': 'flutter_client_debug', // Replace with secure ID in production
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _showOwnerSheet(data);
      } else {
        _showError("Land records not found for this location.");
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (e) {
      // Fallback for Web/Desktop testing where GPS times out or throws an error
      return Position(
        longitude: 79.5941,
        latitude: 17.9689,
        timestamp: DateTime.now(),
        accuracy: 1.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }
  }

  void _showOwnerSheet(Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text("Pattadar Details", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(data['owner_name'], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1B5E20))),
            const SizedBox(height: 16),
            _infoRow(Icons.pin_drop, "ULPIN", data['ulpin']),
            _infoRow(Icons.landscape, "Survey No", data['survey_number']),
            _infoRow(Icons.category, "Land Type", data['land_type']),
            _infoRow(Icons.aspect_ratio, "Area", "${data['area_acres']} Acres"),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green[700]),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _center, zoom: 18),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.hybrid,
          ),
          // Live Crosshair
          const Center(
            child: Icon(Icons.add, size: 40, color: Colors.white),
          ),
          if (_isLoading)
            const Center(
              child: SpinKitRipple(color: Colors.white, size: 200),
            ),
          // Find Owner Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _findOwner,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
              child: const Text("FIND OWNER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}
