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

  String _barePhone = '';
  String _fullPhone = '';
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
      showAppSnackBar(context, 'Please enter a valid Nepal mobile number',
          isError: true);
      return;
    }
    if (_document == null) {
      showAppSnackBar(
          context, 'Please upload an ID document for admin verification',
          isError: true);
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
              ),
            );
          } else if (state is AuthEmailVerified) {
            _navigateByRole(context, state.user);
          } else if (state is AuthRegistrationSubmitted) {
            showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusXl)),
                icon: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: AppTheme.successBg, shape: BoxShape.circle),
                  child: const Icon(Icons.mark_email_read_rounded,
                      color: AppTheme.success, size: 32),
                ),
                title: const Text('Submitted for Review'),
                content: Text(state.message, textAlign: TextAlign.center),
                actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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

          return CustomScrollView(
            slivers: [
              // ── Hero Header ─────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                stretch: true,
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.primary, AppTheme.primaryLight],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.04),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: -20,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.accent.withOpacity(0.08),
                            ),
                          ),
                        ),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusPill),
                                  ),
                                  child: const Text(
                                    'NEW ACCOUNT',
                                    style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Join and start your journey today',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Form ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.space16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Role selector ────────────────────────────
                        _fieldLabel('I want to join as'),
                        const SizedBox(height: 10),
                        Row(children: [
                          _RoleCard(
                            icon: Icons.person_rounded,
                            label: 'Passenger',
                            subtitle: 'Book rides',
                            value: 'passenger',
                            selected: _selectedRole == 'passenger',
                            color: AppTheme.passengerColor,
                            onTap: () =>
                                setState(() => _selectedRole = 'passenger'),
                          ),
                          const SizedBox(width: 10),
                          _RoleCard(
                            icon: Icons.drive_eta_rounded,
                            label: 'Driver',
                            subtitle: 'Offer rides',
                            value: 'driver',
                            selected: _selectedRole == 'driver',
                            color: AppTheme.driverColor,
                            onTap: () =>
                                setState(() => _selectedRole = 'driver'),
                          ),
                          const SizedBox(width: 10),
                          _RoleCard(
                            icon: Icons.swap_horiz_rounded,
                            label: 'Both',
                            subtitle: 'Drive & ride',
                            value: 'both',
                            selected: _selectedRole == 'both',
                            color: AppTheme.accent,
                            onTap: () =>
                                setState(() => _selectedRole = 'both'),
                          ),
                        ]),
                        const SizedBox(height: 20),

                        // ── Personal Details ─────────────────────────
                        _sectionCard(
                          title: 'Personal Details',
                          icon: Icons.person_outline_rounded,
                          children: [
                            _fieldLabel('Full Name'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'Your full name',
                                prefixIcon: Icon(Icons.person_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Name is required';
                                if (v.trim().length < 2)
                                  return 'Name too short';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('Email Address'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                hintText: 'you@example.com',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Email is required';
                                final re = RegExp(
                                    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                                if (!re.hasMatch(v.trim()))
                                  return 'Enter a valid email address';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('Phone Number'),
                            const SizedBox(height: 8),
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
                              initialCountryCode: kDefaultCountry.isoCode,
                              onCountryChanged: (country) {
                                final info = countryByIso(country.code);
                                if (info != null)
                                  setState(() => _selectedCountry = info);
                              },
                              onChanged: (PhoneNumber p) {
                                _barePhone = p.number;
                                _fullPhone = p.completeNumber;
                              },
                              validator: (p) {
                                if (p == null || p.number.isEmpty)
                                  return 'Phone number is required';
                                if (!_isValidNepalMobile(p.number))
                                  return 'Enter a 10-digit Nepal mobile number';
                                return null;
                              },
                            ),
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 13, color: AppTheme.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                'Map search limited to ${_selectedCountry.name}',
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppTheme.textTertiary),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── ID Verification ──────────────────────────
                        _sectionCard(
                          title: 'ID Verification',
                          icon: Icons.badge_outlined,
                          children: [
                            _fieldLabel('Verification Document'),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: isLoading ? null : _pickDocument,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _document != null
                                      ? AppTheme.successBg
                                      : AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(
                                      AppTheme.radiusMd),
                                  border: Border.all(
                                    color: _document != null
                                        ? AppTheme.success.withOpacity(0.4)
                                        : AppTheme.border,
                                  ),
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: _document != null
                                          ? AppTheme.success.withOpacity(0.15)
                                          : AppTheme.primary.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(
                                          AppTheme.radiusSm),
                                    ),
                                    child: Icon(
                                      _document != null
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.badge_outlined,
                                      color: _document != null
                                          ? AppTheme.success
                                          : AppTheme.primary,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _document == null
                                              ? 'Upload ID Document'
                                              : _document!.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: _document != null
                                                ? AppTheme.success
                                                : AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _document == null
                                              ? 'Tap to choose from gallery'
                                              : 'Tap to change document',
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.upload_file_rounded,
                                    color: _document != null
                                        ? AppTheme.success
                                        : AppTheme.textTertiary,
                                    size: 20,
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warningBg,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSm),
                                border: Border.all(
                                    color:
                                        AppTheme.warning.withOpacity(0.2)),
                              ),
                              child: const Row(children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 15, color: AppTheme.warning),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Admin approval required before you can log in',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary),
                                  ),
                                ),
                              ]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // ── Security ─────────────────────────────────
                        _sectionCard(
                          title: 'Security',
                          icon: Icons.lock_outline_rounded,
                          children: [
                            _fieldLabel('Password'),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: 'Create a strong password',
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Password is required';
                                if (v.length < 6) return 'Min 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _fieldLabel('Confirm Password'),
                            const SizedBox(height: 8),
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
                                  onPressed: () => setState(() =>
                                      _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Please confirm your password';
                                if (v != _passwordController.text)
                                  return 'Passwords do not match';
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Submit ───────────────────────────────────
                        AppButton.primary(
                          label: 'Create Account',
                          loading: isLoading,
                          onPressed: isLoading ? null : _onRegister,
                        ),
                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account?  ',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13.5)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppTheme.textPrimary,
        ),
      );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

// ── Role Card ─────────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.07) : AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected ? color : AppTheme.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? [] : AppTheme.cardShadow,
          ),
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? color.withOpacity(0.15)
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Icon(
                icon,
                color: selected ? color : AppTheme.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? color.withOpacity(0.7)
                    : AppTheme.textSecondary,
                fontSize: 10.5,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 6),
              Container(
                width: 20,
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
