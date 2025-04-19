import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../main.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationTimer;
  final List<Map<String, dynamic>> _activeGeofences = [];
  static const double _geofenceRadius = 2.0; // 2km in kilometers

  void startLocationMonitoring() {
    // Stop any existing timer
    _locationTimer?.cancel();

    // Start monitoring location every 30 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _checkNearbyReminders();
    });
  }

  void stopLocationMonitoring() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  void addGeofence(
    int reminderId,
    String title,
    LatLng location,
    String address,
  ) {
    _activeGeofences.add({
      'id': reminderId,
      'title': title,
      'location': location,
      'address': address,
      'notified': false, // To prevent multiple notifications
    });
  }

  void removeGeofence(int reminderId) {
    _activeGeofences.removeWhere((geofence) => geofence['id'] == reminderId);
  }

  Future<void> _checkNearbyReminders() async {
    try {
      final position = await getCurrentLocation();
      final currentLocation = LatLng(position.latitude, position.longitude);

      for (var geofence in _activeGeofences) {
        if (geofence['notified'] == true) continue;

        final targetLocation = geofence['location'] as LatLng;
        final isNearby = isWithinRadius(
          currentLocation,
          targetLocation,
          _geofenceRadius,
        );

        if (isNearby) {
          // Mark as notified to prevent multiple notifications
          geofence['notified'] = true;

          // Send notification
          await NotificationService().showLocationNotification(
            geofence['id'],
            'You\'re near a reminder location!',
            'Task: ${geofence['title']}\nLocation: ${geofence['address']}',
          );
        }
      }
    } catch (e) {
      print('Error checking nearby reminders: $e');
    }
  }

  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.requestPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<String> getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}';
      }
      return 'Address not found';
    } catch (e) {
      print('Error getting address: $e');
      return 'Error getting address';
    }
  }

  Future<LatLng?> getLatLngFromAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
      return null;
    } catch (e) {
      print('Error getting location from address: $e');
      return null;
    }
  }

  double calculateDistance(LatLng point1, LatLng point2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, point1, point2);
  }

  bool isWithinRadius(
    LatLng currentLocation,
    LatLng targetLocation,
    double radiusInKm,
  ) {
    double distance = calculateDistance(currentLocation, targetLocation);
    return distance <= radiusInKm;
  }
}
