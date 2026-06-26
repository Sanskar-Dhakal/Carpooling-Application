import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_user_details_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _roleFilter = '';
  final _searchController = TextEditingController();
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final params = _roleFilter.isNotEmpty ? '?role=$_roleFilter' : '';
      final data = await ApiService.get('/admin/users$params');
      setState(() => _users = List<Map<String, dynamic>>.from(data['users'] ?? []));
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filteredBySearch(List<Map<String, dynamic>> list) {
    final q = _searchController.text.toLowerCase();
    if (q.isEmpty) return list;
    return list.where((u) =>
      (u['name'] ?? '').toString().toLowerCase().contains(q) ||
      (u['email'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppTheme.primary,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'New Users'),
            Tab(text: 'Verified'),
            Tab(text: 'Redlisted'),
            Tab(text: 'Blocked'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                    filled: true,
                    fillColor: AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final r in ['', 'driver', 'passenger', 'both', 'admin'])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(r.isEmpty ? 'All Roles' : r),
                            selected: _roleFilter == r,
                            onSelected: (_) { setState(() => _roleFilter = r); _load(); },
                            selectedColor: AppTheme.primary,
                            checkmarkColor: Colors.white,
                            labelStyle: TextStyle(
                              color: _roleFilter == r ? Colors.white : AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _UserList(users: _filteredBySearch(_users.where((u) => u['is_verified'] != true && u['is_blocked'] != true && u['is_red_listed'] != true).toList()), onRefresh: _load),
                      _UserList(users: _filteredBySearch(_users.where((u) => u['is_verified'] == true && u['is_blocked'] != true && u['is_red_listed'] != true).toList()), onRefresh: _load),
                      _UserList(users: _filteredBySearch(_users.where((u) => u['is_red_listed'] == true && u['is_blocked'] != true).toList()), onRefresh: _load),
                      _UserList(users: _filteredBySearch(_users.where((u) => u['is_blocked'] == true).toList()), onRefresh: _load),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _processUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  return url;
}

class _UserList extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final Future<void> Function() onRefresh;
  const _UserList({required this.users, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 56, color: AppTheme.textTertiary),
            const SizedBox(height: 12),
            const Text('No users found in this category.', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: onRefresh,
      child: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final u = users[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primary.withOpacity(0.15),
              backgroundImage: u['profile_photo_url'] != null
                  ? CachedNetworkImageProvider(_processUrl(u['profile_photo_url']))
                  : null,
              child: u['profile_photo_url'] == null
                  ? Text((u['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(u['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${u['email']} · ${u['role']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 4),
                    Text('${u['rating'] ?? '0.0'}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => AdminUserDetailsScreen(user: u))).then((_) => onRefresh());
            },
          );
        },
      ),
    );
  }
}
