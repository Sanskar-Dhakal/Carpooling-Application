import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';
import '../../models/user_model.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Auto-poll Firebase every 5 seconds — user just needs to click the link
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      context.read<AuthBloc>().add(AuthCheckEmailVerifiedRequested());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _go(BuildContext context, UserModel user) {
    _pollTimer?.cancel();
    if (user.isAdmin) {
      Navigator.pushNamedAndRemoveUntil(context, '/admin/home',     (_) => false);
    } else if (user.isDriver && !user.isPassenger) {
      Navigator.pushNamedAndRemoveUntil(context, '/driver/home',    (_) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/passenger/home', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
          title: const Text('Verify Email'),
          automaticallyImplyLeading: false),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthEmailVerified) _go(context, state.user);
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        builder: (context, state) {
          final loading = state is AuthLoading;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: AppTheme.primary, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('Check your inbox',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'A verification link was sent to\n${widget.email}\n\n'
                  'Open the email, tap the link, then return here.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 48),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: loading ? null : () => context
                        .read<AuthBloc>()
                        .add(AuthCheckEmailVerifiedRequested()),
                    child: loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("I've verified my email"),
                  ),
                ),
                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: loading ? null : () => context
                      .read<AuthBloc>()
                      .add(AuthSendEmailVerificationRequested()),
                  child: const Text('Resend verification email'),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Checking automatically every 5 seconds…',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}