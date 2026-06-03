import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/booking_model.dart';
import '../repository/bookings_repository.dart';

class DriverBookingRequestsScreen extends StatefulWidget {
  const DriverBookingRequestsScreen({super.key});

  @override
  State<DriverBookingRequestsScreen> createState() => _DriverBookingRequestsScreenState();
}

class _DriverBookingRequestsScreenState extends State<DriverBookingRequestsScreen> {
  final _repo = BookingsRepository();
  late Future<List<BookingModel>> _bookings;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _bookings = _repo.driverBookings();

  Future<void> _update(BookingModel booking, String status) async {
    setState(() => _busyId = booking.id);
    try {
      await _repo.updateStatus(booking.id, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking $status')));
      setState(() {
        _reload();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _confirmPayment(BookingModel booking) async {
    setState(() => _busyId = booking.id);
    try {
      await _repo.confirmPayment(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment settled')));
      setState(() {
        _reload();
      });
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
      appBar: AppBar(title: const Text('Booking Requests'), backgroundColor: AppTheme.driverColor),
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
          if (bookings.isEmpty) return const Center(child: Text('No booking requests yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final booking = bookings[index];
              final pending = booking.status == 'pending';
              final busy = _busyId == booking.id;
              final canConfirmPayment = ['cash', 'qr'].contains(booking.paymentMethod)
                  && ['confirmed', 'completed'].contains(booking.status)
                  && booking.paymentStatus != 'settled'
                  && (booking.paymentMethod == 'cash' || booking.paymentStatus == 'passenger_confirmed');
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(booking.routeLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Passenger: ${booking.passenger['name'] ?? 'Passenger'}'),
                    Text('${booking.seatsBooked} seats | ${booking.amountLabel} | ${booking.paymentMethod}'),
                    Text('Status: ${booking.status} | Payment: ${booking.paymentStatus}', style: const TextStyle(color: AppTheme.textSecondary)),
                    if (booking.paymentScreenshotUrl != null) ...[
                      const SizedBox(height: 4),
                      const Text('QR proof submitted', style: TextStyle(color: AppTheme.success)),
                    ],
                    if (pending) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : () => _update(booking, 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: busy ? null : () => _update(booking, 'confirmed'),
                            icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                            label: const Text('Accept'),
                          ),
                        ),
                      ]),
                    ],
                    if (canConfirmPayment) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _confirmPayment(booking),
                        icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payments_rounded),
                        label: Text(booking.paymentMethod == 'cash' ? 'Confirm Cash Received' : 'Confirm QR Received'),
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
