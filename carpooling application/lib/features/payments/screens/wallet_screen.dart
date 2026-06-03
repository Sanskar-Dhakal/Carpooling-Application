import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../models/wallet_model.dart';
import '../repository/payments_repository.dart';

class WalletScreen extends StatefulWidget {
  final bool driverMode;
  const WalletScreen({super.key, this.driverMode = false});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _repo = PaymentsRepository();
  final _amountCtrl = TextEditingController();
  final _qrIdCtrl = TextEditingController();
  final _qrLabelCtrl = TextEditingController(text: 'Driver QR');
  late Future<({WalletModel wallet, List<WalletTransactionModel> transactions})> _wallet;
  String? _qrImageUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _wallet = _repo.wallet();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _qrIdCtrl.dispose();
    _qrLabelCtrl.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _wallet = _repo.wallet());

  Future<void> _moneyAction({required bool withdrawal}) async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    setState(() => _busy = true);
    try {
      if (withdrawal) {
        await _repo.requestWithdrawal(amount);
      } else {
        await _repo.topUp(amount);
      }
      _amountCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(withdrawal ? 'Withdrawal requested' : 'Wallet topped up')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickQrPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 55);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _qrImageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}');
  }

  Future<void> _saveQr() async {
    if (_qrIdCtrl.text.trim().isEmpty || _qrImageUrl == null) return;
    setState(() => _busy = true);
    try {
      await _repo.saveDriverQr(
        qrPaymentId: _qrIdCtrl.text.trim(),
        qrPaymentLabel: _qrLabelCtrl.text.trim().isEmpty ? 'Driver QR' : _qrLabelCtrl.text.trim(),
        qrPaymentImageUrl: _qrImageUrl!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), backgroundColor: widget.driverMode ? AppTheme.driverColor : AppTheme.primary),
      body: FutureBuilder<({WalletModel wallet, List<WalletTransactionModel> transactions})>(
        future: _wallet,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(wallet: data.wallet),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.driverMode ? 'Withdraw earnings' : 'Add wallet amount', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.payments_rounded), labelText: 'Amount'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : () => _moneyAction(withdrawal: widget.driverMode),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(widget.driverMode ? 'Request Withdrawal' : 'Top Up Wallet'),
                    ),
                  ]),
                ),
              ),
              if (widget.driverMode) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Driver QR', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(controller: _qrLabelCtrl, decoration: const InputDecoration(labelText: 'QR label', prefixIcon: Icon(Icons.badge_rounded))),
                      const SizedBox(height: 10),
                      TextField(controller: _qrIdCtrl, decoration: const InputDecoration(labelText: 'QR payment ID', prefixIcon: Icon(Icons.qr_code_rounded))),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(onPressed: _pickQrPhoto, icon: const Icon(Icons.photo_library_rounded), label: const Text('Choose QR Photo')),
                      if (_qrImageUrl != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(base64Decode(_qrImageUrl!.split(',').last), height: 160, width: 160, fit: BoxFit.cover),
                        ),
                      ],
                      const SizedBox(height: 10),
                      ElevatedButton.icon(onPressed: _busy ? null : _saveQr, icon: const Icon(Icons.save_rounded), label: const Text('Save QR')),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...data.transactions.map((tx) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _txColor(tx.type).withValues(alpha: 0.12),
                        child: Icon(_txIcon(tx.type), color: _txColor(tx.type)),
                      ),
                      title: Text(tx.description.isEmpty ? tx.type : tx.description),
                      subtitle: Text('${tx.type} | ${tx.createdAt.toLocal().toString().substring(0, 16)}'),
                      trailing: Text(tx.amountLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )),
            ],
          );
        },
      ),
    );
  }

  Color _txColor(String type) => switch (type) {
        'credit' => AppTheme.success,
        'debit' => AppTheme.error,
        'reserve' => AppTheme.warning,
        'withdrawal_request' => AppTheme.primaryLight,
        _ => AppTheme.textSecondary,
      };

  IconData _txIcon(String type) => switch (type) {
        'credit' => Icons.add_circle_rounded,
        'debit' => Icons.remove_circle_rounded,
        'reserve' => Icons.lock_rounded,
        'withdrawal_request' => Icons.account_balance_rounded,
        _ => Icons.receipt_rounded,
      };
}

class _BalanceCard extends StatelessWidget {
  final WalletModel wallet;
  const _BalanceCard({required this.wallet});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 34),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Available balance', style: TextStyle(color: Colors.white70)),
            Text(wallet.balanceLabel, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            Text('Reserved ${wallet.reservedLabel}', style: const TextStyle(color: Colors.white70)),
          ]),
        ]),
      );
}
