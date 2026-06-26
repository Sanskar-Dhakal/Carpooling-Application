import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.get(
        widget.userId == null ? '/users/me' : '/users/${widget.userId}/profile',
      );
      setState(() => _profile = data['user']);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (_loading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          );
        }

        final user = _profile;
        final name = user?['name'];
        final nameText =
            (name != null && name.trim().isNotEmpty) ? name.trim() : 'User';
        final email = user?['email'] ?? '';
        final phone = user?['phone'] ?? '';
        final rating = (user?['rating'] is num)
            ? (user?['rating'] as num).toDouble()
            : double.tryParse(user?['rating'].toString() ?? '0') ?? 0.0;
        final verified = user?['is_verified'] == true;
        final photoUrl = user?['profile_photo_url'];
        final role = user?['role'] ?? 'passenger';
        final totalRidesDriver = user?['total_rides_driver'] ?? 0;
        final totalRidesPassenger = user?['total_rides_passenger'] ?? 0;
        final isPublicProfile = widget.userId != null;
        final isBlocked = user?['is_blocked'] == true;
        final isRedListed = user?['is_red_listed'] == true;

        String processUrl(String? url) {
          if (url == null || url.isEmpty) return '';
          return url;
        }

        Color statusColor = AppTheme.success;
        IconData statusIcon = Icons.verified_rounded;
        String statusLabel = 'Verified';
        if (isBlocked) {
          statusColor = AppTheme.error;
          statusIcon = Icons.block_rounded;
          statusLabel = 'Blocked';
        } else if (isRedListed) {
          statusColor = Colors.orange;
          statusIcon = Icons.warning_amber_rounded;
          statusLabel = 'Red Listed';
        } else if (!verified) {
          statusColor = AppTheme.textTertiary;
          statusIcon = Icons.pending_outlined;
          statusLabel = 'Not Verified';
        }

        Color roleColor;
        switch (role) {
          case 'driver':
            roleColor = AppTheme.driverColor;
            break;
          case 'admin':
            roleColor = AppTheme.adminColor;
            break;
          default:
            roleColor = AppTheme.passengerColor;
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: RefreshIndicator(
            onRefresh: _load,
            color: AppTheme.accent,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Hero Header ─────────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  leading: Navigator.canPop(context)
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18),
                          onPressed: () => Navigator.pop(context),
                        )
                      : null,
                  actions: isPublicProfile
                      ? null
                      : [
                          IconButton(
                            icon: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: const Icon(Icons.settings_outlined,
                                  size: 18, color: Colors.white),
                            ),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.primary, AppTheme.primaryLight],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Decorative circles
                          Positioned(
                            top: -40,
                            right: -40,
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.04),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 20,
                            left: -30,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accent.withOpacity(0.08),
                              ),
                            ),
                          ),
                          SafeArea(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 24),
                                // Avatar with glow
                                Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white.withOpacity(0.25),
                                            width: 3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                        color: Colors.white.withOpacity(0.12),
                                      ),
                                      child: ClipOval(
                                        child: photoUrl != null &&
                                                photoUrl.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: processUrl(photoUrl),
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _avatarFallback(nameText),
                                              )
                                            : _avatarFallback(nameText),
                                      ),
                                    ),
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: statusColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: AppTheme.primary, width: 2.5),
                                        boxShadow: [
                                          BoxShadow(
                                            color: statusColor.withOpacity(0.3),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Icon(statusIcon,
                                          color: Colors.white, size: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  nameText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _rolePill(role, roleColor),
                                    const SizedBox(width: 8),
                                    _ratingPill(rating),
                                    const SizedBox(width: 8),
                                    _statusPill(statusLabel, statusColor),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Stats Row ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Row(
                      children: [
                        _statCard(
                          icon: Icons.drive_eta_rounded,
                          label: 'Rides Given',
                          value: totalRidesDriver.toString(),
                          color: AppTheme.driverColor,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          icon: Icons.person_outline_rounded,
                          label: 'Rides Taken',
                          value: totalRidesPassenger.toString(),
                          color: AppTheme.passengerColor,
                        ),
                        const SizedBox(width: 12),
                        _statCard(
                          icon: Icons.star_rounded,
                          label: 'Rating',
                          value: rating.toStringAsFixed(1),
                          color: AppTheme.warning,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Contact Card ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _sectionCard(
                      title: 'Contact Info',
                      icon: Icons.contact_page_outlined,
                      children: [
                        _infoRow(
                          icon: Icons.email_outlined,
                          label: 'Email',
                          value: email.isEmpty ? 'Not set' : email,
                        ),
                        _divider(),
                        _infoRow(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: phone.isEmpty ? 'Not set' : phone,
                        ),
                        _divider(),
                        _infoRow(
                          icon: statusIcon,
                          label: 'Account Status',
                          value: statusLabel,
                          valueColor: statusColor,
                          valueBg: statusColor.withOpacity(0.08),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Edit Button ────────────────────────────────────────
                if (!isPublicProfile)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const EditProfileScreen()),
                          );
                          _load();
                        },
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 36)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppTheme.accent.withOpacity(0.3),
      child: Center(
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
              fontSize: 38, color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _rolePill(String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _ratingPill(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.warning, size: 13),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10.5, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textTertiary,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    Color? valueBg,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Icon(icon, size: 18, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppTheme.textTertiary)),
              const SizedBox(height: 3),
              valueBg != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: valueBg,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusPill),
                      ),
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: valueColor ?? AppTheme.textPrimary,
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? AppTheme.textPrimary,
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, color: AppTheme.divider),
      );
}
