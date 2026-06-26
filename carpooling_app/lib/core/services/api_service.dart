import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final _storage = const FlutterSecureStorage();

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.read(key: AppConstants.tokenKey);
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final resp = await http.get(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: await _authHeaders(),
    );
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final resp = await http.post(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final resp = await http.put(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  static Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final resp = await http.patch(
      Uri.parse('${AppConstants.baseUrl}$path'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  static Map<String, dynamic> _handle(http.Response resp) {
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return {'success': true, ...data};
    }
    throw ApiException(
      data['message'] as String? ?? 'Request failed',
      resp.statusCode,
    );
  }

  static Future<Map<String, dynamic>> uploadMultipart(
    String path,
    String fieldName,
    Uint8List bytes, {
    String? filename,
    String? contentType,
    Map<String, String>? fields,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await _authHeaders());
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: filename,
        contentType: contentType != null ? MediaType.parse(contentType) : null,
      ),
    );
    if (fields != null) {
      request.fields.addAll(fields);
    }
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return _handle(resp);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}
