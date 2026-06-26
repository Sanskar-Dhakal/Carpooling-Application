import '../models/user_model.dart';

abstract class AuthState {}

class AuthInitial          extends AuthState {}
class AuthLoading          extends AuthState {}
class AuthUnauthenticated  extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserModel user;
  AuthAuthenticated({required this.user});
}

class AuthError extends AuthState {
  final String message;
  final String? verificationStatus;
  AuthError({required this.message, this.verificationStatus});
}

class AuthRegistrationSubmitted extends AuthState {
  final String message;
  AuthRegistrationSubmitted({required this.message});
}

// ── Verification states ───────────────────────────────────────────────────────

/// SMS sent — show the OTP input screen
class AuthPhoneOtpSent extends AuthState {
  final String maskedPhone; // e.g. "+977 984*****67"
  AuthPhoneOtpSent({required this.maskedPhone});
}

/// OTP confirmed — move to email step
class AuthPhoneVerified extends AuthState {}

/// Firebase email link sent — show "check your inbox" screen
class AuthEmailVerificationSent extends AuthState {
  final String email;
  AuthEmailVerificationSent({required this.email});
}

/// Email confirmed — user can enter the app
class AuthEmailVerified extends AuthState {
  final UserModel user;
  AuthEmailVerified({required this.user});
}
