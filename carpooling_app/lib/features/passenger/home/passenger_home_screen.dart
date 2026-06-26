import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
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
            color: AppTheme.passengerColor,
            onRefresh: () async => Future.delayed(const Duration(milliseconds: 600)),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _Header(user: user, name: firstName)),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Search CTA — the primary action for a passenger.
                      _SearchCta(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FindRideScreen()),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const SectionHeader(title: 'Quick Actions'),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          ActionTile(
                            icon: Icons.search_rounded,
                            label: 'Find a Ride',
                            color: AppTheme.passengerColor,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindRideScreen())),
                          ),
                          ActionTile(
                            icon: Icons.bookmark_rounded,
                            label: 'My Bookings',
                            color: AppTheme.driverColor,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
                          ),
                          ActionTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Wallet',
                            color: AppTheme.warning,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                          ),
                          ActionTile(
                            icon: Icons.person_rounded,
                            label: 'Profile',
                            color: AppTheme.accentDark,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
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

class _Header extends StatelessWidget {
  final UserModel? user;
  final String name;
  const _Header({required this.user, required this.name});

  @override
  Widget build(BuildContext context) {
    final isVerified = user != null && user!.isVerified == true;
    final rating = user != null ? user!.rating : 0.0;
    final photoUrl = user?.profilePhotoUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.passengerColor],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white24,
              backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
              child: photoUrl == null ? const Icon(Icons.person_rounded, color: Colors.white, size: 28) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good day,', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12.5, fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF60E0C8), size: 17),
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
                    const Icon(Icons.star_rounded, color: AppTheme.warning, size: 15),
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

class _SearchCta extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -36),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppTheme.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                  child: const Icon(Icons.search_rounded, color: AppTheme.accentDark, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Where are you headed?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.textPrimary)),
                      SizedBox(height: 2),
                      Text('Search rides near you', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppTheme.background, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: AppTheme.successBg, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          child: Icon(icon, color: AppTheme.success, size: 20),
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
