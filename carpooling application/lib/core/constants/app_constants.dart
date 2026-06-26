class AppConstants {
  // API
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String roleKey = 'user_role';

  // User Roles
  static const String roleDriver = 'driver';
  static const String rolePassenger = 'passenger';
  static const String roleBoth = 'both';
  static const String roleAdmin = 'admin';

  // Payment Methods
  static const String paymentWallet = 'wallet';
  static const String paymentQR = 'qr';
  static const String paymentCash = 'cash';

  // Ride Status
  static const String rideActive = 'active';
  static const String rideInProgress = 'in_progress';
  static const String rideCompleted = 'completed';
  static const String rideCancelled = 'cancelled';

  // Booking Status
  static const String bookingPending = 'pending';
  static const String bookingConfirmed = 'confirmed';
  static const String bookingCancelled = 'cancelled';
  static const String bookingCompleted = 'completed';
}
