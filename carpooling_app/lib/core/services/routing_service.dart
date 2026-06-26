import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Fetches a real, road-following driving route between two points using
/// the free OSRM public routing API (https://project-osrm.org).
///
/// This replaces drawing a straight line between origin and destination —
/// OSRM snaps both points to the road network and returns the actual
/// path a car would drive, plus distance/duration.
class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  static const String _base = 'https://router.project-osrm.org';

  /// Returns the decoded route geometry as a list of LatLng points,
  /// or an empty list if the route could not be fetched (e.g. offline,
  /// rate-limited, or no road route exists between the points) — callers
  /// should fall back to a straight line in that case.
  Future<RouteResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final coords =
        '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final uri = Uri.parse('$_base/route/v1/driving/$coords').replace(
      queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    try {
      final res = await http
          .get(uri, headers: {'User-Agent': 'VroomSquad/1.0 (carpooling app)'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;

      final geometry = route['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;
      final points = coordinates
          .map((c) => LatLng((c as List<dynamic>)[1] as double,
              c[0] as double))
          .toList();

      return RouteResult(
        points: points,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}