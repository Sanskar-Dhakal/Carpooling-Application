import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(AuthLoginRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ));
    }
  }

  void _navigateByRole(BuildContext context, UserModel user) {
    if (user.isAdmin) {
      Navigator.pushReplacementNamed(context, '/admin/home');
    } else if (user.isDriver && !user.isPassenger) {
      Navigator.pushReplacementNamed(context, '/driver/home');
    } else {
      Navigator.pushReplacementNamed(context, '/passenger/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            _navigateByRole(context, state.user);
          } else if (state is AuthError) {
            if (state.verificationStatus != 'rejected' && state.verificationStatus != 'retake') {
              showAppSnackBar(context, state.message, isError: true);
            }
          }
        },
        builder: (context, state) {
          if (state is AuthError && (state.verificationStatus == 'rejected' || state.verificationStatus == 'retake')) {
            return _buildReuploadPrompt(context, state);
          }
          return _buildLoginForm(context, state);
        },
      ),
    );
  }

  Widget _buildReuploadPrompt(BuildContext context, AuthError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: AppTheme.warningBg, shape: BoxShape.circle),
              child: const Icon(Icons.warning_rounded, size: 40, color: AppTheme.warning),
            ),
            const SizedBox(height: AppTheme.space24),
            Text(
              state.message,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.space24),
            AppButton.primary(
              label: 'Reupload Document',
              icon: Icons.upload_file_rounded,
              expand: false,
              onPressed: () async => Navigator.pushNamed(context, '/profile/edit'),
            ),
            const SizedBox(height: AppTheme.space12),
            AppButton.ghost(
              label: 'Logout',
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

  Widget _buildLoginForm(BuildContext context, AuthState state) {
    final loading = state is AuthLoading;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.primary, size: 28),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Welcome back',
                    style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to continue to Vroom Squad',
                    style: TextStyle(color: Colors.white70, fontSize: 14.5),
                  ),
                ],
              ),
            ),

            // Form
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    AppTextField(
                      label: 'Email',
                      hint: 'Enter your email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required';
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Password',
                      hint: 'Enter your password',
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    AppButton.primary(
                      label: 'Sign In',
                      loading: loading,
                      onPressed: loading ? null : _onLogin,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? ", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/register'),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Sign in as', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        _RoleHintCard(icon: Icons.drive_eta_rounded, label: 'Driver', color: AppTheme.driverColor),
                        SizedBox(width: 10),
                        _RoleHintCard(icon: Icons.person_rounded, label: 'Passenger', color: AppTheme.passengerColor),
                        SizedBox(width: 10),
                        _RoleHintCard(icon: Icons.admin_panel_settings_rounded, label: 'Admin', color: AppTheme.adminColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleHintCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RoleHintCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
