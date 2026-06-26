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

  @override
  void initState() { super.initState(); _load(); _loadAdminContact(); }

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
    final uri = Uri(scheme: 'mailto', path: _adminContact!['email'],
      queryParameters: {'subject': 'Wallet Support Request', 'body': 'Hello, I need help with my wallet.'});
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _requestWithdrawal() async {
    final ctrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
          title: const Text('Withdraw Money', style: TextStyle(fontWeight: FontWeight.w800)),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Amount (NPR)',
              prefixIcon: const Icon(Icons.money_rounded),
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill))),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Withdraw'),
            ),
          ],
        ),
      );
      if (confirmed == true && ctrl.text.isNotEmpty) {
        try {
          await ApiService.post('/payments/wallet/withdrawals', {'amount': double.parse(ctrl.text)});
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Withdrawal request submitted!'), backgroundColor: AppTheme.success),
          );
          _load();
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
          );
        }
      }
    } finally { ctrl.dispose(); }
  }

  Future<void> _topUpWallet() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated || !authState.user.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your account before topping up'), backgroundColor: AppTheme.warning),
      );
      return;
    }
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
        title: const Text('Top Up Wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Amount (NPR)',
            prefixIcon: const Icon(Icons.add_card_rounded),
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Top Up'),
          ),
        ],
      ),
    );
    if (confirmed == true && ctrl.text.isNotEmpty) {
      try {
        await ApiService.post('/payments/wallet/top-up', {'amount': double.parse(ctrl.text)});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet topped up! 🎉'), backgroundColor: AppTheme.success),
        );
        _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Teal Header with Balance ──────────────────────
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryDark, AppTheme.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(32),
                          bottomRight: Radius.circular(32),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                const Text('My Wallet', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                                  onPressed: _load,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('Available Balance', style: TextStyle(color: Colors.white60, fontSize: 13)),
                            const SizedBox(height: 6),
                            Text(
                              'NPR ${(_wallet?['balance'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
                            ),
                            if ((_wallet?['reserved'] ?? 0) > 0) ...[
                              const SizedBox(height: 6),
                              Text('Reserved: NPR ${(_wallet?['reserved'] ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // ── Action Buttons ────────────────────────────
                        Transform.translate(
                          offset: const Offset(0, -24),
                          child: Row(
                            children: [
                              Expanded(
                                child: _WalletActionBtn(
                                  icon: Icons.add_circle_rounded,
                                  label: 'Top Up',
                                  color: AppTheme.success,
                                  onTap: _topUpWallet,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _WalletActionBtn(
                                  icon: Icons.arrow_circle_up_rounded,
                                  label: 'Withdraw',
                                  color: AppTheme.accent,
                                  onTap: _requestWithdrawal,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Admin Contact ─────────────────────────────
                        if (_adminContact != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.15), shape: BoxShape.circle),
                                  child: const Icon(Icons.support_agent_rounded, color: AppTheme.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_adminContact!['name'] ?? 'Admin', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                      const Text('For wallet support', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                if (_adminContact?['phone'] != null)
                                  IconButton(onPressed: _callAdmin, icon: const Icon(Icons.phone_rounded, color: AppTheme.success)),
                                if (_adminContact?['email'] != null)
                                  IconButton(onPressed: _emailAdmin, icon: const Icon(Icons.email_rounded, color: AppTheme.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── Transactions ──────────────────────────────
                        Row(
                          children: [
                            const Text('Transactions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                            const Spacer(),
                            Text('${_txns.length} records', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_txns.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textTertiary),
                                SizedBox(height: 8),
                                Text('No transactions yet', style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          )
                        else
                          ..._txns.map((t) => _TxnTile(txn: t)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _WalletActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _WalletActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (_isCredit ? AppTheme.success : AppTheme.error).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: _isCredit ? AppTheme.success : AppTheme.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn['description'] ?? txn['type'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                Text(txn['type'].toString().replaceAll('_', ' '), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text(
            '${_isCredit ? '+' : '-'}NPR ${txn['amount']}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _isCredit ? AppTheme.success : AppTheme.error),
          ),
        ],
      ),
    );
  }
}
