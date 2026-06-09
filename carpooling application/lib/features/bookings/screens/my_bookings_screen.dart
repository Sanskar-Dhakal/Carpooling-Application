import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/booking_model.dart';
import '../repository/bookings_repository.dart';
import '../../payments/screens/qr_payment_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _repo = BookingsRepository();
  late Future<List<BookingModel>> _bookings;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _bookings = _repo.myBookings();
  }

  void _reload() => setState(() => _bookings = _repo.myBookings());

  Future<void> _openQrPayment(BookingModel booking) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => QrPaymentScreen(booking: booking)),
    );
    if (changed == true) _reload();
  }

  Future<void> _authorizeWalletPayment(BookingModel booking) async {
    final passwordCtrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authorize Payment'),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Account password',
            prefixIcon: Icon(Icons.lock_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, passwordCtrl.text), child: const Text('Authorize')),
        ],
      ),
    );
    passwordCtrl.dispose();
    if (password == null || password.trim().isEmpty) return;

    setState(() => _busyId = booking.id);
    try {
      await _repo.authorizeWalletPayment(booking.id, password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet payment authorized')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: FutureBuilder<List<BookingModel>>(
        future: _bookings,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          }
          final bookings = snapshot.data!;
          if (bookings.isEmpty) return const Center(child: Text('No bookings yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final canPayQr = booking.paymentMethod == 'qr'
                  && ['confirmed', 'completed'].contains(booking.status)
                  && booking.paymentStatus != 'settled';
              final canAuthorizeWallet = booking.paymentMethod == 'wallet'
                  && booking.status == 'completed'
                  && booking.paymentStatus != 'settled';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _StatusIcon(status: booking.status),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(booking.routeLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${booking.seatsBooked} seats | ${booking.amountLabel} | ${booking.paymentMethod}'),
                          Text('Driver: ${booking.driver['name'] ?? 'Driver'}'),
                          Text('Booking: ${booking.status} | Payment: ${booking.paymentStatus}', style: const TextStyle(color: AppTheme.textSecondary)),
                        ]),
                      ),
                    ]),
                    if (booking.paymentMethod == 'wallet' && booking.paymentStatus != 'settled') ...[
                      const SizedBox(height: 10),
                      Text(
                        booking.status == 'completed'
                            ? 'Wallet amount is reserved. Enter your password to release it.'
                            : 'Wallet amount is reserved. It will be released if the ride is cancelled.',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                    if (canAuthorizeWallet) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _busyId == booking.id ? null : () => _authorizeWalletPayment(booking),
                        icon: _busyId == booking.id
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.lock_open_rounded),
                        label: const Text('Authorize Wallet Payment'),
                      ),
                    ],
                    if (booking.paymentMethod == 'cash' && booking.status == 'completed' && booking.paymentStatus != 'settled') ...[
                      const SizedBox(height: 10),
                      const Text('Cash payment is waiting for driver confirmation.', style: TextStyle(color: AppTheme.warning)),
                    ],
                    if (canPayQr) ...[
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _busyId == booking.id ? null : () => _openQrPayment(booking),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(booking.paymentStatus == 'passenger_confirmed' ? 'View QR Payment' : 'Pay by QR'),
                      ),
                    ],
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'confirmed' => AppTheme.success,
      'rejected' => AppTheme.error,
      'completed' => AppTheme.primary,
      _ => AppTheme.warning,
    };
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(Icons.event_seat, color: color),
    );
  }
}
