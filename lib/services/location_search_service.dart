import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:latlong2/latlong.dart';

class LocationSearchService {
  static final LocationSearchService _instance =
      LocationSearchService._internal();
  factory LocationSearchService() => _instance;
  LocationSearchService._internal();

  final String _baseUrl = 'https://nominatim.openstreetmap.org';
  Timer? _debounceTimer;

  Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search?format=json&q=$query&limit=5'),
        headers: {'User-Agent': 'YourAppName/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          return {
            'name': item['display_name'],
            'latitude': double.parse(item['lat']),
            'longitude': double.parse(item['lon']),
          };
        }).toList();
      } else {
        print('Error searching locations: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error in searchLocations: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLocationDetails(LatLng location) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/reverse?format=json&lat=${location.latitude}&lon=${location.longitude}',
        ),
        headers: {'User-Agent': 'YourAppName/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'name': data['display_name'],
          'latitude': location.latitude,
          'longitude': location.longitude,
        };
      } else {
        print('Error getting location details: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error in getLocationDetails: $e');
      return null;
    }
  }

  void debounceSearch(
    String query,
    Function(List<Map<String, dynamic>>) callback,
  ) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final results = await searchLocations(query);
      callback(results);
    });
  }

  void dispose() {
    _debounceTimer?.cancel();
  }
}
