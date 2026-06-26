import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum VerificationResult { success, failed, codeSent, expired, tooManyRequests }

class FirebaseAuthService {
  FirebaseAuthService._();
  static final FirebaseAuthService instance = FirebaseAuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _verificationId;
  int?    _resendToken;

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  Future<VerificationResult> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String msg) onError,
    void Function()? onAutoVerified,
  }) async {
    final completer = _Once<VerificationResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: _resendToken,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential cred) async {
        try {
          final user = _auth.currentUser;
          if (user != null) {
            await user.linkWithCredential(cred);
          } else {
            await _auth.signInWithCredential(cred);
          }
          onAutoVerified?.call();
          completer.complete(VerificationResult.success);
        } catch (_) {
          completer.complete(VerificationResult.failed);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('verificationFailed: ${e.code}');
        onError(_friendlyPhoneError(e.code));
        completer.complete(
          e.code == 'too-many-requests'
              ? VerificationResult.tooManyRequests
              : VerificationResult.failed,
        );
      },
      codeSent: (String id, int? resend) {
        _verificationId = id;
        _resendToken    = resend;
        completer.complete(VerificationResult.codeSent);
      },
      codeAutoRetrievalTimeout: (String id) {
        _verificationId = id;
      },
    );

    return completer.future;
  }

  Future<VerificationResult> verifyPhoneOtp(String smsCode) async {
    if (_verificationId == null) return VerificationResult.failed;
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      final user = _auth.currentUser;
      if (user != null) {
        await user.linkWithCredential(cred);
      } else {
        await _auth.signInWithCredential(cred);
      }
      return VerificationResult.success;
    } on FirebaseAuthException catch (e) {
      return e.code == 'session-expired'
          ? VerificationResult.expired
          : VerificationResult.failed;
    }
  }

  // ── Email verification ─────────────────────────────────────────────────────

  Future<({bool success, String? errorMessage, User? user})> createEmailAccount({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.sendEmailVerification();
      return (success: true, errorMessage: null, user: cred.user);
    } on FirebaseAuthException catch (e) {
      return (success: false, errorMessage: _friendlyEmailError(e.code), user: null);
    }
  }

  Future<bool> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      return _auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  User?  get currentUser     => _auth.currentUser;
  bool   get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  Future<void> signOut()     => _auth.signOut();

  static String _friendlyPhoneError(String code) => switch (code) {
    'invalid-phone-number'   => 'The phone number format is invalid.',
    'too-many-requests'      => 'Too many attempts. Please wait and try again.',
    'quota-exceeded'         => 'SMS quota exceeded. Try again later.',
    'network-request-failed' => 'Network error. Check your connection.',
    _                        => 'Phone verification failed ($code).',
  };

  static String _friendlyEmailError(String code) => switch (code) {
    'email-already-in-use'   => 'This email is already registered.',
    'invalid-email'          => 'The email address is badly formatted.',
    'weak-password'          => 'Password must be at least 6 characters.',
    'network-request-failed' => 'Network error. Check your connection.',
    _                        => 'Account creation failed. Please try again.',
  };
}

class _Once<T> {
  final _c = Completer<T>();
  bool _done = false;
  Future<T> get future => _c.future;
  void complete(T v) {
    if (!_done) { _done = true; _c.complete(v); }
  }
}