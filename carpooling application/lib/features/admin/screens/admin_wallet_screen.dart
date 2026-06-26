import 'package:flutter/material.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

class AdminWalletScreen extends StatefulWidget {
  const AdminWalletScreen({super.key});

  @override
  State<AdminWalletScreen> createState() => _AdminWalletScreenState();
}

class _AdminWalletScreenState extends State<AdminWalletScreen> {
  Map<String, dynamic>? _wallet;
  List<dynamic> _transactions = [];
  double _totalEarnings = 0;
  bool _loading = true;
  final _withdrawController = TextEditingController();
  bool _withdrawing = false;

  @override
  void initState() {
    super.initState();
    _fetchWallet();
  }

  @override
  void dispose() {
    _withdrawController.dispose();
    super.dispose();
  }

  Future<void> _fetchWallet() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/admin/wallet');
      if (!mounted) return;
      setState(() {
        _wallet = Map<String, dynamic>.from(data['wallet'] ?? {});
        _transactions = List.from(data['transactions'] ?? []);
        _totalEarnings = (data['totalEarnings'] is num) ? (data['totalEarnings'] as num).toDouble() : 0.0;
      });
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    final amount = double.tryParse(_withdrawController.text.trim());
    if (amount == null || amount <= 0) {
      showAppSnackBar(context, 'Enter a valid amount', isError: true);
      return;
    }
    final balance = (_wallet?['balance'] is num) ? (_wallet!['balance'] as num).toDouble() : 0.0;
    if (amount > balance) {
      showAppSnackBar(context, 'Insufficient balance', isError: true);
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Confirm Withdrawal',
      message: 'Withdraw NPR ${amount.toStringAsFixed(2)} from the platform commission wallet?',
      confirmLabel: 'Withdraw',
    );
    if (!confirmed) return;

    setState(() => _withdrawing = true);
    try {
      await ApiService.post('/admin/wallet/withdraw', {'amount': amount});
      if (!mounted) return;
      showAppSnackBar(context, 'Withdrawal successful');
      _withdrawController.clear();
      _fetchWallet();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  bool _isNegative(String type) => type == 'debit' || type == 'withdrawal_paid' || type == 'withdrawal_request';

  @override
  Widget build(BuildContext context) {
    final balance = (_wallet?['balance'] is num) ? (_wallet!['balance'] as num).toDouble() : (double.tryParse('${_wallet?['balance'] ?? 0}') ?? 0.0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Platform Wallet')),
      body: _loading
          ? const AppLoadingState()
          : RefreshIndicator(
              onRefresh: _fetchWallet,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF8A5A0F), AppTheme.adminColor],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      boxShadow: AppTheme.elevatedShadow,
                    ),
                    child: Column(
                      children: [
                        const Text('Service Charge Balance (15%)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                          'NPR ${balance.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Total Commission Earned: NPR ${_totalEarnings.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Withdraw to Bank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AppTextField(
                                label: '',
                                hint: 'Amount (NPR)',
                                controller: _withdrawController,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.currency_exchange_rounded),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 110,
                              child: AppButton.primary(
                                label: 'Withdraw',
                                size: AppButtonSize.medium,
                                loading: _withdrawing,
                                onPressed: _withdrawing ? null : _requestWithdrawal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SectionHeader(title: 'Transactions'),
                  const SizedBox(height: 14),
                  if (_transactions.isEmpty)
                    const AppEmptyState(icon: Icons.receipt_long_rounded, title: 'No transactions yet')
                  else
                    ..._transactions.map((tx) {
                      final type = (tx['type'] ?? '').toString();
                      final amount = tx['amount'] ?? 0;
                      final desc = (tx['description'] ?? type).toString();
                      final date = (tx['created_at'] ?? '').toString();
                      final isNegative = _isNegative(type);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isNegative ? AppTheme.error : AppTheme.success).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                                ),
                                child: Icon(
                                  isNegative ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: isNegative ? AppTheme.error : AppTheme.success,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(desc, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
                                    const SizedBox(height: 2),
                                    Text(date, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                                  ],
                                ),
                              ),
                              Text(
                                '${isNegative ? '-' : '+'} NPR ${(amount is num ? amount : double.tryParse('$amount') ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: isNegative ? AppTheme.error : AppTheme.success),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
