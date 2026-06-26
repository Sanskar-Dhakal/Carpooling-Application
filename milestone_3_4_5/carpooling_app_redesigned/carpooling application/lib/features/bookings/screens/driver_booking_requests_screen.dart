import 'package:flutter/material.dart';
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

class _State extends State<DriverBookingRequestsScreen>
    with SingleTickerProviderStateMixin {
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
            .where((b) =>
                ['pending', 'confirmed', 'completed'].contains(b['status']))
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
        await ApiService.patch(
            '/bookings/$bookingId/status', {'status': status});
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
        SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requested =
        _bookings.where((b) => b['status'] == 'pending').toList();
    final confirmed =
        _bookings.where((b) => b['status'] == 'confirmed').toList();
    final completed = _bookings
        .where((b) =>
            b['status'] == 'completed' && b['paymentStatus'] != 'settled')
        .toList();
    final paid = _bookings
        .where((b) => b['paymentStatus'] == 'settled')
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
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
                      AppTheme.driverColor.withOpacity(0.75),
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
                              child: const Icon(Icons.drive_eta_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Driver Trips',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Manage your ride requests',
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
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'My Rides'),
                Tab(text: 'Requested'),
                Tab(text: 'Confirmed'),
                Tab(text: 'Completed'),
                Tab(text: 'Paid'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.driverColor))
            : TabBarView(
                controller: _tabController,
                children: [
                  const _MyRidesTab(),
                  _BookingList(
                      bookings: requested,
                      onRefresh: _load,
                      onRespond: _respond),
                  _BookingList(
                      bookings: confirmed,
                      onRefresh: _load,
                      onRespond: _respond),
                  _BookingList(
                      bookings: completed,
                      onRefresh: _load,
                      onRespond: _respond),
                  _BookingList(
                      bookings: paid,
                      onRefresh: _load,
                      onRespond: _respond),
                ],
              ),
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String, String) onRespond;

  const _BookingList(
      {required this.bookings,
      required this.onRefresh,
      required this.onRespond});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.driverColor,
      child: bookings.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: const Icon(Icons.inbox_outlined,
                        size: 36, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 14),
                  const Text('No trips in this category',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 15)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (_, i) => _RequestCard(
                booking: bookings[i],
                onStatusUpdate: (status) =>
                    onRespond(bookings[i]['id'], status),
              ),
            ),
    );
  }
}

// ── My Rides Tab ──────────────────────────────────────────────────────────────

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
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.driverColor));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.driverColor,
      child: _rides.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXl),
                    ),
                    child: const Icon(Icons.add_road_rounded,
                        size: 36, color: AppTheme.textTertiary),
                  ),
                  const SizedBox(height: 14),
                  const Text('No rides posted yet',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          fontSize: 15)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _rides.length,
              itemBuilder: (_, i) {
                final ride = _rides[i];
                final origin = ride['originAddress'] ?? 'Unknown';
                final dest = ride['destinationAddress'] ?? 'Unknown';
                final date = DateTime.tryParse(
                        ride['departureTime'] ?? '')
                    ?.toLocal();
                final dateStr = date != null
                    ? DateFormat('MMM d, yyyy h:mm a').format(date)
                    : '';
                final status =
                    (ride['status'] ?? 'unknown').toString();
                final isCompleted = status == 'completed';
                final statusColor =
                    isCompleted ? AppTheme.success : AppTheme.primary;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              size: 14, color: AppTheme.textTertiary),
                          const SizedBox(width: 6),
                          Text(dateStr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusPill),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Column(children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: AppTheme.driverColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                              width: 1.5,
                              height: 18,
                              color: AppTheme.border),
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: AppTheme.error),
                        ]),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(origin,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                              const SizedBox(height: 8),
                              Text(dest,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final ValueChanged<String> onStatusUpdate;

  const _RequestCard(
      {required this.booking, required this.onStatusUpdate});

  @override
  Widget build(BuildContext context) {
    final passenger =
        booking['passenger'] as Map<String, dynamic>? ?? {};
    final ride = booking['ride'] as Map<String, dynamic>? ?? {};
    final method = booking['paymentMethod'] as String? ?? 'cash';
    final status = booking['status'] as String? ?? 'pending';
    final passengerRating = passenger['rating'];
    final ratingVal = (passengerRating is num)
        ? passengerRating.toDouble()
        : double.tryParse(passengerRating?.toString() ?? '') ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passenger header strip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.passengerColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: AppTheme.passengerColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        passenger['name'] ?? 'Passenger',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary),
                      ),
                      if (ratingVal > 0)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 12, color: AppTheme.warning),
                            const SizedBox(width: 3),
                            Text(
                              ratingVal.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NPR ${booking['totalAmount']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppTheme.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _methodColor(method).withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        method.toUpperCase(),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _methodColor(method)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seats + route
                _InfoRow(Icons.event_seat_outlined,
                    '${booking['seatsBooked']} seat(s) requested'),
                const SizedBox(height: 6),
                _InfoRow(
                  Icons.route_rounded,
                  '${ride['originAddress'] ?? ''} → ${ride['destinationAddress'] ?? ''}',
                ),
                const SizedBox(height: 14),

                // Action buttons
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close_rounded, size: 17),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.error,
                            side: BorderSide(
                                color: AppTheme.error.withOpacity(0.4)),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd)),
                          ),
                          onPressed: () => onStatusUpdate('reject'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_rounded, size: 17),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd)),
                          ),
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
                          icon: const Icon(Icons.navigation_rounded,
                              size: 17),
                          label: const Text('Start Live Map'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.driverColor,
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd)),
                          ),
                          onPressed: () =>
                              _openDriverTracking(context, booking),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: BorderSide(
                                    color: AppTheme.error.withOpacity(0.4)),
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd)),
                              ),
                              onPressed: () =>
                                  onStatusUpdate('cancelled'),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd)),
                              ),
                              onPressed: () =>
                                  onStatusUpdate('completed'),
                              child: const Text('Complete'),
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
                            padding: const EdgeInsets.symmetric(
                                vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(
                                  AppTheme.radiusMd),
                              border: Border.all(
                                  color:
                                      AppTheme.warning.withOpacity(0.2)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.hourglass_empty_rounded,
                                    size: 15, color: AppTheme.warning),
                                SizedBox(width: 8),
                                Text(
                                  'Waiting for passenger wallet authorisation',
                                  style: TextStyle(
                                      color: AppTheme.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payments_outlined,
                                  size: 17),
                              label: Text(
                                  booking['paymentMethod'] == 'qr'
                                      ? 'Verify QR Payment'
                                      : 'Confirm Cash Received'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                minimumSize: const Size(0, 44),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd)),
                              ),
                              onPressed: () async {
                                try {
                                  await ApiService.post(
                                      '/bookings/${booking['id']}/confirm-payment',
                                      {});
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Payment verified successfully!'),
                                    backgroundColor: AppTheme.success,
                                  ));
                                  onStatusUpdate('refresh_only');
                                } catch (e) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(e.toString()),
                                    backgroundColor: AppTheme.error,
                                  ));
                                }
                              },
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.star_rate_rounded,
                              size: 17),
                          label: const Text('Rate Passenger'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.warning,
                            side: const BorderSide(
                                color: AppTheme.warning),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                bookingId: booking['id'].toString(),
                                reviewedUserName:
                                    passenger['name']?.toString() ??
                                        'Passenger',
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
          ),
        ],
      ),
    );
  }

  Color _methodColor(String method) {
    switch (method) {
      case 'wallet':
        return AppTheme.info;
      case 'qr':
        return AppTheme.accent;
      default:
        return AppTheme.driverColor;
    }
  }

  void _openDriverTracking(
      BuildContext context, Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          bookingId: booking['id'].toString(),
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
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, size: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
