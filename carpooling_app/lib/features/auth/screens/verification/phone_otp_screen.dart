import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';
import 'email_verification_screen.dart';

class PhoneOtpScreen extends StatefulWidget {
  final String maskedPhone;
  final String fullPhone; // needed for resend

  const PhoneOtpScreen({
    super.key,
    required this.maskedPhone,
    required this.fullPhone,
  });

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final _controller = TextEditingController();
  String _otp       = '';
  int _secondsLeft  = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    if (_otp.length == 6) {
      context.read<AuthBloc>().add(AuthVerifyPhoneOtpRequested(otp: _otp));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Verify Phone')),
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthEmailVerificationSent) {
            Navigator.pushReplacement(context, MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(
                email: state.email,
              ),
            ));
          } else if (state is AuthPhoneOtpSent) {
            // Resent successfully
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('OTP resent successfully'),
              behavior: SnackBarBehavior.floating,
            ));
          } else if (state is AuthError) {
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
                const SizedBox(height: 48),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sms_rounded,
                      color: AppTheme.primary, size: 40),
                ),
                const SizedBox(height: 24),
                const Text('Enter verification code',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to\n${widget.maskedPhone}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 40),

                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  animationType: AnimationType.scale,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(10),
                    fieldHeight: 52,
                    fieldWidth: 44,
                    activeFillColor: Colors.white,
                    inactiveFillColor: AppTheme.background,
                    selectedFillColor: Colors.white,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.border,
                    selectedColor: AppTheme.primary,
                  ),
                  enableActiveFill: true,
                  onCompleted: (v) { _otp = v; _verify(); },
                  onChanged:   (v) => _otp = v,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: (loading || _otp.length < 6) ? null : _verify,
                    child: loading
                        ? const SizedBox(height: 20, width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Verify'),
                  ),
                ),
                const SizedBox(height: 24),

                if (_secondsLeft > 0)
                  Text('Resend code in $_secondsLeft s',
                      style: const TextStyle(color: AppTheme.textSecondary))
                else
                  TextButton(
                    onPressed: loading ? null : () {
                      context.read<AuthBloc>().add(AuthResendPhoneOtpRequested(
                          fullPhoneNumber: widget.fullPhone));
                      _startTimer();
                    },
                    child: const Text('Resend OTP',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}