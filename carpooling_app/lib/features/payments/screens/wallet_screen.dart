import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;
  List<Map<String, dynamic>> _txns = [];
  bool _loading = true;
  Map<String, dynamic>? _adminContact;

  Future<void> _loadAdminContact() async {
    try {
      final data = await ApiService.get('/admin/contact');
      setState(() => _adminContact = data['admin']);
    } catch (_) {}
  }

  Future<void> _callAdmin() async {
    if (_adminContact?['phone'] == null) return;
    final uri = Uri.parse('tel:${_adminContact!['phone']}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _emailAdmin() async {
    if (_adminContact?['email'] == null) return;
    final uri = Uri(
      scheme: 'mailto',
      path: _adminContact!['email'],
      queryParameters: {
        'subject': 'Wallet Support Request',
        'body': 'Hello, I need help with my wallet.'
      },
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadAdminContact();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/payments/wallet');
      setState(() {
        _wallet = data['wallet'] as Map<String, dynamic>?;
        _txns = List<Map<String, dynamic>>.from(data['transactions'] ?? []);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    final ctrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Withdraw Money'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (NPR)',
              prefixIcon: Icon(Icons.money),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Withdraw'),
            ),
          ],
        ),
      );
      if (confirmed == true && ctrl.text.isNotEmpty) {
        try {
          await ApiService.post('/payments/wallet/withdrawals',
              {'amount': double.parse(ctrl.text)});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Withdrawal request submitted. Awaiting admin approval.'),
                backgroundColor: AppTheme.success),
          );
          _load();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()), backgroundColor: AppTheme.error),
          );
        }
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _topUpWallet() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || !authState.user.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please verify your account before topping up your wallet'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Top Up Wallet'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount (NPR)',
            prefixIcon: Icon(Icons.add_card_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.isNotEmpty) {
      try {
        await ApiService.post(
            '/payments/wallet/top-up', {'amount': double.parse(ctrl.text)});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Wallet topped up!'),
              backgroundColor: AppTheme.success),
        );
        _load();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Balance card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Available Balance',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 6),
                          Text(
                            'NPR ${(_wallet?['balance'] ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold),
                          ),
                          if ((_wallet?['reserved'] ?? 0) > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Reserved: NPR ${(_wallet?['reserved'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: _WalletAction(
                            icon: Icons.add_circle_outline,
                            label: 'Top Up',
                            color: AppTheme.success,
                            onTap: _topUpWallet,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _WalletAction(
                            icon: Icons.arrow_circle_up_outlined,
                            label: 'Withdraw',
                            color: AppTheme.warning,
                            onTap: _requestWithdrawal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_adminContact != null)
                      Card(
                        color: AppTheme.adminColor.withOpacity(0.06),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.support_agent_rounded,
                                  color: AppTheme.adminColor, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_adminContact!['name'] ?? 'Admin',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary)),
                                    Text('For wallet support',
                                        style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              if (_adminContact?['phone'] != null)
                                IconButton(
                                  onPressed: _callAdmin,
                                  icon: const Icon(Icons.phone,
                                      color: AppTheme.success),
                                  tooltip: 'Call Admin',
                                ),
                              if (_adminContact?['email'] != null)
                                IconButton(
                                  onPressed: _emailAdmin,
                                  icon: const Icon(Icons.email_outlined,
                                      color: AppTheme.primary),
                                  tooltip: 'Email Admin',
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Transaction history
                    Row(
                      children: [
                        const Text('Transactions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textPrimary)),
                        const Spacer(),
                        Text('${_txns.length} records',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_txns.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        child: const Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48, color: AppTheme.border),
                            SizedBox(height: 8),
                            Text('No transactions yet',
                                style:
                                    TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      )
                    else
                      ..._txns.map((t) => _TxnTile(txn: t)),
                  ],
                ),
              ),
            ),
    );
  }
}

class _WalletAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WalletAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Map<String, dynamic> txn;
  const _TxnTile({required this.txn});

  bool get _isCredit => ['credit', 'release'].contains(txn['type']);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (_isCredit ? AppTheme.success : AppTheme.error)
                  .withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: _isCredit ? AppTheme.success : AppTheme.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn['description'] ?? txn['type'],
                    style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary)),
                Text(
                  txn['type'].toString().replaceAll('_', ' '),
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${_isCredit ? '+' : '-'}NPR ${txn['amount']}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isCredit ? AppTheme.success : AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }
}