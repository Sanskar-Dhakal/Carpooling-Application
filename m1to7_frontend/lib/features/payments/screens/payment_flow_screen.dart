import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class PaymentFlowScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const PaymentFlowScreen({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final method = booking['paymentMethod'] as String? ?? 'cash';
    switch (method) {
      case 'wallet': return _WalletPayScreen(booking: booking);
      case 'qr': return _QrPayScreen(booking: booking);
      default: return _CashPayScreen(booking: booking);
    }
  }
}

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
      await ApiService.post('/bookings/${widget.booking['id']}/authorize-wallet', {'password': _pwCtrl.text});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment authorised! 🎉'), backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.booking['totalAmount'];
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Wallet Payment'), backgroundColor: AppTheme.primary),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmountCard(amount: amount, method: 'Wallet', icon: Icons.account_balance_wallet_rounded),
            const SizedBox(height: 28),
            const Text('Enter your password to authorise this payment', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: _pwCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
                filled: true,
                fillColor: AppTheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Authorise Payment', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                ),
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
      appBar: AppBar(title: const Text('QR Payment'), backgroundColor: AppTheme.primary),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmountCard(amount: amount, method: 'QR', icon: Icons.qr_code_rounded),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  if (qrImageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      child: CachedNetworkImage(
                        imageUrl: qrImageUrl,
                        height: 180,
                        width: 180,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(height: 180, width: 180, child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
                        errorWidget: (context, url, error) => const SizedBox(height: 180, width: 180, child: Icon(Icons.broken_image_rounded, size: 60, color: AppTheme.textTertiary)),
                      ),
                    )
                  else
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.qr_code_rounded, size: 40, color: AppTheme.primary),
                    ),
                  const SizedBox(height: 16),
                  Text(qrLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Send to: $qrId', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('NPR $amount', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.infoBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Text(
                '1. Open your payment app\n2. Send the amount to the ID shown\n3. Show the success screen to your driver',
                style: TextStyle(color: AppTheme.info, height: 1.6, fontSize: 13),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashPayScreen extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _CashPayScreen({required this.booking});

  @override
  Widget build(BuildContext context) {
    final amount = booking['totalAmount'];
    final driver = booking['driver'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Cash Payment'), backgroundColor: AppTheme.primary),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AmountCard(amount: amount, method: 'Cash', icon: Icons.money_rounded),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(color: AppTheme.successBg, shape: BoxShape.circle),
                    child: const Icon(Icons.money_rounded, size: 40, color: AppTheme.success),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pay NPR $amount cash to ${driver['name'] ?? 'your driver'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hand the cash to your driver at the end of the ride. The driver will mark the payment as received.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, height: 1.5, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warningBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.warning),
                  SizedBox(width: 10),
                  Expanded(child: Text('Please prepare exact change if possible.', style: TextStyle(color: AppTheme.warning, fontSize: 13))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cash payment confirmed!'), backgroundColor: AppTheme.success));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error));
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
      appBar: AppBar(title: const Text('Confirm Cash'), backgroundColor: AppTheme.primary),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: AppTheme.successBg, shape: BoxShape.circle),
              child: const Icon(Icons.money_rounded, size: 52, color: AppTheme.success),
            ),
            const SizedBox(height: 24),
            Text(
              'Did you receive NPR $amount cash from ${passenger['name'] ?? 'passenger'}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Yes, Cash Received', style: TextStyle(fontWeight: FontWeight.w800)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                ),
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
  final IconData icon;
  const _AmountCard({required this.amount, required this.method, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Amount Due', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text('NPR $amount', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('via $method', style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}
