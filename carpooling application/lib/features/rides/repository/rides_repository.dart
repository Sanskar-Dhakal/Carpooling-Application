import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../models/ride_model.dart';

class RidesRepository {
  Future<Map<String, String>> get _headers async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey) ?? '';
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<PlaceSuggestion>> geocode(String query) async {
    final res = await http
        .get(
          Uri.parse('${AppConstants.baseUrl}/rides/geocode?q=${Uri.encodeQueryComponent(query)}'),
          headers: await _headers,
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Geocoding failed');
    return (data['results'] as List).map((e) => PlaceSuggestion.fromJson(e)).toList();
  }

  Future<RideModel> postRide({
    required PlaceSuggestion origin,
    required PlaceSuggestion destination,
    required DateTime departureTime,
    required int seats,
    required double price,
    required Map<String, bool> preferences,
  }) async {
    final res = await http
        .post(
          Uri.parse('${AppConstants.baseUrl}/rides'),
          headers: await _headers,
          body: jsonEncode({
            'originAddress': origin.label,
            'originLat': origin.lat,
            'originLng': origin.lng,
            'destinationAddress': destination.label,
            'destinationLat': destination.lat,
            'destinationLng': destination.lng,
            'departureTime': departureTime.toIso8601String(),
            'seats': seats,
            'price': price,
            'preferences': preferences,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) throw Exception(data['message'] ?? 'Could not post ride');
    return RideModel.fromJson(data['ride']);
  }

  Future<List<RideModel>> searchRides({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/rides/search').replace(queryParameters: {
      'originLat': origin.latitude.toString(),
      'originLng': origin.longitude.toString(),
      'destinationLat': destination.latitude.toString(),
      'destinationLng': destination.longitude.toString(),
      'maxDetour': '0.6',
    });
    final res = await http.get(uri, headers: await _headers).timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Ride search failed');
    return (data['rides'] as List).map((e) => RideModel.fromJson(e)).toList();
  }

  Future<List<RideModel>> myRides() async {
    final res = await http
        .get(Uri.parse('${AppConstants.baseUrl}/rides/my'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not load rides');
    return (data['rides'] as List).map((e) => RideModel.fromJson(e)).toList();
  }

  Future<RideModel> rideDetail(String id) async {
    final res = await http
        .get(Uri.parse('${AppConstants.baseUrl}/rides/$id'), headers: await _headers)
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) throw Exception(data['message'] ?? 'Could not load ride');
    return RideModel.fromJson(data['ride']);
  }

  Future<void> updateStatus(String id, String status) async {
    final res = await http
        .patch(
          Uri.parse('${AppConstants.baseUrl}/rides/$id/status'),
          headers: await _headers,
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'Could not update ride');
    }
  }
}
