import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';

class PassengerHomeScreen extends StatelessWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.user.name : 'Passenger';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vroom Squad'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                  Navigator.pushReplacementNamed(context, '/login');
                },
              )
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.passengerColor, borderRadius: BorderRadius.circular(16)),
                child: Text('Hello, $name\nPassenger Dashboard', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Row(children: [
                _ActionCard(icon: Icons.search_rounded, label: 'Find a Ride', color: AppTheme.passengerColor, onTap: () => Navigator.pushNamed(context, '/rides/search')),
                const SizedBox(width: 12),
                _ActionCard(icon: Icons.bookmark_rounded, label: 'My Bookings', color: AppTheme.primary, onTap: () => Navigator.pushNamed(context, '/bookings/my')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _ActionCard(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', color: AppTheme.warning, onTap: () => Navigator.pushNamed(context, '/wallet')),
                const SizedBox(width: 12),
                _ActionCard(icon: Icons.receipt_long_rounded, label: 'Payments', color: AppTheme.success, onTap: () => Navigator.pushNamed(context, '/bookings/my')),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.borderColor)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );
}
