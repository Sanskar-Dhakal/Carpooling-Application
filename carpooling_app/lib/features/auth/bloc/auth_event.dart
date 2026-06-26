import '../../../core/constants/country_data.dart';
import 'package:image_picker/image_picker.dart';

abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthRefreshRequested extends AuthEvent {}

class AuthLogoutRequested extends AuthEvent {}

class AuthGoogleLoginRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  AuthLoginRequested({required this.email, required this.password});
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String phone; // bare digits, no dial code
  final String password;
  final String role;
  final CountryInfo country; // selected country from phone picker
  final XFile document;
  AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.role,
    required this.country,
    required this.document,
  });
}

// ── Phone OTP events ──────────────────────────────────────────────────────────

class AuthSendPhoneOtpRequested extends AuthEvent {
  final String fullPhoneNumber; // includes dial code e.g. "+9779841xxxxxx"
  AuthSendPhoneOtpRequested({required this.fullPhoneNumber});
}

class AuthVerifyPhoneOtpRequested extends AuthEvent {
  final String otp;
  AuthVerifyPhoneOtpRequested({required this.otp});
}

class AuthResendPhoneOtpRequested extends AuthEvent {
  final String fullPhoneNumber;
  AuthResendPhoneOtpRequested({required this.fullPhoneNumber});
}

// ── Email verification events ─────────────────────────────────────────────────

class AuthSendEmailVerificationRequested extends AuthEvent {}

class AuthCheckEmailVerifiedRequested extends AuthEvent {}
