import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AdminUserHistoryScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminUserHistoryScreen({super.key, required this.user});

  @override
  State<AdminUserHistoryScreen> createState() => _AdminUserHistoryScreenState();
}

class _AdminUserHistoryScreenState extends State<AdminUserHistoryScreen> {
  List<dynamic> _history = [];
  bool _loading = true;
  String _type = 'bookings';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get('/admin/users/${widget.user['id']}/history');
      if (mounted) {
        setState(() {
          _history = res['history'] ?? [];
          _type = res['type'] ?? 'bookings';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user['name']} History'),
        backgroundColor: AppTheme.adminColor,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No history found.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final item = _history[i];
                    final date = DateTime.tryParse(item['created_at'] ?? item['departure_time'] ?? '')?.toLocal();
                    final dateStr = date != null ? DateFormat('MMM d, yyyy · h:mm a').format(date) : 'Unknown date';

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dateStr, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: item['status'] == 'completed' ? AppTheme.success.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    (item['status'] ?? 'unknown').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: item['status'] == 'completed' ? AppTheme.success : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.trip_origin, color: AppTheme.success, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item['origin_address'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: AppTheme.error, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(item['destination_address'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_type == 'bookings')
                              Text('Amount: NPR ${item['total_amount']}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary))
                            else
                              Text('Seats: ${item['seats_total']} · Price: NPR ${item['price_per_seat']}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
