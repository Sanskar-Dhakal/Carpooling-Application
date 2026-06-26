import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/country_data.dart';

class LocationResult {
  final String displayName;
  final double lat;
  final double lng;

  const LocationResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

class LocationSearchService {
  LocationSearchService._();
  static final LocationSearchService instance = LocationSearchService._();

  static const String _base = 'https://nominatim.openstreetmap.org';

  /// Search [query] restricted to [country].
  /// When country is selected (e.g. Nepal), bounded=1 ensures zero results
  /// leak outside that country's bounding box.
  Future<List<LocationResult>> search({
    required String query,
    CountryInfo? country,
    int limit = 8,
  }) async {
    if (query.trim().isEmpty) return [];

    final params = <String, String>{
      'q':      query,
      'format': 'json',
      'limit':  '$limit',
      'addressdetails': '0',
    };

    if (country != null) {
      params['countrycodes'] =
          country.mapBounds.nominatimCountrycodes(country.isoCode);
      params['viewbox']  = country.mapBounds.nominatimViewbox;
      params['bounded']  = '1'; // strict: only inside the viewbox
    }

    final uri = Uri.parse('$_base/search').replace(queryParameters: params);

    try {
      final res = await http.get(uri, headers: {
        'User-Agent':      'VroomSquad/1.0 (carpooling app)',
        'Accept-Language': 'en',
      }).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(res.body);
      return data.map((item) => LocationResult(
        displayName: item['display_name'] as String,
        lat: double.parse(item['lat'] as String),
        lng: double.parse(item['lon'] as String),
      )).toList();
    } catch (_) {
      return [];
    }
  }
}