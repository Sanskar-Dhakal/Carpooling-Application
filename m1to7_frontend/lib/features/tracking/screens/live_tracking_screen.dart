import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String bookingId;
  final bool isDriver;

  const LiveTrackingScreen({
    super.key,
    required this.bookingId,
    required this.isDriver,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final MapController _mapController = MapController();
  LatLng? _driverLocation;
  LatLng? _origin;
  LatLng? _destination;
  Timer? _pollTimer;
  bool _loading = true;
  Map<String, dynamic>? _booking;

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _startListening();
    if (widget.isDriver) _startPolling();
  }

  Future<void> _loadBooking() async {
    try {
      final data = await ApiService.get('/bookings/${widget.bookingId}');
      final b = data['booking'] as Map<String, dynamic>? ?? {};
      final ride = b['ride'] as Map<String, dynamic>? ?? {};
      setState(() {
        _booking = b;
        if (ride['origin_lat'] != null && ride['origin_lng'] != null) {
          _origin = LatLng(double.parse(ride['origin_lat'].toString()), double.parse(ride['origin_lng'].toString()));
        }
        if (ride['destination_lat'] != null && ride['destination_lng'] != null) {
          _destination = LatLng(double.parse(ride['destination_lat'].toString()), double.parse(ride['destination_lng'].toString()));
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

void _startListening() {}

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final data = await ApiService.get('/bookings/${widget.bookingId}/location');
        final lat = data['lat'];
        final lng = data['lng'];
        if (lat != null && lng != null && mounted) {
          setState(() => _driverLocation = LatLng(double.parse(lat.toString()), double.parse(lng.toString())));
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  LatLng get _mapCenter {
    if (_driverLocation != null) return _driverLocation!;
    if (_origin != null) return _origin!;
    return const LatLng(27.7172, 85.3240); // Kathmandu default
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Map ────────────────────────────────────────────────────
          _loading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(initialCenter: _mapCenter, initialZoom: 13),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                    MarkerLayer(markers: [
                      if (_origin != null)
                        Marker(
                          point: _origin!,
                          width: 44,
                          height: 44,
                          child: const _MapPin(color: AppTheme.primary, icon: Icons.my_location_rounded),
                        ),
                      if (_destination != null)
                        Marker(
                          point: _destination!,
                          width: 44,
                          height: 44,
                          child: const _MapPin(color: AppTheme.error, icon: Icons.location_on_rounded),
                        ),
                      if (_driverLocation != null)
                        Marker(
                          point: _driverLocation!,
                          width: 52,
                          height: 52,
                          child: const _MapPin(color: AppTheme.accent, icon: Icons.directions_car_filled_rounded, large: true),
                        ),
                    ]),
                  ],
                ),

          // ── Top AppBar ────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 8, 8, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppTheme.primaryDark.withOpacity(0.95), Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text('Live Tracking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _driverLocation != null ? AppTheme.success : AppTheme.warning,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _driverLocation != null ? 'Live' : 'Waiting',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Card ───────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 16),
                  if (_booking != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.my_location_rounded, size: 16, color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_booking!['ride']?['origin_address'] ?? 'Pickup', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_booking!['ride']?['destination_address'] ?? 'Dropoff', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_driverLocation == null)
                    const Center(
                      child: Text('Waiting for driver location…', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.directions_car_filled_rounded, color: AppTheme.accent, size: 18),
                        const SizedBox(width: 6),
                        const Text('Driver is on the way!', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool large;
  const _MapPin({required this.color, required this.icon, this.large = false});

  @override
  Widget build(BuildContext context) {
    final size = large ? 52.0 : 44.0;
    final iconSize = large ? 26.0 : 20.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}
