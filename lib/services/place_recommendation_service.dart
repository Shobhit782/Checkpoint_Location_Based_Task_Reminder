import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class PlaceRecommendationService {
  static final PlaceRecommendationService _instance =
      PlaceRecommendationService._internal();
  factory PlaceRecommendationService() => _instance;
  PlaceRecommendationService._internal();

  static const Map<String, List<String>> categoryTags = {
    'Shopping': [
      'shop=supermarket',
      'shop=mall',
      'shop=convenience',
      'shop=department_store',
    ],
    'Finance': ['amenity=bank', 'amenity=atm'],
    'Education': [
      'amenity=library',
      'amenity=school',
      'amenity=university',
      'shop=books',
    ],
    'Fitness/Health': [
      'leisure=fitness_centre',
      'amenity=gym',
      'amenity=pharmacy',
      'amenity=hospital',
    ],
    'Social': ['amenity=cafe', 'amenity=restaurant', 'amenity=bar'],
    'Home Maintenance': [
      'shop=hardware',
      'shop=doityourself',
      'shop=furniture',
    ],
  };

  Future<List<Map<String, dynamic>>> getNearbyPlaces(
    String category,
    Position currentLocation,
  ) async {
    try {
      final tags = categoryTags[category] ?? [];
      if (tags.isEmpty) return [];

      final radius = 2000; // 2km radius for better results
      final lat = currentLocation.latitude;
      final lon = currentLocation.longitude;

      // Build Overpass query with proper tag filters
      final tagFilters =
          tags.map((tag) {
            final parts = tag.split('=');
            return 'node["${parts[0]}"="${parts[1]}"](around:$radius,$lat,$lon);way["${parts[0]}"="${parts[1]}"](around:$radius,$lat,$lon);';
          }).join();

      final query = '''
        [out:json][timeout:25];
        (
          $tagFilters
        );
        out body;
        >;
        out skel qt;
      ''';

      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = List<Map<String, dynamic>>.from(data['elements']);

        // Filter and sort places by distance
        final places =
            elements
                .where((element) {
                  return element['tags'] != null &&
                      element['tags']['name'] != null &&
                      element['lat'] != null &&
                      element['lon'] != null;
                })
                .map((element) {
                  final distance = Geolocator.distanceBetween(
                    currentLocation.latitude,
                    currentLocation.longitude,
                    element['lat'].toDouble(),
                    element['lon'].toDouble(),
                  );

                  return {
                    'name': element['tags']['name'],
                    'type':
                        element['tags'].entries
                            .firstWhere(
                              (entry) =>
                                  entry.value != null &&
                                  entry.value.toString().isNotEmpty,
                              orElse: () => MapEntry('type', 'Unknown'),
                            )
                            .value,
                    'latitude': element['lat'].toDouble(),
                    'longitude': element['lon'].toDouble(),
                    'distance': distance,
                  };
                })
                .toList();

        // Sort by distance and return closest 5
        places.sort(
          (a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double),
        );
        return places.take(5).toList();
      }
    } catch (e) {
      print('Error getting place recommendations: $e');
    }
    return [];
  }

  String getPlaceRecommendation(List<Map<String, dynamic>> places) {
    if (places.isEmpty) return '';

    final place = places.first;
    final distance = (place['distance'] as double) / 1000; // Convert to km

    return '${place['name']} (${distance.toStringAsFixed(1)}km away)';
  }
}
