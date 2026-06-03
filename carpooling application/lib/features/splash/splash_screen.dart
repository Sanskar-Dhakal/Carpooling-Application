import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../auth/bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _fade  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
    _scale = Tween<double>(begin: 0.75, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) context.read<AuthBloc>().add(AuthCheckRequested());
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (ctx, state) {
        if (state is AuthAuthenticated) {
          Navigator.pushReplacementNamed(ctx, state.user.homeRoute);
        } else if (state is AuthUnauthenticated || state is AuthError) {
          Navigator.pushReplacementNamed(ctx, '/login');
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.directions_car_rounded,
                        size: 56, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 24),
                  const Text('Vroom Squad',
                      style: TextStyle(
                          color: Colors.white, fontSize: 32,
                          fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  const Text('Share the ride. Share the cost.',
                      style: TextStyle(color: Colors.white60, fontSize: 14)),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white54, strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
