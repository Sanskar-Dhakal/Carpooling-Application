import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _passCtrl       = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  String _role          = 'passenger';
  bool _obscurePass     = true;
  bool _obscureConfirm  = true;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(AuthRegisterRequested(
        name:     _nameCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        phone:    _phoneCtrl.text.trim(),
        password: _passCtrl.text,
        role:     _role,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (ctx, state) {
          if (state is AuthAuthenticated) {
            Navigator.pushReplacementNamed(ctx, state.user.homeRoute);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
        builder: (ctx, state) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Role Selector ────────────────────────
                const Text('I want to join as:',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  _RoleCard(
                    icon: Icons.person_rounded,
                    label: 'Passenger',
                    sub: 'Book rides',
                    value: 'passenger',
                    selected: _role == 'passenger',
                    color: AppTheme.passengerColor,
                    onTap: () => setState(() => _role = 'passenger'),
                  ),
                  const SizedBox(width: 10),
                  _RoleCard(
                    icon: Icons.drive_eta_rounded,
                    label: 'Driver',
                    sub: 'Offer rides',
                    value: 'driver',
                    selected: _role == 'driver',
                    color: AppTheme.driverColor,
                    onTap: () => setState(() => _role = 'driver'),
                  ),
                  const SizedBox(width: 10),
                  _RoleCard(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Both',
                    sub: 'Drive & ride',
                    value: 'both',
                    selected: _role == 'both',
                    color: AppTheme.accent,
                    onTap: () => setState(() => _role = 'both'),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── Fields ───────────────────────────────
                _label('Full Name'),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'John Doe',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Name is required';
                    if (v.trim().length < 2) return 'Name too short';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('Email'),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('Phone Number'),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '+1 234 567 8900',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Phone is required';
                    if (v.length < 7) return 'Enter a valid phone number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('Password'),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    hintText: 'Min 6 characters',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePass
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _label('Confirm Password'),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Repeat password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please confirm password';
                    if (v != _passCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: state is AuthLoading ? null : _submit,
                  child: state is AuthLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 18),

                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('Already have an account? ',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Text('Sign In',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppTheme.textPrimary)),
  );
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label, sub, value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon, required this.label, required this.sub,
    required this.value, required this.selected,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : AppTheme.borderColor,
              width: selected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? color : AppTheme.textSecondary, size: 24),
          const SizedBox(height: 5),
          Text(label,
              style: TextStyle(
                  color: selected ? color : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
          Text(sub,
              style: TextStyle(
                  color: selected ? color.withValues(alpha: 0.7) : AppTheme.textSecondary,
                  fontSize: 10)),
        ]),
      ),
    ),
  );
}
