import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/ride_model.dart';
import '../repository/rides_repository.dart';

class MyRidesScreen extends StatefulWidget {
  const MyRidesScreen({super.key});

  @override
  State<MyRidesScreen> createState() => _MyRidesScreenState();
}

class _MyRidesScreenState extends State<MyRidesScreen> {
  final _repo = RidesRepository();
  late Future<List<RideModel>> _rides;

  @override
  void initState() {
    super.initState();
    _rides = _repo.myRides();
  }

  void _reload() => setState(() => _rides = _repo.myRides());

  Future<void> _setStatus(RideModel ride, String status) async {
    await _repo.updateStatus(ride.id, status);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rides'), backgroundColor: AppTheme.driverColor),
      body: FutureBuilder<List<RideModel>>(
        future: _rides,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString().replaceFirst('Exception: ', '')));
          }
          final rides = snapshot.data!;
          if (rides.isEmpty) return const Center(child: Text('No rides posted yet.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rides.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final ride = rides[index];
              return Card(
                child: ListTile(
                  title: Text('${ride.originAddress} -> ${ride.destinationAddress}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${ride.status} | ${ride.seatsAvailable} seats | ${ride.departureTime.toLocal().toString().substring(0, 16)}'),
                  onTap: () => Navigator.pushNamed(context, '/rides/detail', arguments: ride.id),
                  trailing: PopupMenuButton<String>(
                    onSelected: (status) => _setStatus(ride, status),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'active', child: Text('Mark active')),
                      PopupMenuItem(value: 'completed', child: Text('Mark completed')),
                      PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
