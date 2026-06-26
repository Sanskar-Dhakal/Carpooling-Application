import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';
import '../screens/admin_users_screen.dart';
import '../screens/admin_withdrawals_screen.dart';
import '../screens/admin_driver_withdrawals_screen.dart';
import '../screens/admin_wallet_screen.dart';
import '../screens/admin_rides_screen.dart';
import '../screens/admin_disputes_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.user.name : 'Admin';
        final firstName = name.trim().split(' ').first;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(
            slivers: [
              // ── Teal Header ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
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
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Hi, $firstName 👋', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                              Text('Admin Control Center', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12.5)),
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
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Operations Grid ───────────────────────────
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Operations'),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _AdminActionCard(
                                icon: Icons.people_alt_rounded,
                                label: 'Manage\nUsers',
                                color: AppTheme.primary,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
                              ),
                              const SizedBox(width: 12),
                              _AdminActionCard(
                                icon: Icons.alt_route_rounded,
                                label: 'All\nRides',
                                color: AppTheme.accent,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRidesScreen())),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _AdminActionCard(
                                icon: Icons.account_balance_wallet_rounded,
                                label: 'Platform\nWallet',
                                color: AppTheme.primary,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWalletScreen())),
                              ),
                              const SizedBox(width: 12),
                              _AdminActionCard(
                                icon: Icons.payments_rounded,
                                label: 'Withdrawal\nRequests',
                                color: AppTheme.accent,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDriverWithdrawalsScreen())),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDisputesScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.errorBg,
                                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                border: Border.all(color: AppTheme.error.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                    child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Disputes & Reports', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.textTertiary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // ── System ───────────────────────────────
                          const SectionHeader(title: 'System'),
                          const SizedBox(height: 14),
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _SystemTile(
                                  icon: Icons.people_alt_rounded,
                                  label: 'User Verifications',
                                  subtitle: 'Review pending driver & passenger ID documents',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
                                ),
                                const Divider(height: 1),
                                _SystemTile(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Driver Withdrawal Requests',
                                  subtitle: 'Approve or reject driver payout requests',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDriverWithdrawalsScreen())),
                                ),
                                const Divider(height: 1),
                                _SystemTile(
                                  icon: Icons.receipt_long_rounded,
                                  label: 'Commission Payout History',
                                  subtitle: 'Your own platform-commission withdrawals',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWithdrawalsScreen())),
                                  isLast: true,
                                ),
                              ],
                            ),
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

class _AdminActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionCard({required this.icon, required this.label, required this.color, required this.onTap});

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

class _SystemTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _SystemTile({required this.icon, required this.label, required this.subtitle, required this.onTap, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary),
    );
  }
}
