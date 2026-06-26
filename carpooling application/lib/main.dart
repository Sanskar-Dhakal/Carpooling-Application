import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/driver/home/driver_home_screen.dart';
import 'features/passenger/home/passenger_home_screen.dart';
import 'features/admin/home/admin_home_screen.dart';
import 'features/admin/screens/admin_users_screen.dart';
import 'features/admin/screens/admin_withdrawals_screen.dart';
import 'features/admin/screens/admin_driver_withdrawals_screen.dart';

import 'features/admin/screens/admin_wallet_screen.dart';
import 'features/vehicles/screens/vehicle_setup_screen.dart';
import 'features/bookings/screens/my_bookings_screen.dart';
import 'features/bookings/screens/driver_booking_requests_screen.dart';
import 'features/payments/screens/wallet_screen.dart';
import 'features/payments/screens/qr_setup_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/edit_profile_screen.dart';
import 'features/profile/screens/settings_screen.dart';
import 'features/notifications/notification_handler.dart';
import 'features/rides/screens/find_ride_screen.dart';
import 'features/rides/screens/post_ride_screen.dart';

final _navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const webOptions = FirebaseOptions(
    apiKey: "AIzaSyB5Us1g8FJ_qH7rfjVgJVAP_ddKZtIVr34",
    authDomain: "vroom-squad.firebaseapp.com",
    projectId: "vroom-squad",
    appId: "1:1047074779085:web:1ebef6900f0da7780a1e84",
    messagingSenderId: "1047074779085",
  );
  try {
    await Firebase.initializeApp(
      options:
          const bool.fromEnvironment('dart.library.html') ? webOptions : null,
    );
    // M9: initialize FCM notification handler
    await NotificationHandler.initialize(_navigatorKey);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(VroomSquadApp(navigatorKey: _navigatorKey));
}

class VroomSquadApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const VroomSquadApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => AuthRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Vroom Squad',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),

            // Driver
            '/driver/home': (context) => const DriverHomeScreen(),
            '/driver/post-ride': (context) => const PostRideScreen(),
            '/driver/vehicles': (context) =>
                const VehicleSetupScreen(fromProfile: false),
            '/driver/vehicles/manage': (context) =>
                const VehicleSetupScreen(fromProfile: true),
            '/driver/requests': (context) =>
                const DriverBookingRequestsScreen(),
            '/driver/wallet': (context) => const WalletScreen(),
            '/driver/qr-setup': (context) => const QrSetupScreen(),
            '/driver/profile': (context) => const ProfileScreen(),

            // Passenger
            '/passenger/home': (context) => const PassengerHomeScreen(),
            '/passenger/find-ride': (context) => const FindRideScreen(),
            '/passenger/bookings': (context) => const MyBookingsScreen(),
            '/passenger/wallet': (context) => const WalletScreen(),
            '/passenger/profile': (context) => const ProfileScreen(),

            // Shared profile/settings
            '/profile': (context) => const ProfileScreen(),
            '/profile/edit': (context) => const EditProfileScreen(),
            '/settings': (context) => const SettingsScreen(),

            // Admin
            '/admin/home': (context) => const AdminHomeScreen(),
            '/admin/users': (context) => const AdminUsersScreen(),
            '/admin/withdrawals': (context) => const AdminWithdrawalsScreen(),
            '/admin/driver-withdrawals': (context) => const AdminDriverWithdrawalsScreen(),
            '/admin/wallet': (context) => const AdminWalletScreen(),
          },
        ),
      ),
    );
  }
}
