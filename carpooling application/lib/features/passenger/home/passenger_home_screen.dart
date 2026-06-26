import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carpooling_app/core/theme/app_theme.dart';
import 'package:carpooling_app/core/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../../auth/models/user_model.dart';
import '../../bookings/screens/my_bookings_screen.dart';
import '../../payments/screens/wallet_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../rides/screens/find_ride_screen.dart';

class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final name = user?.name ?? 'Passenger';
        final firstName = name.trim().split(' ').first;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async => Future.delayed(const Duration(milliseconds: 600)),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(user: user, name: firstName)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Search bar (overlaps header) ──────────────
                      Transform.translate(
                        offset: const Offset(0, -24),
                        child: _SearchCta(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FindRideScreen()),
                          ),
                        ),
                      ),
                      // ── Quick Actions ─────────────────────────────
                      const SectionHeader(title: 'Quick Actions'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _QuickActionCard(
                            icon: Icons.work_rounded,
                            label: 'Find Ride',
                            color: AppTheme.accent,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindRideScreen())),
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.home_rounded,
                            label: 'My Bookings',
                            color: AppTheme.primary,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _QuickActionCard(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Wallet',
                            color: AppTheme.accent,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                          ),
                          const SizedBox(width: 12),
                          _QuickActionCard(
                            icon: Icons.person_rounded,
                            label: 'Profile',
                            color: AppTheme.primary,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // ── Promo banner ──────────────────────────────
                      _PromoBanner(),
                      const SizedBox(height: 28),
                      // ── Perks ─────────────────────────────────────
                      const SectionHeader(title: 'Why ride with us'),
                      const SizedBox(height: 14),
                      const _PerkRow(
                        icon: Icons.verified_user_rounded,
                        title: 'Verified drivers',
                        subtitle: 'Every driver is ID-checked before approval',
                      ),
                      const SizedBox(height: 10),
                      const _PerkRow(
                        icon: Icons.payments_rounded,
                        title: 'Affordable fares',
                        subtitle: 'Split the cost, save on every trip',
                      ),
                      const SizedBox(height: 10),
                      const _PerkRow(
                        icon: Icons.gps_fixed_rounded,
                        title: 'Live trip tracking',
                        subtitle: 'Know exactly where your ride is',
                      ),
                    ]),
                  ),
                ),
              ],
            ),
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
    final isVerified = user != null && user!.isVerified == true;
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
                child: photoUrl == null ? const Icon(Icons.person_rounded, color: Colors.white, size: 26) : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning, $name',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(
                        'Ready for your commute?',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded, color: Color(0xFF60E0C8), size: 14),
                      ],
                    ],
                  ),
                ],
              ),
            ),
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

// ── Search CTA ────────────────────────────────────────────────────────────────
class _SearchCta extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: AppTheme.primary, size: 22),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Where to?',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textSecondary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: const Icon(Icons.history_rounded, size: 18, color: AppTheme.textSecondary),
              ),
            ],
          ),
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
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Promo Banner ──────────────────────────────────────────────────────────────
class _PromoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const Text('🌿 ECO FRIENDLY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                                const Text(
                  'Go Green with HopON',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Every shared ride means fewer cars\non the road. Save money and help\nthe environment.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: const Text('Ride Now', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const Icon(Icons.directions_car_filled_rounded, color: Colors.white24, size: 80),
        ],
      ),
    );
  }
}

// ── Perk Row ──────────────────────────────────────────────────────────────────
class _PerkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PerkRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.textPrimary)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}
