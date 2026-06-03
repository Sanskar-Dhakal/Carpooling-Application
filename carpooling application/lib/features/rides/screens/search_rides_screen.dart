import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ride_model.dart';
import '../repository/rides_repository.dart';
import '../widgets/route_map.dart';

class SearchRidesScreen extends StatefulWidget {
  const SearchRidesScreen({super.key});

  @override
  State<SearchRidesScreen> createState() => _SearchRidesScreenState();
}

class _SearchRidesScreenState extends State<SearchRidesScreen> {
  final _repo = RidesRepository();
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  PlaceSuggestion? _origin;
  PlaceSuggestion? _destination;
  List<PlaceSuggestion> _originResults = [];
  List<PlaceSuggestion> _destinationResults = [];
  List<RideModel> _rides = [];
  bool _loading = false;

  Future<void> _searchPlace(TextEditingController ctrl, bool isOrigin) async {
    setState(() => _loading = true);
    try {
      final results = await _repo.geocode(ctrl.text.trim());
      setState(() {
        if (isOrigin) {
          _originResults = results;
        } else {
          _destinationResults = results;
        }
      });
    } catch (e) {
      _show(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _findRides() async {
    if (_origin == null || _destination == null) {
      _show('Choose origin and destination from search results');
      return;
    }
    setState(() => _loading = true);
    try {
      final rides = await _repo.searchRides(origin: _origin!.point, destination: _destination!.point);
      setState(() => _rides = rides);
    } catch (e) {
      _show(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _rides.isNotEmpty
        ? _rides.first.route
        : [
            if (_origin != null) _origin!.point,
            if (_destination != null) _destination!.point,
          ];
    return Scaffold(
      appBar: AppBar(title: const Text('Find a Ride'), backgroundColor: AppTheme.passengerColor),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(height: 220, child: RouteMap(route: preview, origin: _origin?.point, destination: _destination?.point)),
          const SizedBox(height: 16),
          _PlaceField(
            controller: _originCtrl,
            label: 'Pickup',
            results: _originResults,
            onSearch: () => _searchPlace(_originCtrl, true),
            onPick: (place) => setState(() {
              _origin = place;
              _originCtrl.text = place.label;
              _originResults = [];
            }),
          ),
          const SizedBox(height: 12),
          _PlaceField(
            controller: _destinationCtrl,
            label: 'Drop-off',
            results: _destinationResults,
            onSearch: () => _searchPlace(_destinationCtrl, false),
            onPick: (place) => setState(() {
              _destination = place;
              _destinationCtrl.text = place.label;
              _destinationResults = [];
            }),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _findRides,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
            label: const Text('Search Rides'),
          ),
          const SizedBox(height: 16),
          ..._rides.map((ride) => Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: AppTheme.primary),
                  title: Text('${ride.originAddress} -> ${ride.destinationAddress}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${ride.distanceLabel} | ${ride.etaLabel} | ${ride.seatsAvailable} seats | Rs ${ride.pricePerSeat.toStringAsFixed(0)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(context, '/rides/detail', arguments: ride.id),
                ),
              )),
          if (!_loading && _rides.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text('No rides loaded yet.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _PlaceField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final List<PlaceSuggestion> results;
  final VoidCallback onSearch;
  final ValueChanged<PlaceSuggestion> onPick;

  const _PlaceField({
    required this.controller,
    required this.label,
    required this.results,
    required this.onSearch,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
            ),
            onSubmitted: (_) => onSearch(),
          ),
          ...results.take(4).map((place) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(place.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => onPick(place),
              )),
        ],
      );
}
