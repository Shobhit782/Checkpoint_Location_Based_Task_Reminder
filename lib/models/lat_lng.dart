class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng(latitude: $latitude, longitude: $longitude)';

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory LatLng.fromJson(Map<String, dynamic> json) {
    return LatLng(json['latitude'] as double, json['longitude'] as double);
  }
}
