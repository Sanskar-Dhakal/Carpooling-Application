import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/countries.dart' as phone_countries;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';
import '../../../core/constants/country_data.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../models/user_model.dart';
import 'verification/phone_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'passenger';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  XFile? _document;

  // Set by IntlPhoneField callbacks
  String _barePhone = ''; // digits only, no dial code
  String _fullPhone = ''; // includes dial code e.g. "+9779841234567"
  CountryInfo _selectedCountry = kDefaultCountry;
  final _nepalPhoneCountries = phone_countries.countries
      .where((country) => country.code == 'NP')
      .toList();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;
    if (!_isValidNepalMobile(_barePhone)) {
      showAppSnackBar(context, 'Please enter a valid Nepal mobile number', isError: true);
      return;
    }
    if (_document == null) {
      showAppSnackBar(context, 'Please upload an ID document for admin verification', isError: true);
      return;
    }
    context.read<AuthBloc>().add(AuthRegisterRequested(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _barePhone,
          password: _passwordController.text,
          role: _selectedRole,
          country: _selectedCountry,
          document: _document!,
        ));
  }

  bool _isValidNepalMobile(String phone) {
    return RegExp(r'^(97|98)\d{8}$').hasMatch(phone);
  }

  Future<void> _pickDocument() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _document = picked);
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
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthPhoneOtpSent) {
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhoneOtpScreen(
                    maskedPhone: state.maskedPhone,
                    fullPhone: _fullPhone,
                  ),
                ));
          } else if (state is AuthEmailVerified) {
            _navigateByRole(context, state.user);
          } else if (state is AuthRegistrationSubmitted) {
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                icon: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: AppTheme.successBg, shape: BoxShape.circle),
                  child: const Icon(Icons.mark_email_read_rounded, color: AppTheme.success, size: 28),
                ),
                title: const Text('Submitted for Review'),
                content: Text(state.message),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      label: 'Go to Login',
                      size: AppButtonSize.medium,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ),
                ],
              ),
            );
          } else if (state is AuthAuthenticated) {
            _navigateByRole(context, state.user);
          } else if (state is AuthError) {
            showAppSnackBar(context, state.message, isError: true);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Role selector ─────────────────────────────────────────
                  const Text('I want to join as:',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  Row(children: [
                    _RoleCard(
                      icon: Icons.person_rounded,
                      label: 'Passenger',
                      subtitle: 'Book rides',
                      value: 'passenger',
                      selected: _selectedRole == 'passenger',
                      color: AppTheme.passengerColor,
                      onTap: () => setState(() => _selectedRole = 'passenger'),
                    ),
                    const SizedBox(width: 12),
                    _RoleCard(
                      icon: Icons.drive_eta_rounded,
                      label: 'Driver',
                      subtitle: 'Offer rides',
                      value: 'driver',
                      selected: _selectedRole == 'driver',
                      color: AppTheme.driverColor,
                      onTap: () => setState(() => _selectedRole = 'driver'),
                    ),
                    const SizedBox(width: 12),
                    _RoleCard(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Both',
                      subtitle: 'Drive & ride',
                      value: 'both',
                      selected: _selectedRole == 'both',
                      color: AppTheme.accent,
                      onTap: () => setState(() => _selectedRole = 'both'),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // ── Full Name ─────────────────────────────────────────────
                  _label('Full Name'),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Name is required';
                      if (v.trim().length < 2) return 'Name too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Email ─────────────────────────────────────────────────
                  _label('Email'),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      final re = RegExp(
                          r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                      if (!re.hasMatch(v.trim()))
                        return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Phone with country-code picker ────────────────────────
                  _label('Phone Number'),
                  IntlPhoneField(
                    countries: _nepalPhoneCountries,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Mobile number',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    initialCountryCode: kDefaultCountry.isoCode, // 'NP'
                    onCountryChanged: (country) {
                      final info = countryByIso(country.code);
                      if (info != null) setState(() => _selectedCountry = info);
                    },
                    onChanged: (PhoneNumber p) {
                      _barePhone = p.number;
                      _fullPhone = p.completeNumber;
                    },
                    validator: (p) {
                      if (p == null || p.number.isEmpty) {
                        return 'Phone number is required';
                      }
                      if (!_isValidNepalMobile(p.number)) {
                        return 'Enter a 10-digit Nepal mobile number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Map search will be limited to ${_selectedCountry.name}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // ── Password ──────────────────────────────────────────────
                  _label('Verification Document'),
                  InkWell(
                    onTap: isLoading ? null : _pickDocument,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.badge_outlined,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _document == null
                                    ? 'Upload ID document'
                                    : _document!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Admin approval is required before login',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _document == null
                              ? Icons.upload_file_rounded
                              : Icons.check_circle_rounded,
                          color: _document == null
                              ? AppTheme.textSecondary
                              : AppTheme.success,
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _label('Password'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Create a password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 6) return 'Min 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Confirm Password ──────────────────────────────────────
                  _label('Confirm Password'),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: 'Repeat your password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty)
                        return 'Please confirm password';
                      if (v != _passwordController.text)
                        return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // ── Submit ────────────────────────────────────────────────
                  AppButton.primary(
                    label: 'Create Account',
                    loading: isLoading,
                    onPressed: isLoading ? null : _onRegister,
                  ),
                  const SizedBox(height: 16),

                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Already have an account? ',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13.5)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('Sign In',
                          style: TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5)),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      );
}

// ── Role card (unchanged) ─────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected ? color : AppTheme.textSecondary, size: 26),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? color : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
            Text(subtitle,
                style: TextStyle(
                    color: selected
                        ? color.withOpacity(0.7)
                        : AppTheme.textSecondary,
                    fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}
