import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';

class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (ctx, state) {
        final name = state is AuthAuthenticated ? state.user.name : 'Driver';
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.driverColor,
            title: const Text('Vroom Squad'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  ctx.read<AuthBloc>().add(AuthLogoutRequested());
                  Navigator.pushReplacementNamed(ctx, '/login');
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome
                _WelcomeCard(
                  name: name,
                  role: 'Driver',
                  color: AppTheme.driverColor,
                  icon: Icons.drive_eta_rounded,
                ),
                const SizedBox(height: 24),

                const Text('Quick Actions',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),

                Row(children: [
                  _ActionCard(icon: Icons.add_road_rounded,   label: 'Post a Ride',  color: AppTheme.driverColor,   onTap: () => Navigator.pushNamed(context, '/rides/post')),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.list_alt_rounded,   label: 'My Rides',     color: AppTheme.primary,       onTap: () => Navigator.pushNamed(context, '/rides/my')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.account_balance_wallet_rounded, label: 'Wallet',  color: AppTheme.warning, onTap: () => Navigator.pushNamed(context, '/wallet/driver')),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.person_rounded,     label: 'Profile',      color: AppTheme.accent,        onTap: () {}),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.fact_check_rounded, label: 'Requests', color: AppTheme.primaryLight, onTap: () => Navigator.pushNamed(context, '/bookings/driver')),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.star_outline_rounded, label: 'Reviews',    color: AppTheme.warning,       onTap: () {}),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Passenger Home ────────────────────────────────────────
class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (ctx, state) {
        final name = state is AuthAuthenticated ? state.user.name : 'Passenger';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vroom Squad'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  ctx.read<AuthBloc>().add(AuthLogoutRequested());
                  Navigator.pushReplacementNamed(ctx, '/login');
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeCard(
                  name: name,
                  role: 'Passenger',
                  color: AppTheme.passengerColor,
                  icon: Icons.person_rounded,
                ),
                const SizedBox(height: 24),
                const Text('Quick Actions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.search_rounded,       label: 'Find a Ride',   color: AppTheme.passengerColor, onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.bookmark_rounded,     label: 'My Bookings',   color: AppTheme.primary,        onTap: () {}),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', color: AppTheme.warning, onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.person_rounded,       label: 'Profile',       color: AppTheme.accent,         onTap: () {}),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.chat_bubble_outline_rounded, label: 'Messages', color: AppTheme.primaryLight, onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.star_outline_rounded, label: 'Reviews',       color: AppTheme.warning,        onTap: () {}),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Admin Home ────────────────────────────────────────────
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (ctx, state) {
        final name = state is AuthAuthenticated ? state.user.name : 'Admin';
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.adminColor,
            title: const Text('Admin Panel'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  ctx.read<AuthBloc>().add(AuthLogoutRequested());
                  Navigator.pushReplacementNamed(ctx, '/login');
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WelcomeCard(
                  name: name,
                  role: 'Admin',
                  color: AppTheme.adminColor,
                  icon: Icons.admin_panel_settings_rounded,
                ),
                const SizedBox(height: 24),
                const Text('Admin Actions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.people_rounded,           label: 'Users',       color: AppTheme.adminColor,    onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.account_balance_wallet_rounded, label: 'Wallet Credits', color: AppTheme.success, onTap: () {}),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.payment_rounded,          label: 'Withdrawals', color: AppTheme.warning,        onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.report_problem_rounded,   label: 'Disputes',    color: AppTheme.error,          onTap: () {}),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _ActionCard(icon: Icons.directions_car_rounded,   label: 'All Rides',   color: AppTheme.primary,        onTap: () {}),
                  const SizedBox(width: 12),
                  _ActionCard(icon: Icons.verified_user_rounded,    label: 'Verify IDs',  color: AppTheme.primaryLight,   onTap: () {}),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────
class _WelcomeCard extends StatelessWidget {
  final String name, role;
  final Color color;
  final IconData icon;
  const _WelcomeCard({required this.name, required this.role, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: Colors.white24,
        child: Icon(icon, color: Colors.white, size: 30),
      ),
      const SizedBox(width: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hello, $name 👋',
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        Text('$role Dashboard',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    ]),
  );
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimary)),
        ]),
      ),
    ),
  );
}
