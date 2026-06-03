class AppConstants {
  // ── API ───────────────────────────────────────────────
  // Use 10.0.2.2 for Android emulator, localhost for web/desktop
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  // ── Storage Keys ──────────────────────────────────────
  static const String tokenKey        = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey         = 'user_data';

  // ── Roles ─────────────────────────────────────────────
  static const String roleDriver    = 'driver';
  static const String rolePassenger = 'passenger';
  static const String roleBoth      = 'both';
  static const String roleAdmin     = 'admin';
}
