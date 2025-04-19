import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/lat_lng.dart' as custom_latlng;
import '../services/location_service.dart';
import '../services/location_search_service.dart';

class LocationPicker extends StatefulWidget {
  const LocationPicker({Key? key}) : super(key: key);

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();
  final LocationSearchService _searchService = LocationSearchService();
  late MapController _mapController;
  Position? _currentPosition;
  String? _currentAddress;
  bool _isLoading = false;
  bool _isSearching = false;
  List<Marker> _markers = [];
  LatLng? _selectedLocation;
  List<Map<String, dynamic>> _searchResults = [];
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    Future.delayed(Duration.zero, () {
      if (!_disposed) {
        _getCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _searchController.dispose();
    _mapController.dispose();
    _searchService.dispose();
    super.dispose();
  }

  void _moveMap(LatLng location, double zoom) {
    if (!_disposed) {
      try {
        _mapController.move(location, zoom);
      } catch (e) {
        print('Error moving map: $e');
      }
    }
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _searchService.debounceSearch(query, (results) {
      if (!_disposed) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _onSuggestionSelected(Map<String, dynamic> location) async {
    setState(() {
      _isLoading = true;
      _isSearching = false;
    });

    try {
      final latLng = LatLng(location['latitude'], location['longitude']);
      setState(() {
        _selectedLocation = latLng;
        _currentAddress = location['name'];
        _searchController.text = _currentAddress ?? '';
        _markers = [
          Marker(
            width: 40.0,
            height: 40.0,
            point: latLng,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
          ),
        ];
      });
      _moveMap(latLng, 15);
    } catch (e) {
      print('Error selecting location: $e');
      if (!_disposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (!_disposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_disposed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!_disposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them in your device settings.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!_disposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied.'),
                duration: Duration(seconds: 3),
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!_disposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied.'),
              duration: Duration(seconds: 3),
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );

      if (_disposed) return;

      final location = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
        _selectedLocation = location;
        _markers = [
          Marker(
            width: 40.0,
            height: 40.0,
            point: location,
            child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
          ),
        ];
      });

      _moveMap(location, 16);
      await _updateAddress(location);
    } catch (e) {
      print('Error getting location: $e');
      if (!_disposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting current location: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (!_disposed) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateSelectedLocation(LatLng position) {
    if (_disposed) return;

    setState(() {
      _selectedLocation = position;
      _markers = [
        Marker(
          width: 40.0,
          height: 40.0,
          point: position,
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
      ];
    });
    _moveMap(position, 15);
    _updateAddress(position);
  }

  Future<void> _updateAddress(LatLng position) async {
    if (_disposed) return;

    try {
      final address = await _locationService.getAddressFromLatLng(position);
      if (!_disposed) {
        setState(() {
          _currentAddress = address;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      if (!_disposed) {
        setState(() {
          _currentAddress =
              'Lat: ${position.latitude}, Long: ${position.longitude}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pick Location')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _selectedLocation ?? const LatLng(0, 0),
                      initialZoom: 15,
                      onTap:
                          (tapPosition, point) =>
                              _updateSelectedLocation(point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(markers: _markers),
                    ],
                  ),
                  // Search Bar with Autocomplete
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search location...',
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon:
                                      _searchController.text.isNotEmpty
                                          ? IconButton(
                                            icon:
                                                _isSearching
                                                    ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                    : const Icon(Icons.clear),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _searchResults = [];
                                              });
                                            },
                                          )
                                          : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: _onSearchChanged,
                              ),
                              if (_searchResults.isNotEmpty)
                                Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(8),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final result = _searchResults[index];
                                      return ListTile(
                                        leading: const Icon(Icons.location_on),
                                        title: Text(result['name']),
                                        onTap:
                                            () => _onSuggestionSelected(result),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Current Location Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: FloatingActionButton(
                      onPressed: _getCurrentLocation,
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                  // Address Display and Select Button
                  if (_currentAddress != null)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 80, // Make space for the location button
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentAddress!,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        _selectedLocation != null
                                            ? () {
                                              Navigator.pop(context, {
                                                'location':
                                                    custom_latlng.LatLng(
                                                      _selectedLocation!
                                                          .latitude,
                                                      _selectedLocation!
                                                          .longitude,
                                                    ),
                                                'address': _currentAddress,
                                              });
                                            }
                                            : null,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Select This Location',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
