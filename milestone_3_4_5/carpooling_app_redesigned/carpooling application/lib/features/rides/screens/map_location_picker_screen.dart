import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';

class _NominatimService {
  static const _baseUrl =
      'https://nominatim.openstreetmap.org/reverse?format=json';

  static Future<String?> reverseGeocode(LatLng point) async {
    final url =
        '$_baseUrl&lat=${point.latitude.toString()}&lon=${point.longitude.toString()}';
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'com.example.carpooling_app',
        'Accept': 'application/json',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final name = address['name'] as String?;
          final road = address['road'] as String?;
          final suburb = address['suburb'] as String?;
          final city = address['city'] as String?;
          final town = address['town'] as String?;
          final village = address['village'] as String?;
          final parts = <String>[];
          if (name != null && road != null) parts.add('$name, $road');
          else if (road != null) parts.add(road);
          if (suburb != null) parts.add(suburb);
          if ((city ?? town ?? village) != null) {
            parts.add(city ?? town ?? village!);
          }
          if (parts.isNotEmpty) return parts.join(', ');
        }
      }
    } catch (_) {}
    return null;
  }
}

class PickedMapLocation {
  final String label;
  final LatLng point;

  const PickedMapLocation({required this.label, required this.point});
}

class MapLocationPickerScreen extends StatefulWidget {
  final String title;
  final PickedMapLocation? initialLocation;

  const MapLocationPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  final _mapController = MapController();
  LatLng _center = const LatLng(27.7172, 85.3240);
  LatLng? _selected;
  String? _selectedLabel;
  bool _locating = false;
  bool _resolving = false;

  Future<String> _resolveLabel(LatLng point) async {
    try {
      final label = await _NominatimService.reverseGeocode(point);
      if (label != null && mounted) {
        setState(() => _selectedLabel = label);
        return label;
      }
    } catch (_) {}
    final fallback =
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
    if (mounted) setState(() => _selectedLabel = fallback);
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation?.point;
    _center = widget.initialLocation?.point ?? _center;
    _selectedLabel = widget.initialLocation?.label;
    if (widget.initialLocation == null) {
      _useCurrentLocation(moveMap: false);
    }
  }

  Future<void> _useCurrentLocation({bool moveMap = true}) async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _show('Location permission is required to use the live map.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = point;
        _selected = point;
      });
      if (moveMap) _mapController.move(point, 15);
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null) {
      _show('Tap the map or use current location first.');
      return;
    }
    setState(() => _resolving = true);
    try {
      final label = await _resolveLabel(selected);
      if (!mounted) return;
      Navigator.pop(
        context,
        PickedMapLocation(label: label, point: selected),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Use current location',
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 14,
                onTap: (_, point) async {
                  setState(() {
                    _selected = point;
                    _selectedLabel = null;
                    _resolving = true;
                  });
                  await _resolveLabel(point);
                  if (mounted) setState(() => _resolving = false);
                },
              ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.carpooling_app',
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.location_on,
                          color: AppTheme.error, size: 42),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10)
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selected == null
                          ? 'Tap the map to select a location'
                          : _resolving
                              ? 'Resolving location...'
                              : _selectedLabel ??
                                  '${_selected!.latitude.toStringAsFixed(6)}, ${_selected!.longitude.toStringAsFixed(6)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _resolving
                          ? const SizedBox(
                              height: 36,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _confirm,
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Use This Location'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
