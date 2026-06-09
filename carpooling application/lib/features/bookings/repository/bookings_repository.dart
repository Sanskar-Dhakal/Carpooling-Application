import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../models/booking_model.dart';

class BookingsRepository {
  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey) ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<BookingModel> createBooking({
    required String rideId,
    required int seatsBooked,
    required String paymentMethod,
  }) async {
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/bookings'),
          headers: await _headers,
          body: jsonEncode({
            'rideId': rideId,
            'seatsBooked': seatsBooked,
            'paymentMethod': paymentMethod,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) throw Exception(data['message'] ?? 'Could not create booking');
    return BookingModel.fromJson(data['booking']);
  }

  Future<List<BookingModel>> myBookings() async {
    final res = await http
        .get(Uri.parse('${AppConstants.baseUrl}/bookings/my'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not load bookings');
    return (data['bookings'] as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<List<BookingModel>> driverBookings() async {
    final res = await http
        .get(Uri.parse('${AppConstants.baseUrl}/bookings/driver'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not load requests');
    return (data['bookings'] as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<BookingModel> updateStatus(String bookingId, String status) async {
    final res = await http
        .patch(
          Uri.parse('${AppConstants.baseUrl}/bookings/$bookingId/status'),
          headers: await _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not update booking');
    return BookingModel.fromJson(data['booking']);
  }

  Future<BookingModel> submitQrPayment(String bookingId, String screenshotUrl) async {
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/bookings/$bookingId/qr-payment'),
          headers: await _headers,
          body: jsonEncode({'screenshotUrl': screenshotUrl}),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not submit QR payment');
    return BookingModel.fromJson(data['booking']);
  }

  Future<BookingModel> authorizeWalletPayment(String bookingId, String password) async {
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/bookings/$bookingId/authorize-wallet'),
          headers: await _headers,
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not authorize wallet payment');
    return BookingModel.fromJson(data['booking']);
  }

  Future<BookingModel> confirmPayment(String bookingId) async {
    final res = await http
        .post(Uri.parse('${AppConstants.baseUrl}/bookings/$bookingId/confirm-payment'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not confirm payment');
    return BookingModel.fromJson(data['booking']);
  }
}
