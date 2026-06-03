import 'package:latlong2/latlong.dart';

class PlaceSuggestion {
  final String label;
  final double lat;
  final double lng;

  const PlaceSuggestion({
    required this.label,
    required this.lat,
    required this.lng,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) => PlaceSuggestion(
        label: json['label'] ?? '',
        lat: (json['lat'] ?? 0).toDouble(),
        lng: (json['lng'] ?? 0).toDouble(),
      );

  LatLng get point => LatLng(lat, lng);
}

class RideModel {
  final String id;
  final String originAddress;
  final LatLng origin;
  final String destinationAddress;
  final LatLng destination;
  final List<LatLng> route;
  final int distanceMeters;
  final int durationSeconds;
  final DateTime departureTime;
  final int seatsTotal;
  final int seatsAvailable;
  final double pricePerSeat;
  final String status;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic>? driver;
  final Map<String, dynamic>? match;

  const RideModel({
    required this.id,
    required this.originAddress,
    required this.origin,
    required this.destinationAddress,
    required this.destination,
    required this.route,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.departureTime,
    required this.seatsTotal,
    required this.seatsAvailable,
    required this.pricePerSeat,
    required this.status,
    required this.preferences,
    this.driver,
    this.match,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    final route = (json['route'] as List? ?? [])
        .map((p) => LatLng((p['lat'] ?? 0).toDouble(), (p['lng'] ?? 0).toDouble()))
        .toList();
    final origin = LatLng(
      (json['origin']?['lat'] ?? 0).toDouble(),
      (json['origin']?['lng'] ?? 0).toDouble(),
    );
    final destination = LatLng(
      (json['destination']?['lat'] ?? 0).toDouble(),
      (json['destination']?['lng'] ?? 0).toDouble(),
    );
    return RideModel(
      id: json['id'] ?? '',
      originAddress: json['originAddress'] ?? '',
      origin: origin,
      destinationAddress: json['destinationAddress'] ?? '',
      destination: destination,
      route: route.isEmpty ? [origin, destination] : route,
      distanceMeters: json['distanceMeters'] ?? 0,
      durationSeconds: json['durationSeconds'] ?? 0,
      departureTime: DateTime.tryParse(json['departureTime'] ?? '') ?? DateTime.now(),
      seatsTotal: json['seatsTotal'] ?? 0,
      seatsAvailable: json['seatsAvailable'] ?? 0,
      pricePerSeat: (json['pricePerSeat'] ?? 0).toDouble(),
      status: json['status'] ?? 'active',
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      driver: json['driver'] == null ? null : Map<String, dynamic>.from(json['driver']),
      match: json['match'] == null ? null : Map<String, dynamic>.from(json['match']),
    );
  }

  String get distanceLabel => '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  String get etaLabel => '${(durationSeconds / 60).round()} min';
}
