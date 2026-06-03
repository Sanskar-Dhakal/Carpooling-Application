import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/driver/home/driver_home_screen.dart'
    hide PassengerHomeScreen, AdminHomeScreen;
import 'features/passenger/home/passenger_home_screen.dart';
import 'features/admin/home/admin_home_screen.dart';
import 'features/bookings/screens/driver_booking_requests_screen.dart';
import 'features/bookings/screens/my_bookings_screen.dart';
import 'features/rides/screens/my_rides_screen.dart';
import 'features/rides/screens/post_ride_screen.dart';
import 'features/rides/screens/ride_detail_screen.dart';
import 'features/rides/screens/search_rides_screen.dart';
import 'features/payments/screens/admin_payments_screen.dart';
import 'features/payments/screens/wallet_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const VroomSquadApp());
}

class VroomSquadApp extends StatelessWidget {
  const VroomSquadApp({super.key});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => AuthRepository(),
      child: BlocProvider(
        create: (ctx) => AuthBloc(
          authRepository: ctx.read<AuthRepository>(),
        ),
        child: MaterialApp(
          title: 'Vroom Squad',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          initialRoute: '/',
          routes: {
            '/': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/driver/home': (_) => const DriverHomeScreen(),
            '/passenger/home': (_) => const PassengerHomeScreen(),
            '/admin/home': (_) => const AdminHomeScreen(),
            '/rides/post': (_) => const PostRideScreen(),
            '/rides/search': (_) => const SearchRidesScreen(),
            '/rides/my': (_) => const MyRidesScreen(),
            '/rides/detail': (context) => RideDetailScreen(
                  rideId: ModalRoute.of(context)!.settings.arguments as String,
                ),
            '/bookings/my': (_) => const MyBookingsScreen(),
            '/bookings/driver': (_) => const DriverBookingRequestsScreen(),
            '/wallet': (_) => const WalletScreen(),
            '/wallet/driver': (_) => const WalletScreen(driverMode: true),
            '/payments/admin': (_) => const AdminPaymentsScreen(),
          },
        ),
      ),
    );
  }
}
