import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminRidesScreen extends StatefulWidget {
  const AdminRidesScreen({super.key});

  @override
  State<AdminRidesScreen> createState() => _AdminRidesScreenState();
}

class _AdminRidesScreenState extends State<AdminRidesScreen> {
  List<Map<String, dynamic>> _rides = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.get('/admin/rides');
      setState(() => _rides = List<Map<String, dynamic>>.from(data['rides'] ?? []));
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'completed': return AppTheme.success;
      case 'active': return AppTheme.primary;
      case 'cancelled': return AppTheme.error;
      default: return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('All Platform Rides'),
        backgroundColor: AppTheme.primary,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _rides.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 56, color: AppTheme.textTertiary),
                      const SizedBox(height: 12),
                      const Text('No rides found.', style: TextStyle(color: AppTheme.textSecondary)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rides.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final r = _rides[i];
                      return Container(
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(r['status']).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  ),
                                  child: Text(
                                    r['status']?.toString().toUpperCase() ?? 'UNKNOWN',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: _statusColor(r['status'])),
                                  ),
                                ),
                                Text('NPR ${r['price_per_seat']}/seat', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 16, color: AppTheme.textSecondary),
                                const SizedBox(width: 8),
                                Text('Driver: ${r['driver_name']}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.my_location_rounded, size: 16, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${r['origin_address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: AppTheme.error),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${r['destination_address']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Total Seats: ${r['total_seats']} | Available: ${r['seats_available']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
