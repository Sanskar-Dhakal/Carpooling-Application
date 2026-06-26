import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../widgets/route_map.dart';
import 'map_location_picker_screen.dart';

class PostRideScreen extends StatefulWidget {
  const PostRideScreen({super.key});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originAddress = TextEditingController();
  final _originLat = TextEditingController();
  final _originLng = TextEditingController();
  final _destinationAddress = TextEditingController();
  final _destinationLat = TextEditingController();
  final _destinationLng = TextEditingController();
  final _seats = TextEditingController(text: '1');
  final _price = TextEditingController();
  DateTime? _departureTime;
  PickedMapLocation? _origin;
  PickedMapLocation? _destination;
  bool _loading = false;
  List<LatLng> _routePoints = [];

  Future<void> _refreshRoute() async {
    if (_origin == null || _destination == null) {
      if (_routePoints.isNotEmpty) setState(() => _routePoints = []);
      return;
    }
    final result = await RoutingService.instance.getRoute(
      origin: _origin!.point,
      destination: _destination!.point,
    );
    if (!mounted) return;
    setState(() => _routePoints = result?.points ?? []);
  }

  @override
  void dispose() {
    _originAddress.dispose();
    _originLat.dispose();
    _originLng.dispose();
    _destinationAddress.dispose();
    _destinationLat.dispose();
    _destinationLng.dispose();
    _seats.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _departureTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _departureTime ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    setState(() {
      _departureTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _geocode({
    required TextEditingController address,
    required TextEditingController lat,
    required TextEditingController lng,
  }) async {
    if (address.text.trim().length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final data = await ApiService.get(
          '/rides/geocode?q=${Uri.encodeQueryComponent(address.text.trim())}');
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) {
        if (!mounted) return;
        showAppSnackBar(context, 'No location found', isError: true);
        return;
      }
      final first = results.first as Map<String, dynamic>;
      address.text = first['label']?.toString() ?? address.text;
      lat.text = first['lat'].toString();
      lng.text = first['lng'].toString();
      final picked = PickedMapLocation(
        label: address.text,
        point: LatLng(
          (first['lat'] is num)
              ? (first['lat'] as num).toDouble()
              : double.tryParse(first['lat']?.toString() ?? '0') ?? 0.0,
          (first['lng'] is num)
              ? (first['lng'] as num).toDouble()
              : double.tryParse(first['lng']?.toString() ?? '0') ?? 0.0,
        ),
      );
      setState(() {
        if (identical(address, _originAddress)) {
          _origin = picked;
        } else {
          _destination = picked;
        }
      });
      _refreshRoute();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_origin == null || _destination == null) {
      showAppSnackBar(context, 'Pickup and dropoff map locations are required',
          isError: true);
      return;
    }
    if (_departureTime == null) {
      showAppSnackBar(context, 'Choose a departure time', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService.post('/rides', {
        'originAddress': _originAddress.text.trim(),
        'originLat': _origin!.point.latitude,
        'originLng': _origin!.point.longitude,
        'destinationAddress': _destinationAddress.text.trim(),
        'destinationLat': _destination!.point.latitude,
        'destinationLng': _destination!.point.longitude,
        'departureTime': _departureTime!.toIso8601String(),
        'seatsTotal': int.parse(_seats.text.trim()),
        'pricePerSeat': double.parse(_price.text.trim()),
      });
      if (!mounted) return;
      showAppSnackBar(context, 'Ride posted successfully');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickOnMap({required bool isOrigin}) async {
    final picked = await Navigator.push<PickedMapLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          title: isOrigin ? 'Select Pickup' : 'Select Dropoff',
          initialLocation: isOrigin ? _origin : _destination,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isOrigin) {
        _origin = picked;
        _originAddress.text = picked.label;
        _originLat.text = picked.point.latitude.toString();
        _originLng.text = picked.point.longitude.toString();
      } else {
        _destination = picked;
        _destinationAddress.text = picked.label;
        _destinationLat.text = picked.point.latitude.toString();
        _destinationLng.text = picked.point.longitude.toString();
      }
    });
    _refreshRoute();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _number(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Enter a number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasDeparture = _departureTime != null;
    final departureLabel = !hasDeparture
        ? 'Choose departure date & time'
        : DateFormat('MMM d, yyyy · h:mm a').format(_departureTime!);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              expandedHeight: 120,
              backgroundColor: AppTheme.driverColor,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.driverColor,
                        AppTheme.driverColor.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd),
                                ),
                                child: const Icon(Icons.add_road_rounded,
                                    color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Post a Ride',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'Share your journey with others',
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Body ────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Map
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    child: RouteMap(
                      origin: _origin?.point,
                      destination: _destination?.point,
                      route: _routePoints,
                      onTap: () => _pickOnMap(isOrigin: _origin == null),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pickup
                  _LocationCard(
                    title: 'Pickup',
                    address: _originAddress,
                    onLocate: () => _geocode(
                        address: _originAddress,
                        lat: _originLat,
                        lng: _originLng),
                    onPickMap: () => _pickOnMap(isOrigin: true),
                    validator: _required,
                    selected: _origin,
                    isPickup: true,
                  ),
                  const SizedBox(height: 10),

                  // Dropoff
                  _LocationCard(
                    title: 'Dropoff',
                    address: _destinationAddress,
                    onLocate: () => _geocode(
                      address: _destinationAddress,
                      lat: _destinationLat,
                      lng: _destinationLng,
                    ),
                    onPickMap: () => _pickOnMap(isOrigin: false),
                    validator: _required,
                    selected: _destination,
                    isPickup: false,
                  ),
                  const SizedBox(height: 14),

                  // Ride details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded,
                                size: 14, color: AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            const Text(
                              'RIDE DETAILS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textTertiary,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: 'Seats Available',
                                controller: _seats,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(
                                    Icons.event_seat_rounded),
                                validator: (value) {
                                  final n =
                                      int.tryParse(value?.trim() ?? '');
                                  if (n == null || n < 1)
                                    return 'Enter seats';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppTextField(
                                label: 'Price / Seat (NPR)',
                                controller: _price,
                                keyboardType: TextInputType.number,
                                prefixIcon:
                                    const Icon(Icons.payments_outlined),
                                validator: _number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Departure Time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          onTap: _loading ? null : _pickDateTime,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: hasDeparture
                                  ? AppTheme.driverColor.withOpacity(0.06)
                                  : AppTheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd),
                              border: Border.all(
                                color: hasDeparture
                                    ? AppTheme.driverColor.withOpacity(0.35)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 18,
                                  color: hasDeparture
                                      ? AppTheme.driverColor
                                      : AppTheme.textSecondary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    departureLabel,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: hasDeparture
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: hasDeparture
                                          ? AppTheme.textPrimary
                                          : AppTheme.textTertiary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: hasDeparture
                                      ? AppTheme.driverColor
                                      : AppTheme.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  AppButton.primary(
                    label: 'Post Ride',
                    icon: Icons.add_road_rounded,
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String title;
  final TextEditingController address;
  final VoidCallback onLocate;
  final VoidCallback onPickMap;
  final String? Function(String?) validator;
  final PickedMapLocation? selected;
  final bool isPickup;

  const _LocationCard({
    required this.title,
    required this.address,
    required this.onLocate,
    required this.onPickMap,
    required this.validator,
    required this.selected,
    required this.isPickup,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isPickup ? AppTheme.driverColor : AppTheme.error;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: selected != null
              ? dotColor.withOpacity(0.3)
              : AppTheme.border,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: dotColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  isPickup
                      ? Icons.trip_origin_rounded
                      : Icons.location_on_rounded,
                  size: 15,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: dotColor,
                ),
              ),
              if (selected != null) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const Text('Set',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: address,
            decoration: InputDecoration(
              hintText: '$title address',
              suffixIcon: IconButton(
                tooltip: 'Find coordinates',
                onPressed: onLocate,
                icon: const Icon(Icons.search_rounded),
              ),
            ),
            validator: validator,
          ),
          const SizedBox(height: 8),
          AppButton.outline(
            label: selected == null ? 'Pick on Map' : 'Change Map Point',
            icon: Icons.map_outlined,
            size: AppButtonSize.medium,
            onPressed: onPickMap,
          ),
          if (selected != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.gps_fixed_rounded,
                    size: 12, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${selected!.point.latitude.toStringAsFixed(5)}, ${selected!.point.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
