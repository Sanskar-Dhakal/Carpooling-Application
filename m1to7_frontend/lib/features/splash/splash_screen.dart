import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_theme.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../auth/bloc/auth_state.dart';
import '../auth/models/user_model.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _taglineSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _scaleAnim = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.7, curve: Curves.easeOutBack)),
    );
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1, curve: Curves.easeOut)),
    );
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) context.read<AuthBloc>().add(AuthCheckRequested());
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _navigateByRole(BuildContext context, UserModel user) {
    if (user.isAdmin) Navigator.pushReplacementNamed(context, '/admin/home');
    else if (user.isDriver && !user.isPassenger) Navigator.pushReplacementNamed(context, '/driver/home');
    else Navigator.pushReplacementNamed(context, '/passenger/home');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) _navigateByRole(context, state.user);
        else if (state is AuthUnauthenticated || state is AuthError) Navigator.pushReplacementNamed(context, '/login');
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryDark, AppTheme.primary, AppTheme.primaryLight],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Decorative background icons
                Positioned(
                  right: -60,
                  top: 80,
                  child: Icon(Icons.alt_route_rounded, size: 220, color: Colors.white.withOpacity(0.05)),
                ),
                Positioned(
                  left: -40,
                  bottom: 60,
                  child: Icon(Icons.location_on_rounded, size: 160, color: Colors.white.withOpacity(0.05)),
                ),
                Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 12)),
                              ],
                            ),
                            child: const Icon(Icons.directions_car_filled_rounded, size: 54, color: AppTheme.primary),
                          ),
                          const SizedBox(height: 28),
                          // App name
                          const Text(
                            'HopON',
                            style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                          ),
                          const SizedBox(height: 10),
                          // Tagline pill
                          SlideTransition(
                            position: _taglineSlide,
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  border: Border.all(color: AppTheme.accent.withOpacity(0.5)),
                                ),
                                child: const Text(
                                  'Share the ride · Share the cost',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Loading indicator
                Positioned(
                  bottom: 48,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: const Center(
                      child: SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          strokeWidth: 2.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
