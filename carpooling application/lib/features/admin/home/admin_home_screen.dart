import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import '../../auth/bloc/auth_state.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final name = state is AuthAuthenticated ? state.user.name : 'Admin';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Panel'),
            backgroundColor: AppTheme.adminColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                onPressed: () {
                  context.read<AuthBloc>().add(AuthLogoutRequested());
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppTheme.adminColor, borderRadius: BorderRadius.circular(16)),
                child: Text('Hello, $name\nAdmin Dashboard', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.success),
                      title: const Text('Wallet Credits'),
                      onTap: () => Navigator.pushNamed(context, '/payments/admin'),
                    ),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}
