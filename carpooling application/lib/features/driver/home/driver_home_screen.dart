import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carpooling_app/core/theme/app_theme.dart';
import 'package:carpooling_app/core/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../../vehicles/screens/vehicle_setup_screen.dart';
import '../../bookings/screens/driver_booking_requests_screen.dart';
import '../../payments/screens/wallet_screen.dart';
import '../../payments/screens/qr_setup_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../rides/screens/post_ride_screen.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final rawName = user?.name.trim() ?? '';
        final name = rawName.isNotEmpty ? rawName : 'Driver';
        final firstName = name.split(' ').first;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(user: user, name: firstName)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Post Ride CTA (overlaps header) ───────────
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRideScreen())),
                          icon: const Icon(Icons.add_road_rounded),
                          label: const Text('Post a New Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                            elevation: 4,
                            shadowColor: AppTheme.accent.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                    // ── Manage Grid ───────────────────────────────
                    const SectionHeader(title: 'Manage'),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _QuickActionCard(
                          icon: Icons.inbox_rounded,
                          label: 'Booking\nRequests',
                          color: AppTheme.primary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverBookingRequestsScreen())),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Earnings\n& Wallet',
                          color: AppTheme.accent,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _QuickActionCard(
                          icon: Icons.directions_car_rounded,
                          label: 'My\nVehicles',
                          color: AppTheme.primary,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleSetupScreen(fromProfile: true))),
                        ),
                        const SizedBox(width: 12),
                        _QuickActionCard(
                          icon: Icons.qr_code_rounded,
                          label: 'QR Payment\nSetup',
                          color: AppTheme.accent,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrSetupScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Profile tile
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                                color: AppTheme.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.person_rounded, color: AppTheme.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text('My Profile', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textTertiary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // ── Driver Status ─────────────────────────────
                    const SectionHeader(title: 'Driver Status'),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Column(
                        children: [
                          _StatusLine(
                            icon: Icons.verified_user_rounded,
                            label: 'Identity verification',
                            tone: (user?.isVerified ?? false) ? BadgeTone.success : BadgeTone.warning,
                            statusLabel: (user?.isVerified ?? false) ? 'Verified' : 'Pending',
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Divider(height: 1),
                          ),
                          _StatusLine(
                            icon: Icons.star_rounded,
                            label: 'Passenger rating',
                            tone: BadgeTone.info,
                            statusLabel: user != null && user.rating > 0 ? '${user.rating.toStringAsFixed(1)} / 5.0' : 'No ratings yet',
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final UserModel? user;
  final String name;
  const _Header({required this.user, required this.name});

  @override
  Widget build(BuildContext context) {
    final isVerified = user?.isVerified ?? false;
    final rating = user?.rating ?? 0.0;
    final photoUrl = user?.profilePhotoUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.drive_eta_rounded, color: Colors.white, size: 26) : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, $name 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text('Driver Dashboard', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5)),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: Color(0xFF8BE0A8), size: 14),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (rating > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.14), borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.accent, size: 15),
                    const SizedBox(width: 4),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 21),
              onPressed: () {
                context.read<AuthBloc>().add(AuthLogoutRequested());
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick Action Card ─────────────────────────────────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status Line ───────────────────────────────────────────────────────────────
class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String statusLabel;
  final BadgeTone tone;

  const _StatusLine({required this.icon, required this.label, required this.statusLabel, required this.tone});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
        StatusBadge(label: statusLabel, tone: tone),
      ],
    );
  }
}
