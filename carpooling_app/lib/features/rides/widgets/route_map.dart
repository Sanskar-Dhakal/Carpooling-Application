import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';

class RouteMap extends StatelessWidget {
  final LatLng? origin;
  final LatLng? destination;
  final List<LatLng> route;
  final double height;
  final VoidCallback? onTap;

  const RouteMap({
    super.key,
    this.origin,
    this.destination,
    this.route = const [],
    this.height = 220,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final points = route.isNotEmpty
        ? route
        : [
            if (origin != null) origin!,
            if (destination != null) destination!,
          ];
    final center = points.isNotEmpty
        ? points[points.length ~/ 2]
        : const LatLng(27.7172, 85.3240);

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: points.length > 1 ? 12 : 13,
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
                    if (origin != null)
                      Marker(
                        point: origin!,
                        width: 42,
                        height: 42,
                        child: const Icon(Icons.trip_origin,
                            color: AppTheme.success, size: 32),
                      ),
                    if (destination != null)
                      Marker(
                        point: destination!,
                        width: 42,
                        height: 42,
                        child: const Icon(Icons.location_on,
                            color: AppTheme.error, size: 36),
                      ),
                  ],
                ),
              ],
            ),
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: onTap),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
