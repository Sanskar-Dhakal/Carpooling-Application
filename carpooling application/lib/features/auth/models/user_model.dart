class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isVerified;
  final double rating;
  final String? profilePhotoUrl;
  final String? qrPaymentId;
  final String? qrPaymentLabel;
  final String? qrPaymentImageUrl;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isVerified = false,
    this.rating = 0.0,
    this.profilePhotoUrl,
    this.qrPaymentId,
    this.qrPaymentLabel,
    this.qrPaymentImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id:              json['id']           ?? '',
        name:            json['name']         ?? '',
        email:           json['email']        ?? '',
        phone:           json['phone']        ?? '',
        role:            json['role']         ?? 'passenger',
        isVerified:      json['is_verified']  ?? false,
        rating:          (json['rating']      ?? 0.0).toDouble(),
        profilePhotoUrl: json['profile_photo_url'],
        qrPaymentId:     json['qr_payment_id'],
        qrPaymentLabel:  json['qr_payment_label'],
        qrPaymentImageUrl: json['qr_payment_image_url'],
      );

  Map<String, dynamic> toJson() => {
        'id':                id,
        'name':              name,
        'email':             email,
        'phone':             phone,
        'role':              role,
        'is_verified':       isVerified,
        'rating':            rating,
        'profile_photo_url': profilePhotoUrl,
        'qr_payment_id':     qrPaymentId,
        'qr_payment_label':  qrPaymentLabel,
        'qr_payment_image_url': qrPaymentImageUrl,
      };

  // ── Role helpers ──────────────────────────────────────
  bool get isDriver    => role == 'driver'    || role == 'both';
  bool get isPassenger => role == 'passenger' || role == 'both';
  bool get isAdmin     => role == 'admin';

  // ── Route by role ─────────────────────────────────────
  String get homeRoute {
    if (isAdmin)   return '/admin/home';
    if (isDriver && !isPassenger) return '/driver/home';
    return '/passenger/home';
  }
}
