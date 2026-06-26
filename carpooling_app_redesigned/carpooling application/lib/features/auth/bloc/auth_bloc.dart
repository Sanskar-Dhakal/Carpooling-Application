import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/auth_repository.dart';
import '../models/user_model.dart';
import '../../../core/services/firebase_auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:image_picker/image_picker.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repo;
  final FirebaseAuthService _firebase = FirebaseAuthService.instance;

  // Held while phone+email verification is in progress
  UserModel? _pendingUser;
  String? _pendingPassword;
  XFile? _pendingDocument;

  AuthBloc({required AuthRepository authRepository})
      : _repo = authRepository,
        super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheck);
    on<AuthRefreshRequested>(_onRefresh);
    on<AuthLoginRequested>(_onLogin);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthSendPhoneOtpRequested>(_onSendOtp);
    on<AuthVerifyPhoneOtpRequested>(_onVerifyOtp);
    on<AuthResendPhoneOtpRequested>(_onResendOtp);
    on<AuthSendEmailVerificationRequested>(_onSendEmail);
    on<AuthCheckEmailVerifiedRequested>(_onCheckEmail);
  }

  // ── Session check ─────────────────────────────────────────────────────────

  Future<void> _onCheck(AuthCheckRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final user = await _repo.getCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user: user));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onRefresh(
      AuthRefreshRequested e, Emitter<AuthState> emit) async {
    final user = await _repo.refreshCurrentUser();
    if (user != null) {
      emit(AuthAuthenticated(user: user));
    } else {
      add(AuthCheckRequested());
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<void> _onLogin(AuthLoginRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final r = await _repo.login(e.email, e.password);
    if (r['success'] == true) {
      emit(AuthAuthenticated(user: UserModel.fromJson(r['user'])));
    } else {
      emit(AuthError(
        message: r['message'] ?? 'Login failed',
        verificationStatus: r['verification_status'],
      ));
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _onLogout(AuthLogoutRequested e, Emitter<AuthState> emit) async {
    await _repo.logout();
    await _firebase.signOut();
    _pendingUser = null;
    _pendingDocument = null;
    emit(AuthUnauthenticated());
  }

  // ── Register → trigger phone OTP ─────────────────────────────────────────

  Future<void> _onRegister(
      AuthRegisterRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final r = await _repo.register(
      name: e.name,
      email: e.email,
      phone: e.phone,
      password: e.password,
      role: e.role,
      document: e.document,
      verified: false,
    );

    if (r['success'] != true) {
      emit(AuthError(message: r['message'] ?? 'Registration failed'));
      return;
    }

    emit(AuthRegistrationSubmitted(
      message: r['message'] ??
          'Registration submitted. Please wait for admin verification.',
    ));
  }

  // ── Phone OTP ─────────────────────────────────────────────────────────────

  Future<void> _onSendOtp(
      AuthSendPhoneOtpRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    String? err;
    final result = await _firebase.sendPhoneOtp(
      phoneNumber: e.fullPhoneNumber,
      onError: (m) => err = m,
      onAutoVerified: () => add(AuthSendEmailVerificationRequested()),
    );
    if (err != null) {
      emit(AuthError(message: err!));
      return;
    }
    switch (result) {
      case VerificationResult.codeSent:
        emit(AuthPhoneOtpSent(maskedPhone: _mask(e.fullPhoneNumber)));
      case VerificationResult.success:
        add(AuthSendEmailVerificationRequested());
      case VerificationResult.tooManyRequests:
        emit(AuthError(message: 'Too many OTP requests. Try again later.'));
      default:
        emit(AuthError(message: 'Failed to send OTP. Please try again.'));
    }
  }

  Future<void> _onVerifyOtp(
      AuthVerifyPhoneOtpRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final result = await _firebase.verifyPhoneOtp(e.otp);
    switch (result) {
      case VerificationResult.success:
        emit(AuthPhoneVerified());
        add(AuthSendEmailVerificationRequested());
      case VerificationResult.expired:
        emit(
            AuthError(message: 'OTP expired. Tap "Resend" to get a new code.'));
      default:
        emit(AuthError(message: 'Invalid OTP. Please check and try again.'));
    }
  }

  Future<void> _onResendOtp(
      AuthResendPhoneOtpRequested e, Emitter<AuthState> emit) async {
    add(AuthSendPhoneOtpRequested(fullPhoneNumber: e.fullPhoneNumber));
  }

  // ── Email verification ────────────────────────────────────────────────────

  Future<void> _onSendEmail(
      AuthSendEmailVerificationRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final pending = _pendingUser;
    if (pending == null) {
      emit(AuthError(message: 'Session expired. Please register again.'));
      return;
    }
    if (_firebase.currentUser == null) {
      final res = await _firebase.createEmailAccount(
        email: pending.email,
        password: 'firebase_tmp_${pending.id}',
      );
      if (!res.success) {
        emit(AuthError(
            message: res.errorMessage ?? 'Could not create Firebase account.'));
        return;
      }
    } else {
      await _firebase.sendEmailVerification();
    }
    emit(AuthEmailVerificationSent(email: pending.email));
  }

  Future<void> _onCheckEmail(
      AuthCheckEmailVerifiedRequested e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    final verified = await _firebase.checkEmailVerified();
    if (verified) {
      final pending = _pendingUser;
      final password = _pendingPassword;
      final document = _pendingDocument;
      if (pending == null || password == null || document == null) {
        emit(AuthError(message: 'Session expired. Please register again.'));
        return;
      }

      final r = await _repo.register(
        name: pending.name,
        email: pending.email,
        phone: pending.phone,
        password: password,
        role: pending.role,
        document: document,
        verified: false,
      );
      if (r['success'] != true) {
        emit(AuthError(message: r['message'] ?? 'Registration failed'));
        return;
      }
      _pendingPassword = null;
      _pendingUser = null;
      _pendingDocument = null;
      emit(AuthRegistrationSubmitted(
        message: r['message'] ??
            'Registration submitted. Please wait for admin verification.',
      ));
    } else {
      emit(AuthEmailVerificationSent(email: _pendingUser?.email ?? ''));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _mask(String phone) {
    if (phone.length < 6) return phone;
    return '${phone.substring(0, 4)} *****${phone.substring(phone.length - 2)}';
  }
}
