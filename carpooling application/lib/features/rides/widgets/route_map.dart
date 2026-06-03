import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';

class RouteMap extends StatelessWidget {
  final List<LatLng> route;
  final LatLng? origin;
  final LatLng? destination;

  const RouteMap({
    super.key,
    required this.route,
    this.origin,
    this.destination,
  });

  @override
  Widget build(BuildContext context) {
    final points = route.isNotEmpty
        ? route
        : [
            if (origin != null) origin!,
            if (destination != null) destination!,
          ];
    final center = points.isNotEmpty ? points[points.length ~/ 2] : const LatLng(27.7172, 85.3240);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: points.length > 1 ? 11 : 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.carpooling_app',
          ),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: AppTheme.primary,
                  strokeWidth: 5,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (origin != null || points.isNotEmpty)
                Marker(
                  point: origin ?? points.first,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.trip_origin, color: AppTheme.success, size: 30),
                ),
              if (destination != null || points.length > 1)
                Marker(
                  point: destination ?? points.last,
                  width: 36,
                  height: 36,
                  child: const Icon(Icons.location_on, color: AppTheme.error, size: 34),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
