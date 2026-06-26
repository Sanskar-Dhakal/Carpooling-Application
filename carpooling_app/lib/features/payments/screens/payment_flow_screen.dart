import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

/// Central screen that shows the correct payment UI based on booking.paymentMethod.
/// Invoked from MyBookingsScreen when passenger taps "Pay Now".
class PaymentFlowScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const PaymentFlowScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final method = booking['paymentMethod'] as String? ?? 'cash';
    switch (method) {
      case 'wallet':
        return _WalletPayScreen(booking: booking);
      case 'qr':
        return _QrPayScreen(booking: booking);
      default:
        return _CashPayScreen(booking: booking);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wallet payment: just confirm with password
// ─────────────────────────────────────────────────────────────────────────────
class _WalletPayScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _WalletPayScreen({required this.booking});

  @override
  State<_WalletPayScreen> createState() => _WalletPayState();
}

class _WalletPayState extends State<_WalletPayScreen> {
  final _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  Future<void> _authorize() async {
    if (_pwCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiService.post('/bookings/${widget.booking['id']}/authorize-wallet', {
        'password': _pwCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment authorised! 🎉'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.booking['totalAmount'];
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Wallet Payment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmountCard(amount: amount, method: 'Wallet'),
            const SizedBox(height: 28),
            const Text('Enter your password to authorise this payment',
                style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _pwCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Authorise Payment'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                onPressed: _loading ? null : _authorize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrPayScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _QrPayScreen({required this.booking});

  @override
  Widget build(BuildContext context) {
    final driver = booking['driver'] as Map<String, dynamic>? ?? {};
    final amount = booking['totalAmount'];
    final qrId = driver['qrPaymentId'] ?? '-';
    final qrLabel = driver['qrPaymentLabel'] ?? 'eSewa / Khalti';
    final paymentMethod = booking['paymentMethod'] ?? 'cash';
    final qrImages = driver['qrPaymentImages'] ?? {};
    final qrImageUrl = (qrImages is Map) ? qrImages[paymentMethod] : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('QR Payment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmountCard(amount: amount, method: 'QR'),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  if (qrImageUrl != null)
                    CachedNetworkImage(
                      imageUrl: qrImageUrl,
                      height: 180,
                      width: 180,
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const SizedBox(
                        height: 180,
                        width: 180,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
                      ),
                      errorWidget: (context, url, error) => const SizedBox(
                        height: 180,
                        width: 180,
                        child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
                      ),
                    )
                  else
                    const Icon(Icons.qr_code, size: 80, color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(qrLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Send to: $qrId',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Amount: NPR $amount',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Open your payment app\n2. Send the amount above to the ID shown\n3. Show the success screen to your driver',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.6),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text("Close"),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cash payment: passenger just sees instructions
// ─────────────────────────────────────────────────────────────────────────────
class _CashPayScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _CashPayScreen({required this.booking});

  @override
  Widget build(BuildContext context) {
    final amount = booking['totalAmount'];
    final driver = booking['driver'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Cash Payment')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmountCard(amount: amount, method: 'Cash'),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  const Icon(Icons.money, size: 64, color: AppTheme.success),
                  const SizedBox(height: 16),
                  Text(
                    'Pay NPR $amount cash to ${driver['name'] ?? 'your driver'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hand the cash to your driver at the end of the ride. '
                    'The driver will mark the payment as received.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warning),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please prepare exact change if possible.',
                      style: TextStyle(color: AppTheme.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Driver: mark cash received
// ─────────────────────────────────────────────────────────────────────────────
class DriverCashReceivedScreen extends StatefulWidget {
  final Map<String, dynamic> booking;
  const DriverCashReceivedScreen({super.key, required this.booking});

  @override
  State<DriverCashReceivedScreen> createState() => _DriverCashState();
}

class _DriverCashState extends State<DriverCashReceivedScreen> {
  bool _loading = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await ApiService.put('/bookings/${widget.booking['id']}/cash-received', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cash payment confirmed!'), backgroundColor: AppTheme.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final passenger = widget.booking['passenger'] as Map<String, dynamic>? ?? {};
    final amount = widget.booking['totalAmount'];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Confirm Cash')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.money, size: 80, color: AppTheme.success),
            const SizedBox(height: 20),
            Text(
              'Did you receive NPR $amount cash from ${passenger['name'] ?? 'passenger'}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle),
                label: const Text('Yes, Cash Received'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                onPressed: _loading ? null : _confirm,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  final dynamic amount;
  final String method;
  const _AmountCard({required this.amount, required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amount Due', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text('NPR $amount',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('via $method', style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ],
      ),
    );
  }
}
