import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';

/// Lets the admin review *driver/passenger withdrawal requests* and either
/// pay them out (after sending money externally) or reject them, which
/// releases the reserved funds back to the user's spendable balance.
///
/// This closes a gap that previously existed in the app: a withdrawal
/// request endpoint existed on the backend (`GET /payments/admin/withdrawals`)
/// but nothing in the app ever called it, and there was no way to actually
/// approve/reject a request once made — the money just sat in `reserved`
/// forever. Both gaps are fixed: the new `complete` / `reject` endpoints are
/// called from here.
class AdminDriverWithdrawalsScreen extends StatefulWidget {
  const AdminDriverWithdrawalsScreen({super.key});

  @override
  State<AdminDriverWithdrawalsScreen> createState() => _AdminDriverWithdrawalsScreenState();
}

class _AdminDriverWithdrawalsScreenState extends State<AdminDriverWithdrawalsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/payments/admin/withdrawals');
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

  List<Map<String, dynamic>> get _pending => _items.where((w) => w['status'] == 'pending').toList();
  List<Map<String, dynamic>> get _resolved => _items.where((w) => w['status'] != 'pending').toList();

  Future<void> _approve(Map<String, dynamic> item) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Mark as Paid',
      message: 'Confirm that you have sent NPR ${item['amount']} to ${item['userName'] ?? 'this user'} outside the app before marking this complete.',
      confirmLabel: 'Mark Paid',
    );
    if (!confirmed) return;
    await _act(item, isApprove: true);
  }

  Future<void> _reject(Map<String, dynamic> item) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: 'Reject Request',
      message: 'NPR ${item['amount']} will be released back into ${item['userName'] ?? "the user's"} wallet balance.',
      confirmLabel: 'Reject',
      isDanger: true,
    );
    if (!confirmed) return;
    await _act(item, isApprove: false);
  }

  Future<void> _act(Map<String, dynamic> item, {required bool isApprove}) async {
    final id = item['id'].toString();
    setState(() => _busyId = id);
    try {
      if (isApprove) {
        await ApiService.put('/payments/admin/withdrawals/$id/complete', const {});
      } else {
        await ApiService.put('/payments/admin/withdrawals/$id/reject', const {});
      }
      if (!mounted) return;
      showAppSnackBar(context, isApprove ? 'Marked as paid' : 'Request rejected');
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Withdrawal Requests')),
      body: _loading
          ? const AppLoadingState()
          : _items.isEmpty
              ? AppEmptyState(
                  icon: Icons.payments_outlined,
                  title: 'No withdrawal requests',
                  subtitle: 'Driver and passenger payout requests will show up here for review.',
                  actionLabel: 'Refresh',
                  onAction: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_pending.isNotEmpty) ...[
                        SectionHeader(title: 'Pending (${_pending.length})'),
                        const SizedBox(height: 12),
                        for (final item in _pending) ...[
                          _WithdrawalCard(
                            item: item,
                            busy: _busyId == item['id'].toString(),
                            onApprove: () => _approve(item),
                            onReject: () => _reject(item),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 12),
                      ],
                      if (_resolved.isNotEmpty) ...[
                        SectionHeader(title: 'History'),
                        const SizedBox(height: 12),
                        for (final item in _resolved) ...[
                          _WithdrawalCard(item: item, busy: false),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _WithdrawalCard({required this.item, required this.busy, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    final status = (item['status'] ?? 'pending').toString();
    final amount = item['amount'];
    final createdRaw = item['createdAt']?.toString();
    final created = createdRaw == null ? null : DateTime.tryParse(createdRaw)?.toLocal();
    final isPending = status == 'pending';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.warning.withOpacity(0.12),
                child: const Icon(Icons.person_rounded, color: AppTheme.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['userName']?.toString() ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
                    if (item['userEmail'] != null)
                      Text(item['userEmail'].toString(), style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary)),
                  ],
                ),
              ),
              StatusBadge.fromStatus(status),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NPR $amount', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textPrimary)),
                if (created != null)
                  Text(DateFormat('MMM d, h:mm a').format(created), style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary)),
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AppButton.outline(
                    label: 'Reject',
                    size: AppButtonSize.medium,
                    loading: busy,
                    onPressed: busy ? null : onReject,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton.primary(
                    label: 'Mark Paid',
                    size: AppButtonSize.medium,
                    loading: busy,
                    onPressed: busy ? null : onApprove,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
