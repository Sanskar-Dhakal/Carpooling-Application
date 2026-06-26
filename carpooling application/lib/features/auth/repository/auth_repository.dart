import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AuthRepository {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await _save(data);
        return {'success': true, 'user': data['user']};
      }
      if (data['token'] != null) {
        await _saveReuploadToken(data['token'] as String);
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Login failed',
        'verification_status': data['verification_status'],
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.'
      };
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    required XFile document,
    bool verified = false,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/auth/register'),
      )
        ..fields['name'] = name
        ..fields['email'] = email
        ..fields['phone'] = phone
        ..fields['password'] = password
        ..fields['role'] = role
        ..fields['verified'] = verified.toString();

      request.files.add(http.MultipartFile.fromBytes(
        'document',
        await document.readAsBytes(),
        filename: document.name,
      ));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final data = jsonDecode(res.body.isEmpty ? '{}' : res.body);
      if (res.statusCode == 201) {
        if (data['token'] != null) await _save(data);
        return {
          'success': true,
          'user': data['user'],
          'message': data['message'] ??
              'Registration submitted. Please wait for admin verification.',
        };
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed'
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Connection error. Please try again.'
      };
    }
  }

  /// Called once both phone OTP and email link are confirmed.
  /// Hits PATCH /users/:id/verify on the backend.
  Future<bool> markVerified({required String userId}) async {
    try {
      final token = await getToken();
      final res = await http.patch(
        Uri.parse('${AppConstants.baseUrl}/users/$userId/verify'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return false;
      await _setVerifiedFlag();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _setVerifiedFlag() async {
    try {
      final userJson = await _storage.read(key: AppConstants.userKey);
      if (userJson == null) return;
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      userMap['is_verified'] = true;
      await _storage.write(
          key: AppConstants.userKey, value: jsonEncode(userMap));
    } catch (_) {
      // ignore storage update failures
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    await _storage.write(key: AppConstants.tokenKey, value: data['token']);
    await _storage.write(
        key: AppConstants.refreshTokenKey, value: data['refreshToken']);
    await _storage.write(
        key: AppConstants.userKey, value: jsonEncode(data['user']));
  }

  Future<void> _saveReuploadToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final j = await _storage.read(key: AppConstants.userKey);
      return j != null ? UserModel.fromJson(jsonDecode(j)) : null;
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> refreshCurrentUser() async {
    try {
      final token = await getToken();
      if (token == null) return null;
      final res = await http.get(
        Uri.parse('${AppConstants.baseUrl}/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      await _storage.write(key: AppConstants.userKey, value: jsonEncode(user));
      return UserModel.fromJson(user);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);
  Future<void> logout() => _storage.deleteAll();
}
