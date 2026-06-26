import 'package:flutter/material.dart';
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
        _bookings =
            List<Map<String, dynamic>>.from(data['bookings'] ?? []);
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
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: AppTheme.passengerColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.passengerColor,
                      AppTheme.passengerColor.withOpacity(0.75),
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
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: const Icon(Icons.bookmark_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'My Bookings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Track all your ride bookings',
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
              controller: _tabs,
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
                Tab(text: 'Pending'),
                Tab(text: 'Confirmed'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.passengerColor))
            : TabBarView(
                controller: _tabs,
                children: [
                  _BookingList(
                      bookings: _filtered('pending'), onRefresh: _load),
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
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<Map<String, dynamic>> bookings;
  final Future<void> Function() onRefresh;
  final bool showPay;

  const _BookingList(
      {required this.bookings,
      required this.onRefresh,
      this.showPay = false});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: const Icon(Icons.bookmark_outline,
                  size: 36, color: AppTheme.textTertiary),
            ),
            const SizedBox(height: 14),
            const Text('No bookings here yet',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    fontSize: 15)),
            const SizedBox(height: 4),
            const Text('Your bookings will appear here',
                style:
                    TextStyle(color: AppTheme.textTertiary, fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.passengerColor,
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
      {required this.booking,
      required this.showPay,
      required this.onRefresh});

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

  IconData get _statusIcon {
    switch (booking['status']) {
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'completed':
        return Icons.flag_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.schedule_rounded;
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status strip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusLg)),
            ),
            child: Row(
              children: [
                Icon(_statusIcon, size: 15, color: _statusColor),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    (booking['status'] as String).toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const Spacer(),
                Text(
                  'NPR ${booking['totalAmount']}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route
                _RouteRow(
                  origin: ride['originAddress'] as String? ?? '',
                  destination: ride['destinationAddress'] as String? ?? '',
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppTheme.divider),
                const SizedBox(height: 10),

                // Driver + seats row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.driverColor.withOpacity(0.1),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: const Icon(Icons.drive_eta_rounded,
                          size: 16, color: AppTheme.driverColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        driver['name'] ?? '-',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppTheme.textPrimary),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: driver['id'] == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                      userId: driver['id'].toString()),
                                ),
                              ),
                      child: const Text('Profile',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_seat_outlined,
                              size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            '${booking['seatsBooked']} seat(s)',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Payment badges
                Row(children: [
                  _PayBadge(method: method),
                  const SizedBox(width: 8),
                  _PayStatusBadge(status: payStatus),
                ]),

                // Action buttons
                if (booking['status'] == 'confirmed') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 17),
                      label: const Text('Track Live Map'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.border),
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd)),
                      ),
                      onPressed: () => _openTracking(context, booking),
                    ),
                  ),
                ],
                if (showPay &&
                    (booking['status'] == 'confirmed' ||
                        booking['status'] == 'completed') &&
                    payStatus == 'pending') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.payment, size: 17),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusMd)),
                      ),
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
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.star_rate_rounded, size: 17),
                      label: const Text('Rate Trip'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warning,
                        side: const BorderSide(color: AppTheme.warning),
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
                                driver['name']?.toString() ?? 'Driver',
                            isReviewingDriver: true,
                          ),
                        ),
                      ).then((_) => onRefresh()),
                    ),
                  ),
                ],
                if (booking['status'] == 'pending' ||
                    booking['status'] == 'confirmed') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
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
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: const Text('Yes, Cancel',
                                      style: TextStyle(
                                          color: AppTheme.error))),
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

  void _openTracking(
      BuildContext context, Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveTrackingScreen(
          bookingId: booking['id'].toString(),
          isDriver: false,
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
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.driverColor,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppTheme.driverColor.withOpacity(0.3), width: 2),
              ),
            ),
            Container(
                width: 1.5,
                height: 22,
                color: AppTheme.border),
            const Icon(Icons.location_on_rounded,
                size: 14, color: AppTheme.error),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(origin,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 10),
              Text(destination,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
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
        icon = Icons.account_balance_wallet_rounded;
        label = 'Wallet';
        break;
      case 'qr':
        icon = Icons.qr_code_rounded;
        label = 'QR';
        break;
      default:
        icon = Icons.money_rounded;
        label = 'Cash';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.primary),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
