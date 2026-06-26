import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../../reviews/screens/review_screen.dart';
import 'package:intl/intl.dart';

class DriverBookingRequestsScreen extends StatefulWidget {
  const DriverBookingRequestsScreen({super.key});

  @override
  State<DriverBookingRequestsScreen> createState() => _State();
}

class _State extends State<DriverBookingRequestsScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/bookings/driver');
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? [])
            .where((b) => ['pending', 'confirmed', 'completed'].contains(b['status']))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _respond(String bookingId, String status) async {
    try {
      if (status == 'refresh_only') {
        // Do nothing, just refresh below
      } else if (['confirm', 'reject'].contains(status)) {
        await ApiService.put('/bookings/$bookingId/$status', {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip status updated to $status!'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        await ApiService.patch('/bookings/$bookingId/status', {'status': status});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip status updated to $status!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
      _load();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requested = _bookings.where((b) => b['status'] == 'pending').toList();
    final confirmed = _bookings.where((b) => b['status'] == 'confirmed').toList();
    final completed = _bookings.where((b) => b['status'] == 'completed' && b['paymentStatus'] != 'settled').toList();
    final paid = _bookings.where((b) => b['paymentStatus'] == 'settled').toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Driver Trips'),
        backgroundColor: AppTheme.driverColor,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Recent Post'),
            Tab(text: 'Requested'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Completed'),
            Tab(text: 'Paid'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                const _MyRidesTab(),
                _BookingList(bookings: requested, onRefresh: _load, onRespond: _respond),
                _BookingList(bookings: confirmed, onRefresh: _load, onRespond: _respond),
                _BookingList(bookings: completed, onRefresh: _load, onRespond: _respond),
                _BookingList(bookings: paid, onRefresh: _load, onRespond: _respond),
              ],
            ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String, String) onRespond;

  const _BookingList({required this.bookings, required this.onRefresh, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: bookings.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: AppTheme.border),
                  SizedBox(height: 12),
                  Text('No trips in this category', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (_, i) => _RequestCard(
                booking: bookings[i],
                onStatusUpdate: (status) => onRespond(bookings[i]['id'], status),
              ),
            ),
    );
  }
}

class _MyRidesTab extends StatefulWidget {
  const _MyRidesTab();
  @override
  State<_MyRidesTab> createState() => _MyRidesTabState();
}

class _MyRidesTabState extends State<_MyRidesTab> {
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/rides/my');
      setState(() {
        _rides = List<Map<String, dynamic>>.from(data['rides'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: _rides.isEmpty
          ? const Center(child: Text('You have not posted any rides.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rides.length,
              itemBuilder: (_, i) {
                final ride = _rides[i];
                final origin = ride['originAddress'] ?? 'Unknown';
                final dest = ride['destinationAddress'] ?? 'Unknown';
                final date = DateTime.tryParse(ride['departureTime'] ?? '')?.toLocal();
                final dateStr = date != null ? DateFormat('MMM d, yyyy h:mm a').format(date) : '';
                final status = (ride['status'] ?? 'unknown').toUpperCase();
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'COMPLETED' ? AppTheme.success.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: status == 'COMPLETED' ? AppTheme.success : AppTheme.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.trip_origin, color: AppTheme.success, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(origin, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: AppTheme.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(dest, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final ValueChanged<String> onStatusUpdate;

  const _RequestCard(
      {required this.booking, required this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    final passenger = booking['passenger'] as Map<String, dynamic>? ?? {};
    final ride = booking['ride'] as Map<String, dynamic>? ?? {};
    final method = booking['paymentMethod'] as String? ?? 'cash';
    final status = booking['status'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary,
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passenger['name'] ?? 'Passenger',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 13, color: AppTheme.warning),
                        Text(
                           ' ${(passenger['rating'] is num) ? (passenger['rating'] as num).toDouble().toStringAsFixed(1) : double.tryParse(passenger['rating']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0'}',
                           style: const TextStyle(
                               fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
              Text('NPR ${booking['totalAmount']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const Divider(height: 20),
          _InfoRow(Icons.event_seat_outlined,
              '${booking['seatsBooked']} seat(s) requested'),
          const SizedBox(height: 6),
          _InfoRow(Icons.location_on_outlined,
              '${ride['originAddress'] ?? ''} → ${ride['destinationAddress'] ?? ''}'),
          const SizedBox(height: 6),
          _InfoRow(
            method == 'wallet'
                ? Icons.account_balance_wallet
                : method == 'qr'
                    ? Icons.qr_code
                    : Icons.money,
            'Payment: ${method.toUpperCase()}',
          ),
          const SizedBox(height: 16),
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error),
                    onPressed: () => onStatusUpdate('reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success),
                    onPressed: () => onStatusUpdate('confirm'),
                  ),
                ),
              ],
            )
          else if (status == 'confirmed')
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Start Live Map'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.driverColor),
                    onPressed: () => _openDriverTracking(context, booking),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusUpdate('cancelled'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                        child: const Text('Cancel Trip'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onStatusUpdate('completed'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                        child: const Text('Complete Trip'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else if (status == 'completed')
            Column(
              children: [
                if (booking['paymentStatus'] != 'settled') ...[
                  if (booking['paymentMethod'] == 'wallet')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_empty, size: 16, color: AppTheme.warning),
                          SizedBox(width: 8),
                          Text('Waiting for passenger to authorise Wallet', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.payments_outlined, size: 18),
                        label: Text(booking['paymentMethod'] == 'qr' ? 'Verify QR Payment' : 'Confirm Cash Received'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                        onPressed: () async {
                          try {
                             await ApiService.post('/bookings/${booking['id']}/confirm-payment', {});
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verified successfully!'), backgroundColor: AppTheme.success));
                             onStatusUpdate('refresh_only');
                          } catch (e) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.star_rate_rounded, size: 18),
                    label: const Text('Rate Passenger'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warning,
                      side: const BorderSide(color: AppTheme.warning),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(
                          bookingId: booking['id'].toString(),
                          reviewedUserName: passenger['name']?.toString() ?? 'Passenger',
                          isReviewingDriver: false,
                        ),
                      ),
                    ).then((_) => onStatusUpdate('refresh_only')),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _openDriverTracking(BuildContext context, Map<String, dynamic> booking) {
    final ride = booking['ride'] as Map<String, dynamic>? ?? {};
    final passenger = booking['passenger'] as Map<String, dynamic>? ?? {};
    final origin = ride['origin'] as Map<String, dynamic>? ?? {};
    final route = (ride['route'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          rideId: ride['id']?.toString() ?? booking['rideId'].toString(),
          routePoints: route,
          driverName: passenger['name']?.toString() ?? 'Passenger',
              passengerOrigin: LatLng(
                (origin['lat'] is num) ? (origin['lat'] as num).toDouble() : double.tryParse(origin['lat']?.toString() ?? '27.7172') ?? 27.7172,
                (origin['lng'] is num) ? (origin['lng'] as num).toDouble() : double.tryParse(origin['lng']?.toString() ?? '85.3240') ?? 85.3240,
              ),
          isDriver: true,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary))),
        ],
      );
}
