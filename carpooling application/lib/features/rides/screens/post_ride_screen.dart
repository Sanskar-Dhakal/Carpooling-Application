import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ride_model.dart';
import '../repository/rides_repository.dart';
import '../widgets/route_map.dart';

class PostRideScreen extends StatefulWidget {
  const PostRideScreen({super.key});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  final _repo = RidesRepository();
  final _originCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _seatsCtrl = TextEditingController(text: '2');
  final _priceCtrl = TextEditingController(text: '300');
  DateTime _departure = DateTime.now().add(const Duration(hours: 1));
  PlaceSuggestion? _origin;
  PlaceSuggestion? _destination;
  List<PlaceSuggestion> _originResults = [];
  List<PlaceSuggestion> _destinationResults = [];
  bool _loading = false;
  final Map<String, bool> _preferences = {
    'No smoking': true,
    'Music ok': true,
    'Pets ok': false,
  };

  Future<void> _search(TextEditingController ctrl, bool isOrigin) async {
    if (ctrl.text.trim().length < 2) return;
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

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departure,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_departure));
    if (time == null) return;
    setState(() => _departure = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  void dispose() {
    _originCtrl.dispose();
    _destinationCtrl.dispose();
    _seatsCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_origin == null || _destination == null) {
      _show('Choose origin and destination from search results');
      return;
    }
    setState(() => _loading = true);
    try {
      final ride = await _repo.postRide(
        origin: _origin!,
        destination: _destination!,
        departureTime: _departure,
        seats: int.tryParse(_seatsCtrl.text) ?? 1,
        price: double.tryParse(_priceCtrl.text) ?? 0,
        preferences: _preferences,
      );
      if (!mounted) return;
      _show('Ride posted');
      Navigator.pushReplacementNamed(context, '/rides/detail', arguments: ride.id);
    } catch (e) {
      _show(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message.replaceFirst('Exception: ', ''))));
  }

  @override
  Widget build(BuildContext context) {
    final route = [
      if (_origin != null) _origin!.point,
      if (_destination != null) _destination!.point,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Post a Ride'), backgroundColor: AppTheme.driverColor),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(height: 220, child: RouteMap(route: route, origin: _origin?.point, destination: _destination?.point)),
          const SizedBox(height: 16),
          _PlaceField(
            controller: _originCtrl,
            label: 'Origin',
            results: _originResults,
            onSearch: () => _search(_originCtrl, true),
            onPick: (place) => setState(() {
              _origin = place;
              _originCtrl.text = place.label;
              _originResults = [];
            }),
          ),
          const SizedBox(height: 12),
          _PlaceField(
            controller: _destinationCtrl,
            label: 'Destination',
            results: _destinationResults,
            onSearch: () => _search(_destinationCtrl, false),
            onPick: (place) => setState(() {
              _destination = place;
              _destinationCtrl.text = place.label;
              _destinationResults = [];
            }),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _seatsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Seats'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: _priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price per seat'))),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule),
            label: Text('${_departure.year}-${_departure.month.toString().padLeft(2, '0')}-${_departure.day.toString().padLeft(2, '0')} ${_departure.hour.toString().padLeft(2, '0')}:${_departure.minute.toString().padLeft(2, '0')}'),
          ),
          const SizedBox(height: 8),
          ..._preferences.keys.map((key) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(key),
                value: _preferences[key]!,
                onChanged: (value) => setState(() => _preferences[key] = value),
              )),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_road),
            label: const Text('Post Ride'),
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
