import 'package:latlong2/latlong.dart';

class BookingModel {
  final String id;
  final String rideId;
  final int seatsBooked;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final String paymentStatus;
  final String? paymentScreenshotUrl;
  final DateTime createdAt;
  final Map<String, dynamic> ride;
  final Map<String, dynamic> driver;
  final Map<String, dynamic> passenger;

  const BookingModel({
    required this.id,
    required this.rideId,
    required this.seatsBooked,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    required this.paymentStatus,
    this.paymentScreenshotUrl,
    required this.createdAt,
    required this.ride,
    required this.driver,
    required this.passenger,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] ?? '',
        rideId: json['rideId'] ?? '',
        seatsBooked: json['seatsBooked'] ?? 0,
        totalAmount: (json['totalAmount'] ?? 0).toDouble(),
        paymentMethod: json['paymentMethod'] ?? 'cash',
        status: json['status'] ?? 'pending',
        paymentStatus: json['paymentStatus'] ?? 'pending',
        paymentScreenshotUrl: json['paymentScreenshotUrl'],
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        ride: Map<String, dynamic>.from(json['ride'] ?? {}),
        driver: Map<String, dynamic>.from(json['driver'] ?? {}),
        passenger: Map<String, dynamic>.from(json['passenger'] ?? {}),
      );

  String get routeLabel => '${ride['originAddress'] ?? 'Origin'} -> ${ride['destinationAddress'] ?? 'Destination'}';
  String get amountLabel => 'Rs ${totalAmount.toStringAsFixed(0)}';

  List<LatLng> get routePoints {
    final raw = ride['route'] as List? ?? [];
    return raw
        .map((p) => LatLng((p['lat'] ?? 0).toDouble(), (p['lng'] ?? 0).toDouble()))
        .toList();
  }

  LatLng? get origin {
    final raw = ride['origin'];
    if (raw is! Map) return null;
    return LatLng((raw['lat'] ?? 0).toDouble(), (raw['lng'] ?? 0).toDouble());
  }

  LatLng? get destination {
    final raw = ride['destination'];
    if (raw is! Map) return null;
    return LatLng((raw['lat'] ?? 0).toDouble(), (raw['lng'] ?? 0).toDouble());
  }
}
