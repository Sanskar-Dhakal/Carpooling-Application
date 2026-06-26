import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class VehicleSetupScreen extends StatefulWidget {
  final bool fromProfile;
  const VehicleSetupScreen({super.key, this.fromProfile = false});

  @override
  State<VehicleSetupScreen> createState() => _VehicleSetupScreenState();
}

class _VehicleSetupScreenState extends State<VehicleSetupScreen> {
  static const _storage = FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  String _type = 'Car';
  bool _loading = false;
  List<Map<String, dynamic>> _vehicles = [];

  static const _types = ['Car', 'Van', 'Motorbike', 'Microbus'];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    try {
      final data = await ApiService.get('/vehicles/mine');
      setState(() => _vehicles = List<Map<String, dynamic>>.from(data['vehicles'] ?? []));
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.post('/vehicles', {
        'vehicleNumber': _numberCtrl.text.trim().toUpperCase(),
        'type': _type,
        'capacity': int.parse(_capacityCtrl.text.trim()),
      });
      _numberCtrl.clear();
      _capacityCtrl.clear();
      setState(() => _type = 'Car');
      await _loadVehicles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle added!'), backgroundColor: AppTheme.success),
        );
        if (!widget.fromProfile && _vehicles.isNotEmpty) {
          Navigator.pushReplacementNamed(context, '/driver/home');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      final token = await _storage.read(key: AppConstants.tokenKey);
      await http.delete(
        Uri.parse('${AppConstants.baseUrl}/vehicles/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      await _loadVehicles();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Vehicles'),
        backgroundColor: AppTheme.driverColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.fromProfile) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.driverColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.driverColor.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.driverColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please add at least one vehicle before posting rides.',
                        style: TextStyle(color: AppTheme.driverColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text('Add Vehicle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _numberCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: _inputDec('Vehicle Details', Icons.confirmation_number_outlined),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: _type,
                    decoration: _inputDec('Vehicle Type', Icons.directions_car_outlined),
                    items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDec('Seat Capacity', Icons.event_seat_outlined),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 20) return 'Enter 1–20';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _submit,
                      icon: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.add),
                      label: const Text('Add Vehicle'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.driverColor),
                    ),
                  ),
                ],
              ),
            ),
            if (_vehicles.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Your Vehicles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              ..._vehicles.map((v) => _VehicleCard(vehicle: v, onDelete: () => _delete(v['id']))),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      );
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onDelete;
  const _VehicleCard({required this.vehicle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.driverColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.directions_car, color: AppTheme.driverColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(vehicle['vehicleNumber'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text('${vehicle['type']} · ${vehicle['capacity']} seats',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
