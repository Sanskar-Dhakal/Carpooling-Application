import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/wallet_model.dart';
import '../repository/payments_repository.dart';

class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  final _repo = PaymentsRepository();
  final _emailCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController(text: 'Admin wallet credit');
  late Future<List<WalletTransactionModel>> _withdrawals;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _withdrawals = _repo.withdrawalRequests();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _credit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (_emailCtrl.text.trim().isEmpty || amount == null || amount <= 0) return;
    setState(() => _busy = true);
    try {
      await _repo.adminCreditWallet(email: _emailCtrl.text.trim(), amount: amount, description: _descCtrl.text.trim());
      _amountCtrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet credited')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Payment Admin'), backgroundColor: AppTheme.adminColor),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Credit Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'User email', prefixIcon: Icon(Icons.email_rounded))),
                  const SizedBox(height: 10),
                  TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.payments_rounded))),
                  const SizedBox(height: 10),
                  TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_rounded))),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(onPressed: _busy ? null : _credit, icon: const Icon(Icons.add_circle_rounded), label: const Text('Credit Wallet')),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Withdrawal Requests', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<List<WalletTransactionModel>>(
              future: _withdrawals,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Text(snapshot.error.toString().replaceFirst('Exception: ', ''));
                final withdrawals = snapshot.data!;
                if (withdrawals.isEmpty) return const Card(child: ListTile(title: Text('No withdrawal requests')));
                return Column(
                  children: withdrawals
                      .map((tx) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.account_balance_rounded, color: AppTheme.warning),
                              title: Text('${tx.userName ?? 'Driver'} | ${tx.amountLabel}'),
                              subtitle: Text('${tx.userEmail ?? ''}\n${tx.createdAt.toLocal().toString().substring(0, 16)}'),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      );
}
