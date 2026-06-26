import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminDisputesScreen extends StatefulWidget {
  const AdminDisputesScreen({super.key});
  @override
  State<AdminDisputesScreen> createState() => _AdminDisputesScreenState();
}

class _AdminDisputesScreenState extends State<AdminDisputesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/admin/disputes');
      setState(() => _items = List<Map<String, dynamic>>.from(data['disputes'] ?? []));
    } catch (e) { Fluttertoast.showToast(msg: e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _resolve(String id, String resolution) async {
    try {
      await ApiService.put('/admin/disputes/$id/resolve', {'resolution': resolution});
      Fluttertoast.showToast(msg: 'Dispute resolved');
      _load();
    } catch (e) { Fluttertoast.showToast(msg: e.toString()); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Disputes & Reports'),
        backgroundColor: AppTheme.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.gavel_rounded, size: 56, color: AppTheme.textTertiary),
                      const SizedBox(height: 12),
                      const Text('No disputes found', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final d = _items[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: AppTheme.errorBg, shape: BoxShape.circle),
                                child: const Icon(Icons.gavel_rounded, color: AppTheme.error, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${d['origin_address']} → ${d['destination_address']}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text('Driver: ${d['driver_name']} · Passenger: ${d['passenger_name']}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                          Text('Amount: NPR ${d['total_amount']} · Method: ${d['payment_method']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    side: const BorderSide(color: AppTheme.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                                  ),
                                  onPressed: () => _resolve(d['id'], 'settled'),
                                  child: const Text('Settle'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.error,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                                  ),
                                  onPressed: () => _resolve(d['id'], 'refunded'),
                                  child: const Text('Refund'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
