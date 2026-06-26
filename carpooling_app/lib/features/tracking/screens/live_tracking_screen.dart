import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class LiveTrackingScreen extends StatefulWidget {
  final String rideId;
  final List<Map<String, dynamic>> routePoints; // [{lat,lng}]
  final String driverName;
  final LatLng passengerOrigin;
  final bool isDriver;

  const LiveTrackingScreen({
    super.key,
    required this.rideId,
    required this.routePoints,
    required this.driverName,
    required this.passengerOrigin,
    this.isDriver = false,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  IO.Socket? _socket;
  LatLng? _driverLocation;
  LatLng? _passengerLocation;
  bool _driverOffline = false;
  bool _passengerOffline = false;
  final MapController _mapController = MapController();
  Timer? _offlineTimer;
  Timer? _passengerOfflineTimer;
  StreamSubscription<Position>? _positionSub;
  bool _driverBroadcasting = false;
  bool _passengerBroadcasting = false;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.tokenKey);
    _socket = IO.io(
      AppConstants.baseUrl.replaceAll('/api/v1', ''),
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setAuth({'token': token})
          .build(),
    );
    _socket!.onConnect((_) {
      _socket!.emit('join_ride_room', widget.rideId);
      setState(() => _driverOffline = false);
      if (widget.isDriver) _startBroadcasting();
      else _startPassengerLocationSharing();
    });
    _socket!.on('passenger_location', (data) {
      _passengerOfflineTimer?.cancel();
      final lat = (data['lat'] is num) ? (data['lat'] as num).toDouble() : double.tryParse(data['lat']?.toString() ?? '27.7172') ?? 27.7172;
      final lng = (data['lng'] is num) ? (data['lng'] as num).toDouble() : double.tryParse(data['lng']?.toString() ?? '85.3240') ?? 85.3240;
      setState(() {
        _passengerLocation = LatLng(lat, lng);
        _passengerOffline = false;
      });
      _passengerOfflineTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _passengerOffline = true);
      });
    });
    _socket!.on('driver_location', (data) {
      _offlineTimer?.cancel();
      final lat = (data['lat'] is num) ? (data['lat'] as num).toDouble() : double.tryParse(data['lat']?.toString() ?? '27.7172') ?? 27.7172;
      final lng = (data['lng'] is num) ? (data['lng'] as num).toDouble() : double.tryParse(data['lng']?.toString() ?? '85.3240') ?? 85.3240;
      setState(() {
        _driverLocation = LatLng(lat, lng);
        _driverOffline = false;
      });
      _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
      _offlineTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _driverOffline = true);
      });
    });
    _socket!.onDisconnect((_) {
      if (mounted) setState(() => _driverOffline = true);
    });
    _socket!.onConnectError((_) {
      if (mounted) setState(() => _driverOffline = true);
    });
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    _passengerOfflineTimer?.cancel();
    _positionSub?.cancel();
    _socket?.disconnect();
    super.dispose();
  }

  Future<void> _startBroadcasting() async {
    if (_driverBroadcasting) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _show('Location permission is required for live tracking.');
        return;
      }

      setState(() => _driverBroadcasting = true);
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _emitDriverLocation(current);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_emitDriverLocation);
    } catch (e) {
      _show(e.toString());
    }
  }

  void _emitDriverLocation(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    _socket?.emit('location_update', {
      'rideId': widget.rideId,
      'lat': point.latitude,
      'lng': point.longitude,
    });
    if (!mounted) return;
    setState(() {
      _driverLocation = point;
      _driverOffline = false;
    });
    _mapController.move(point, _mapController.camera.zoom);
  }

  Future<void> _startPassengerLocationSharing() async {
    if (_passengerBroadcasting) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _show('Location permission is required for live tracking.');
        return;
      }

      setState(() => _passengerBroadcasting = true);
      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _emitPassengerLocation(current);
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_emitPassengerLocation);
    } catch (e) {
      _show(e.toString());
    }
  }

  void _emitPassengerLocation(Position position) {
    final point = LatLng(position.latitude, position.longitude);
    _socket?.emit('passenger_location', {
      'rideId': widget.rideId,
      'lat': point.latitude,
      'lng': point.longitude,
    });
    if (!mounted) return;
    setState(() {
      _passengerLocation = point;
      _passengerOffline = false;
    });
    _mapController.move(point, _mapController.camera.zoom);
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  List<LatLng> get _routeLatLngs => widget.routePoints
      .map((p) => LatLng(
          (p['lat'] is num) ? (p['lat'] as num).toDouble() : double.tryParse(p['lat']?.toString() ?? '0') ?? 0.0,
          (p['lng'] is num) ? (p['lng'] as num).toDouble() : double.tryParse(p['lng']?.toString() ?? '0') ?? 0.0))
      .toList();

  void _centerMap() {
    final center = widget.isDriver
        ? (_driverLocation ?? widget.passengerOrigin)
        : (_passengerLocation ?? widget.passengerOrigin);
    _mapController.move(center, 15);
  }

  @override
  Widget build(BuildContext context) {
    final center = _driverLocation ?? widget.passengerOrigin;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isDriver ? 'Driver Live Map' : 'Live Tracking'),
        backgroundColor:
            widget.isDriver ? AppTheme.driverColor : AppTheme.passengerColor,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: center, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.carpooling_app',
              ),
              if (_routeLatLngs.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routeLatLngs,
                    color: (widget.isDriver
                            ? AppTheme.driverColor
                            : AppTheme.passengerColor)
                        .withOpacity(0.7),
                    strokeWidth: 4,
                  ),
                ]),
              MarkerLayer(markers: [
                Marker(
                  point: widget.passengerOrigin,
                  child: const Icon(
                    Icons.trip_origin,
                    color: AppTheme.success,
                    size: 36,
                  ),
                ),
                if (_passengerLocation != null)
                  Marker(
                    point: _passengerLocation!,
                    child: Transform.translate(
                      offset: const Offset(-15, 0),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.person_pin_circle,
                            color: AppTheme.passengerColor, size: 28),
                      ),
                    ),
                  ),
                if (_driverLocation != null)
                  Marker(
                    point: _driverLocation!,
                    child: Transform.translate(
                      offset: const Offset(15, 0),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.directions_car,
                            color: AppTheme.driverColor, size: 28),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
          // Status banner
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _driverOffline ? AppTheme.error : AppTheme.success,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  Icon(_driverOffline ? Icons.signal_wifi_off : Icons.gps_fixed,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    widget.isDriver
                        ? (_driverBroadcasting
                            ? 'Sharing live location'
                            : 'Starting live location')
                        : (_driverOffline
                            ? 'Driver is offline'
                            : 'Driver is live'),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    widget.driverName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          // Legend
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _legendItem(
                        Icons.person_pin_circle, 
                        AppTheme.passengerColor, 
                        widget.isDriver ? 'Passenger' : 'You'),
                    _legendItem(
                        Icons.directions_car, 
                        AppTheme.driverColor,
                        widget.isDriver ? 'Your car' : 'Driver'),
                  ],
                ),
              ),
            ),
          ),
          // Center Map Button
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'center_map_btn',
              onPressed: _centerMap,
              backgroundColor: Colors.white,
              foregroundColor: widget.isDriver ? AppTheme.driverColor : AppTheme.passengerColor,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
