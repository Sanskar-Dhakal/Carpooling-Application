import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../payments/screens/payment_flow_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../tracking/screens/live_tracking_screen.dart';
import '../../reviews/screens/review_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/bookings/my');
      setState(() {
        _bookings = List<Map<String, dynamic>>.from(data['bookings'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filtered(String status) =>
      _bookings.where((b) => b['status'] == status).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Bookings'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Confirmed'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _BookingList(bookings: _filtered('pending'), onRefresh: _load),
                _BookingList(
                    bookings: _filtered('confirmed'),
                    onRefresh: _load,
                    showPay: true),
                _BookingList(
                    bookings: _filtered('completed'),
                    onRefresh: _load,
                    showPay: true),
                _BookingList(
                    bookings: _filtered('cancelled'), onRefresh: _load),
              ],
            ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final Future<void> Function() onRefresh;
  final bool showPay;

  const _BookingList(
      {required this.bookings, required this.onRefresh, this.showPay = false});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bookmark_outline, size: 64, color: AppTheme.border),
            SizedBox(height: 12),
            Text('No bookings here yet',
                style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (_, i) => _BookingCard(
            booking: bookings[i], showPay: showPay, onRefresh: onRefresh),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool showPay;
  final Future<void> Function() onRefresh;

  const _BookingCard(
      {required this.booking, required this.showPay, required this.onRefresh});

  Color get _statusColor {
    switch (booking['status']) {
      case 'confirmed':
        return AppTheme.success;
      case 'completed':
        return AppTheme.primary;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ride = booking['ride'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>? ?? {};
    final method = booking['paymentMethod'] as String? ?? 'cash';
    final payStatus = booking['paymentStatus'] as String? ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    (booking['status'] as String).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                Text('NPR ${booking['totalAmount']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RouteRow(
                  origin: ride['originAddress'] as String? ?? '',
                  destination: ride['destinationAddress'] as String? ?? '',
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Driver: ${driver['name'] ?? '-'}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                    TextButton(
                      onPressed: driver['id'] == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    userId: driver['id'].toString(),
                                  ),
                                ),
                              ),
                      child: const Text('Profile'),
                    ),
                    const Spacer(),
                    const Icon(Icons.event_seat_outlined,
                        size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('${booking['seatsBooked']} seat(s)',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  _PayBadge(method: method),
                  const SizedBox(width: 8),
                  _PayStatusBadge(status: payStatus)
                ]),
                if (booking['status'] == 'confirmed') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Track Live Map'),
                      onPressed: () => _openTracking(context, booking),
                    ),
                  ),
                ],
                if (showPay &&
                    (booking['status'] == 'confirmed' || booking['status'] == 'completed') &&
                    payStatus == 'pending') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                PaymentFlowScreen(booking: booking)),
                      ).then((_) => onRefresh()),
                    ),
                  ),
                ],
                if (booking['status'] == 'completed') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star_rate_rounded, size: 18),
                      label: const Text('Rate Trip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warning,
                        side: const BorderSide(color: AppTheme.warning),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReviewScreen(
                            bookingId: booking['id'].toString(),
                            reviewedUserName: driver['name']?.toString() ?? 'Driver',
                            isReviewingDriver: true,
                          ),
                        ),
                      ).then((_) => onRefresh()),
                    ),
                  ),
                ],
                if (booking['status'] == 'pending' || booking['status'] == 'confirmed') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Cancel Booking?'),
                            content: const Text(
                                'Are you sure you want to cancel this booking?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('No')),
                              TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes, Cancel',
                                      style: TextStyle(color: AppTheme.error))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            await ApiService.put(
                                '/bookings/${booking['id']}/cancel', {});
                            onRefresh();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: AppTheme.error),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error),
                      child: const Text('Cancel Booking'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openTracking(BuildContext context, Map<String, dynamic> booking) {
    final ride = booking['ride'] as Map<String, dynamic>? ?? {};
    final driver = booking['driver'] as Map<String, dynamic>? ?? {};
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
          driverName: driver['name']?.toString() ?? 'Driver',
              passengerOrigin: LatLng(
                (origin['lat'] is num) ? (origin['lat'] as num).toDouble() : double.tryParse(origin['lat']?.toString() ?? '27.7172') ?? 27.7172,
                (origin['lng'] is num) ? (origin['lng'] as num).toDouble() : double.tryParse(origin['lng']?.toString() ?? '85.3240') ?? 85.3240,
              ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String origin, destination;
  const _RouteRow({required this.origin, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.circle, size: 10, color: AppTheme.success),
            Container(width: 1.5, height: 20, color: AppTheme.border),
            const Icon(Icons.location_on, size: 14, color: AppTheme.error),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(origin,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(destination,
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayBadge extends StatelessWidget {
  final String method;
  const _PayBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String label;
    switch (method) {
      case 'wallet':
        icon = Icons.account_balance_wallet;
        label = 'Wallet';
        break;
      case 'qr':
        icon = Icons.qr_code;
        label = 'QR';
        break;
      default:
        icon = Icons.money;
        label = 'Cash';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PayStatusBadge extends StatelessWidget {
  final String status;
  const _PayStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'settled':
        color = AppTheme.success;
        break;
      case 'passenger_confirmed':
        color = AppTheme.warning;
        break;
      default:
        color = AppTheme.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style:
            TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
