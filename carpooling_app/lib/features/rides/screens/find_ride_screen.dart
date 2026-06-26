import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/routing_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import '../../profile/screens/profile_screen.dart';
import '../widgets/route_map.dart';
import 'map_location_picker_screen.dart';

class FindRideScreen extends StatefulWidget {
  const FindRideScreen({super.key});

  @override
  State<FindRideScreen> createState() => _FindRideScreenState();
}

class _FindRideScreenState extends State<FindRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originAddress = TextEditingController();
  final _originLat = TextEditingController();
  final _originLng = TextEditingController();
  final _destinationAddress = TextEditingController();
  final _destinationLat = TextEditingController();
  final _destinationLng = TextEditingController();
  bool _loading = false;
  PickedMapLocation? _origin;
  PickedMapLocation? _destination;
  List<Map<String, dynamic>> _rides = [];
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
    // Falls back to an empty list (straight line) if OSRM is unreachable.
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
    super.dispose();
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

  Future<void> _search() async {
    if (!_formKey.currentState!.validate()) return;
    if (_origin == null || _destination == null) {
      showAppSnackBar(context, 'Pickup and dropoff map locations are required', isError: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _rides = [];
    });
    try {
      final query = Uri(queryParameters: {
        'originLat': _origin!.point.latitude.toString(),
        'originLng': _origin!.point.longitude.toString(),
        'destinationLat': _destination!.point.latitude.toString(),
        'destinationLng': _destination!.point.longitude.toString(),
      }).query;
      final data = await ApiService.get('/rides/search?$query');
      final rides = data['rides'] as List<dynamic>? ?? [];
      setState(() => _rides = rides.cast<Map<String, dynamic>>());
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _bookRide(Map<String, dynamic> ride) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || !authState.user.isVerified) {
      showAppSnackBar(context, 'Please verify your account before booking a ride', isError: true);
      return;
    }

    final seatsController = TextEditingController(text: '1');
    var paymentMethod = AppConstants.paymentCash;
    final farePerSeat = _farePerSeat(ride);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final seats = int.tryParse(seatsController.text.trim()) ?? 1;
          final total = farePerSeat * seats.clamp(1, 99);
          return AlertDialog(
            title: const Text('Book Ride'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Seats',
                  controller: seatsController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  items: const [
                    DropdownMenuItem(value: AppConstants.paymentCash, child: Text('Cash')),
                    DropdownMenuItem(value: AppConstants.paymentWallet, child: Text('Wallet')),
                    DropdownMenuItem(value: AppConstants.paymentQR, child: Text('QR')),
                  ],
                  onChanged: (value) => setDialogState(() => paymentMethod = value ?? AppConstants.paymentCash),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.successBg, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  child: Text(
                    'Fare: NPR ${_formatMoney(farePerSeat)} × ${seats.clamp(1, 99)} = NPR ${_formatMoney(total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.success, fontSize: 13.5),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              Expanded(
                child: AppButton.outline(
                  label: 'Cancel',
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton.primary(
                  label: 'Book',
                  size: AppButtonSize.medium,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;

    final seats = int.tryParse(seatsController.text.trim());
    if (seats == null || seats < 1) {
      if (!mounted) return;
      showAppSnackBar(context, 'Enter valid seats', isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      await ApiService.post('/bookings', {
        'rideId': ride['id'],
        'seatsBooked': seats,
        'paymentMethod': paymentMethod,
        'originLat': _origin!.point.latitude,
        'originLng': _origin!.point.longitude,
        'destinationLat': _destination!.point.latitude,
        'destinationLng': _destination!.point.longitude,
      });
      if (!mounted) return;
      showAppSnackBar(context, 'Booking request sent');
      Navigator.pushNamed(context, '/passenger/bookings');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Find a Ride')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                RouteMap(
                  origin: _origin?.point,
                  destination: _destination?.point,
                  route: _routePoints,
                  onTap: () => _pickOnMap(isOrigin: _origin == null),
                ),
                const SizedBox(height: 12),
                _LocationFields(
                  title: 'Pickup',
                  address: _originAddress,
                  onLocate: () => _geocode(
                      address: _originAddress,
                      lat: _originLat,
                      lng: _originLng),
                  onPickMap: () => _pickOnMap(isOrigin: true),
                  selected: _origin,
                ),
                const SizedBox(height: 14),
                _LocationFields(
                  title: 'Dropoff',
                  address: _destinationAddress,
                  onLocate: () => _geocode(
                    address: _destinationAddress,
                    lat: _destinationLat,
                    lng: _destinationLng,
                  ),
                  onPickMap: () => _pickOnMap(isOrigin: false),
                  selected: _destination,
                ),
                const SizedBox(height: 18),
                AppButton.primary(
                  label: 'Search Rides',
                  icon: Icons.search_rounded,
                  loading: _loading,
                  onPressed: _loading ? null : _search,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_loading && _rides.isEmpty) ...[
            const RideCardSkeleton(),
            const RideCardSkeleton(),
          ] else if (!_loading && _rides.isEmpty)
            const AppEmptyState(
              icon: Icons.directions_car_outlined,
              title: 'No rides found yet',
              subtitle: 'Set your pickup and dropoff points, then tap "Search Rides" to find available drivers.',
            )
          else ...[
            SectionHeader(title: '${_rides.length} ride${_rides.length == 1 ? '' : 's'} found'),
            const SizedBox(height: 12),
            for (final ride in _rides) ...[
              _RideResult(ride: ride, onBook: () => _bookRide(ride)),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _farePerSeat(Map<String, dynamic> ride) {
  final passengerFare = _asDouble(ride['passengerPricePerSeat']);
  if (passengerFare > 0) return passengerFare;
  return _asDouble(ride['pricePerSeat']);
}

String _formatMoney(dynamic value) {
  final amount = _asDouble(value);
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
}

String _distanceLabel(dynamic meters) {
  final distanceMeters = _asDouble(meters);
  if (distanceMeters <= 0) return '';
  return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
}

class _LocationFields extends StatelessWidget {
  final String title;
  final TextEditingController address;
  final VoidCallback onLocate;
  final VoidCallback onPickMap;
  final PickedMapLocation? selected;

  const _LocationFields({
    required this.title,
    required this.address,
    required this.onLocate,
    required this.onPickMap,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                title == 'Pickup' ? Icons.trip_origin_rounded : Icons.location_on_rounded,
                size: 16,
                color: title == 'Pickup' ? AppTheme.driverColor : AppTheme.error,
              ),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: '',
            hint: '$title address',
            controller: address,
            suffixIcon: IconButton(
              tooltip: 'Find coordinates',
              onPressed: onLocate,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 10),
          AppButton.outline(
            label: selected == null ? 'Pick on Map' : 'Change Map Point',
            icon: Icons.map_outlined,
            size: AppButtonSize.medium,
            onPressed: onPickMap,
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Text(
              '${selected!.point.latitude.toStringAsFixed(5)}, ${selected!.point.longitude.toStringAsFixed(5)}',
              style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _RideResult extends StatelessWidget {
  final Map<String, dynamic> ride;
  final VoidCallback onBook;

  const _RideResult({required this.ride, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final driver = ride['driver'] as Map<String, dynamic>?;
    final departureRaw = ride['departureTime']?.toString();
    final departure = departureRaw == null
        ? null
        : DateTime.tryParse(departureRaw)?.toLocal();
    final fullPrice = ride['pricePerSeat'];
    final fare = _farePerSeat(ride);
    final passengerDistance = _distanceLabel(ride['passengerDistanceMeters']);
    final seats = ride['seatsAvailable'];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RouteRow(
            from: (ride['originAddress'] ?? 'Pickup').toString(),
            to: (ride['destinationAddress'] ?? 'Dropoff').toString(),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.passengerColor.withOpacity(0.12),
                child: const Icon(Icons.person_rounded, size: 17, color: AppTheme.passengerColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(driver?['name'] ?? 'Driver', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
              ),
              StatusBadge(
                label: seats == null ? 'Seats N/A' : '$seats seats left',
                tone: BadgeTone.success,
                icon: Icons.event_seat_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 15, color: AppTheme.textTertiary),
              const SizedBox(width: 6),
              Text(
                departure == null ? 'Departure time unavailable' : DateFormat('MMM d, h:mm a').format(departure),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NPR ${_formatMoney(fare)}/seat${passengerDistance.isEmpty ? '' : ' · $passengerDistance'}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary, fontSize: 14),
                ),
                if (_asDouble(fullPrice) > 0 && _asDouble(fullPrice) != fare)
                  Text('Full: NPR ${_formatMoney(fullPrice)}', style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  label: 'Driver Profile',
                  icon: Icons.person_outline_rounded,
                  size: AppButtonSize.medium,
                  onPressed: driver?['id'] == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: driver!['id'].toString()),
                            ),
                          ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.primary(
                  label: 'Book',
                  icon: Icons.event_available_rounded,
                  size: AppButtonSize.medium,
                  onPressed: onBook,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}