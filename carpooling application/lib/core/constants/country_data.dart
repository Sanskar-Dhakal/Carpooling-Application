class CountryInfo {
  final String isoCode;
  final String dialCode;
  final String name;
  final CountryBounds mapBounds;

  const CountryInfo({
    required this.isoCode,
    required this.dialCode,
    required this.name,
    required this.mapBounds,
  });
}

class CountryBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const CountryBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  double get centerLat => (minLat + maxLat) / 2;
  double get centerLng => (minLng + maxLng) / 2;

  // Nominatim viewbox param: "minLng,maxLat,maxLng,minLat"
  String get nominatimViewbox => '$minLng,$maxLat,$maxLng,$minLat';

  String nominatimCountrycodes(String isoCode) => isoCode.toLowerCase();
}

const List<CountryInfo> kCountries = [
  CountryInfo(
    isoCode: 'NP', dialCode: '+977', name: 'Nepal',
    mapBounds: CountryBounds(minLat: 26.36, maxLat: 30.45, minLng: 80.06, maxLng: 88.20),
  ),
  CountryInfo(
    isoCode: 'IN', dialCode: '+91', name: 'India',
    mapBounds: CountryBounds(minLat: 7.96, maxLat: 35.67, minLng: 67.96, maxLng: 97.40),
  ),
  CountryInfo(
    isoCode: 'US', dialCode: '+1', name: 'United States',
    mapBounds: CountryBounds(minLat: 24.52, maxLat: 49.38, minLng: -124.77, maxLng: -66.95),
  ),
  CountryInfo(
    isoCode: 'GB', dialCode: '+44', name: 'United Kingdom',
    mapBounds: CountryBounds(minLat: 49.87, maxLat: 58.64, minLng: -8.65, maxLng: 1.77),
  ),
  CountryInfo(
    isoCode: 'AU', dialCode: '+61', name: 'Australia',
    mapBounds: CountryBounds(minLat: -43.65, maxLat: -10.67, minLng: 113.15, maxLng: 153.64),
  ),
  CountryInfo(
    isoCode: 'PK', dialCode: '+92', name: 'Pakistan',
    mapBounds: CountryBounds(minLat: 23.63, maxLat: 37.10, minLng: 60.87, maxLng: 77.84),
  ),
  CountryInfo(
    isoCode: 'BD', dialCode: '+880', name: 'Bangladesh',
    mapBounds: CountryBounds(minLat: 20.74, maxLat: 26.63, minLng: 88.01, maxLng: 92.67),
  ),
  CountryInfo(
    isoCode: 'AE', dialCode: '+971', name: 'UAE',
    mapBounds: CountryBounds(minLat: 22.63, maxLat: 26.09, minLng: 51.58, maxLng: 56.38),
  ),
  CountryInfo(
    isoCode: 'SG', dialCode: '+65', name: 'Singapore',
    mapBounds: CountryBounds(minLat: 1.16, maxLat: 1.47, minLng: 103.61, maxLng: 104.00),
  ),
  CountryInfo(
    isoCode: 'DE', dialCode: '+49', name: 'Germany',
    mapBounds: CountryBounds(minLat: 47.27, maxLat: 55.09, minLng: 5.87, maxLng: 15.04),
  ),
];

CountryInfo? countryByIso(String isoCode) {
  final upper = isoCode.toUpperCase();
  try {
    return kCountries.firstWhere((c) => c.isoCode == upper);
  } catch (_) {
    return null;
  }
}

// Default country: Nepal
final CountryInfo kDefaultCountry = kCountries[0];