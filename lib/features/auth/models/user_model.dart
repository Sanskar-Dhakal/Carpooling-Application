class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isVerified;
  final double rating;
  final String? profilePhotoUrl;
  final String? fcmToken;
  final String? qrPaymentId;
  final String? qrPaymentLabel;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isVerified = false,
    this.rating = 0.0,
    this.profilePhotoUrl,
    this.fcmToken,
    this.qrPaymentId,
    this.qrPaymentLabel,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'passenger',
      isVerified: json['is_verified'] ?? false,
      rating: (json['rating'] ?? 0.0).toDouble(),
      profilePhotoUrl: json['profile_photo_url'],
      fcmToken: json['fcm_token'],
      qrPaymentId: json['qr_payment_id'],
      qrPaymentLabel: json['qr_payment_label'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'is_verified': isVerified,
      'rating': rating,
      'profile_photo_url': profilePhotoUrl,
      'fcm_token': fcmToken,
      'qr_payment_id': qrPaymentId,
      'qr_payment_label': qrPaymentLabel,
    };
  }

  bool get isDriver => role == 'driver' || role == 'both';
  bool get isPassenger => role == 'passenger' || role == 'both';
  bool get isAdmin => role == 'admin';
}
