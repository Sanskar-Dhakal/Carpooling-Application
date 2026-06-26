import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
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

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Header(user: user, name: name)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: AppButton.primary(
                        label: 'Post a New Ride',
                        icon: Icons.add_road_rounded,
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostRideScreen())),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SectionHeader(title: 'Manage'),
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
                          icon: Icons.inbox_rounded,
                          label: 'Booking Requests',
                          color: AppTheme.driverColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverBookingRequestsScreen())),
                        ),
                        ActionTile(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Earnings & Wallet',
                          color: AppTheme.warning,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                        ),
                        ActionTile(
                          icon: Icons.directions_car_rounded,
                          label: 'My Vehicles',
                          color: AppTheme.accentDark,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VehicleSetupScreen(fromProfile: true))),
                        ),
                        ActionTile(
                          icon: Icons.qr_code_rounded,
                          label: 'QR Payment Setup',
                          color: AppTheme.passengerColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrSetupScreen())),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ActionTile(
                      icon: Icons.person_rounded,
                      label: 'My Profile',
                      color: AppTheme.textSecondary,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                    ),
                    const SizedBox(height: 28),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 44),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3D26), AppTheme.driverColor],
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
              child: photoUrl == null ? const Icon(Icons.drive_eta_rounded, color: Colors.white, size: 26) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Driver Dashboard', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12.5, fontWeight: FontWeight.w500)),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Hi, $name',
                          style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF8BE0A8), size: 17),
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
