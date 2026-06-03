import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../bookings/repository/bookings_repository.dart';
import '../models/ride_model.dart';
import '../repository/rides_repository.dart';
import '../widgets/route_map.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  const RideDetailScreen({super.key, required this.rideId});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final _repo = RidesRepository();
  final _bookingsRepo = BookingsRepository();
  late Future<RideModel> _ride;
  int _seats = 1;
  String _paymentMethod = 'cash';
  bool _booking = false;

  @override
  void initState() {
    super.initState();
    _ride = _repo.rideDetail(widget.rideId);
  }

  Future<void> _bookRide(RideModel ride) async {
    setState(() => _booking = true);
    try {
      await _bookingsRepo.createBooking(
        rideId: ride.id,
        seatsBooked: _seats,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking request sent')));
      Navigator.pushNamed(context, '/bookings/my');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Detail')),
      body: FutureBuilder<RideModel>(
        future: _ride,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          }
          final ride = snapshot.data!;
          final driver = ride.driver ?? {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SizedBox(height: 260, child: RouteMap(route: ride.route, origin: ride.origin, destination: ride.destination)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${ride.originAddress} -> ${ride.destinationAddress}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    _Info(icon: Icons.event, text: ride.departureTime.toLocal().toString().substring(0, 16)),
                    _Info(icon: Icons.airline_seat_recline_normal, text: '${ride.seatsAvailable}/${ride.seatsTotal} seats available'),
                    _Info(icon: Icons.payments, text: 'Rs ${ride.pricePerSeat.toStringAsFixed(0)} per seat'),
                    _Info(icon: Icons.route, text: '${ride.distanceLabel}, ETA ${ride.etaLabel}'),
                    if (ride.match != null)
                      _Info(icon: Icons.alt_route, text: 'Detour score ${(((ride.match!['detourScore'] ?? 0) as num) * 100).toStringAsFixed(0)}%'),
                  ]),
                ),
              ),
              if (ride.status == 'active' && ride.seatsAvailable > 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Book seats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Text('Seats'),
                        const Spacer(),
                        IconButton(
                          onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        SizedBox(width: 28, child: Text('$_seats', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
                        IconButton(
                          onPressed: _seats < ride.seatsAvailable ? () => setState(() => _seats++) : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments)),
                          ButtonSegment(value: 'wallet', label: Text('Wallet'), icon: Icon(Icons.account_balance_wallet)),
                          ButtonSegment(value: 'qr', label: Text('QR'), icon: Icon(Icons.qr_code)),
                        ],
                        selected: {_paymentMethod},
                        onSelectionChanged: (value) => setState(() => _paymentMethod = value.first),
                      ),
                      const SizedBox(height: 12),
                      Text('Total: Rs ${(ride.pricePerSeat * _seats).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _booking ? null : () => _bookRide(ride),
                        icon: _booking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.event_seat),
                        label: const Text('Request Booking'),
                      ),
                    ]),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(driver['name'] ?? 'Driver'),
                  subtitle: Text('Rating ${(driver['rating'] ?? 0).toString()} | ${driver['phone'] ?? 'No phone'}'),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ride.preferences.entries
                        .where((entry) => entry.value == true)
                        .map((entry) => Chip(label: Text(entry.key)))
                        .toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}
