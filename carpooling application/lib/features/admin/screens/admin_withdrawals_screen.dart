import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Read-only history of withdrawals the *admin themselves* has made from the
/// platform commission wallet (see [AdminWalletScreen] for making a new one).
/// This is distinct from [AdminDriverWithdrawalsScreen], which is where
/// driver/passenger payout *requests* are approved or rejected.
class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key});
  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/admin/wallet/withdrawals');
      final items = List<Map<String, dynamic>>.from(data['withdrawals'] ?? []);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Commission Payout History')),
      body: _loading
          ? const AppLoadingState()
          : _items.isEmpty
              ? AppEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title: 'No payouts yet',
                  subtitle: 'Withdrawals you make from the platform commission wallet will appear here.',
                  actionLabel: 'Refresh',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final w = _items[i];
                      final amount = w['amount'] ?? '';
                      final createdRaw = w['created_at']?.toString();
                      final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
                      final origin = (w['origin_address'] ?? '').toString();
                      final destination = (w['destination_address'] ?? '').toString();

                      return AppCard(
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: AppTheme.warningBg, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                              child: const Icon(Icons.payments_outlined, color: AppTheme.warning, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('NPR $amount', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    created == null ? '' : DateFormat('MMM d, yyyy · h:mm a').format(created),
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary),
                                  ),
                                  if (origin.isNotEmpty && destination.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('$origin → $destination', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                  ],
                                ],
                              ),
                            ),
                            const StatusBadge(label: 'Paid', tone: BadgeTone.success),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
