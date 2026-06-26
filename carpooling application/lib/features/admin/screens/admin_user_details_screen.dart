import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_user_history_screen.dart';

class AdminUserDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const AdminUserDetailsScreen({super.key, required this.user});

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  late Map<String, dynamic> _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  Future<void> _toggleStatus(String field, bool value) async {
    try {
      await ApiService.put('/admin/users/${_user['id']}/status', {field: value});
      Fluttertoast.showToast(msg: 'Status updated');
      setState(() => _user[field] = value);
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  Future<void> _docReview(String action) async {
    try {
      await ApiService.put('/admin/users/${_user['id']}/doc-review', {'action': action});
      Fluttertoast.showToast(msg: action == 'accept' ? 'User accepted!' : action == 'retake' ? 'Retake requested!' : 'User rejected!');
      setState(() {
        if (action == 'accept') {
          _user['is_verified'] = true;
          _user['verification_status'] = 'verified';
        } else if (action == 'retake') {
          _user['verification_status'] = 'retake';
          _user['id_document_url'] = null;
        } else if (action == 'reject') {
          _user['is_verified'] = false;
          _user['is_blocked'] = false;
          _user['verification_status'] = 'rejected';
        }
      });
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }
  }

  String _processUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final verified = _user['is_verified'] == true;
    final blocked = _user['is_blocked'] == true;
    final redlisted = _user['is_red_listed'] == true;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: AppTheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUserHistoryScreen(user: _user))),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Header Card ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                border: Border.all(color: AppTheme.border),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primary.withOpacity(0.15),
                    backgroundImage: _user['profile_photo_url'] != null
                        ? CachedNetworkImageProvider(_processUrl(_user['profile_photo_url']))
                        : null,
                    child: _user['profile_photo_url'] == null
                        ? Text((_user['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 28, color: AppTheme.primary, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_user['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        Text(_user['email'] ?? '', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          children: [
                            if (verified) _StatusChip('Verified', AppTheme.success),
                            if (blocked) _StatusChip('Blocked', AppTheme.error),
                            if (redlisted && !blocked) _StatusChip('Red Listed', Colors.orange),
                            if (!verified && !blocked && !redlisted) _StatusChip('Pending', AppTheme.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Contact Info ──────────────────────────────────────
            _InfoCard(
              title: 'Contact Info',
              icon: Icons.contact_page_rounded,
              children: [
                _InfoRow('Phone', _user['phone'] ?? 'Not provided'),
                _InfoRow('Role', (_user['role'] ?? '').toString().toUpperCase()),
                _InfoRow('Rating', '${_user['rating'] ?? '0'} Stars'),
              ],
            ),
            const SizedBox(height: 16),

            // ── ID Document ───────────────────────────────────────
            if (_user['id_document_url'] != null) ...[
              const Text('Citizenship / ID Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: CachedNetworkImage(imageUrl: _processUrl(_user['id_document_url']), fit: BoxFit.contain),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: CachedNetworkImage(imageUrl: _processUrl(_user['id_document_url']), height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_user['license_document_url'] != null) ...[
              const Text('Driver License Document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    child: CachedNetworkImage(imageUrl: _processUrl(_user['license_document_url']), fit: BoxFit.contain),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: CachedNetworkImage(imageUrl: _processUrl(_user['license_document_url']), height: 200, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Doc Review Buttons ────────────────────────────────
            if (_user['id_document_url'] != null && !verified) ...[
              const Text('Document Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill))),
                      onPressed: () => _docReview('accept'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retake'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill))),
                      onPressed: () => _docReview('retake'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill))),
                      onPressed: () => _docReview('reject'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Actions ───────────────────────────────────────────
            const Text('Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(redlisted ? Icons.warning : Icons.warning_amber_rounded, size: 18),
                    label: Text(redlisted ? 'Remove Redlist' : 'Add Redlist'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill))),
                    onPressed: () => _toggleStatus('is_red_listed', !redlisted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: Icon(blocked ? Icons.lock_open_rounded : Icons.block_rounded, size: 18),
                    label: Text(blocked ? 'Unblock' : 'Block'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill))),
                    onPressed: () => _toggleStatus('is_blocked', !blocked),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.history_rounded),
                label: const Text('View User Ride History'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUserHistoryScreen(user: _user))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.primary)),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
