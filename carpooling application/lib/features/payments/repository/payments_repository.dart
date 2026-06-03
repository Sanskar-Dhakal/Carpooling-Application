import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../models/wallet_model.dart';

class PaymentsRepository {
  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey) ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<({WalletModel wallet, List<WalletTransactionModel> transactions})> wallet() async {
    final res = await http
        .get(Uri.parse('${AppConstants.baseUrl}/payments/wallet'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not load wallet');
    return (
      wallet: WalletModel.fromJson(data['wallet']),
      transactions: (data['transactions'] as List).map((e) => WalletTransactionModel.fromJson(e)).toList(),
    );
  }

  Future<WalletModel> topUp(double amount) async {
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/payments/wallet/top-up'),
          headers: await _headers,
          body: jsonEncode({'amount': amount}),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not top up wallet');
    return WalletModel.fromJson(data['wallet']);
  }

  Future<WalletModel> requestWithdrawal(double amount) async {
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/payments/wallet/withdrawals'),
          headers: await _headers,
          body: jsonEncode({'amount': amount}),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) throw Exception(data['message'] ?? 'Could not request withdrawal');
    return WalletModel.fromJson(data['wallet']);
  }

  Future<void> saveDriverQr({
    required String qrPaymentId,
    required String qrPaymentLabel,
    required String qrPaymentImageUrl,
  }) async {
    final res = await http
        .put(
          Uri.parse('${AppConstants.baseUrl}/payments/qr'),
          headers: await _headers,
          body: jsonEncode({
            'qrPaymentId': qrPaymentId,
            'qrPaymentLabel': qrPaymentLabel,
            'qrPaymentImageUrl': qrPaymentImageUrl,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Could not save QR');
    }
  }

  Future<void> adminCreditWallet({
    required String email,
    required double amount,
    required String description,
  }) async {
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/payments/admin/credit-wallet'),
          headers: await _headers,
          body: jsonEncode({'email': email, 'amount': amount, 'description': description}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Could not credit wallet');
    }
  }

  Future<List<WalletTransactionModel>> withdrawalRequests() async {
    final res = await http
        .get(Uri.parse('${AppConstants.baseUrl}/payments/admin/withdrawals'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not load withdrawals');
    return (data['withdrawals'] as List).map((e) => WalletTransactionModel.fromJson(e)).toList();
  }
}
