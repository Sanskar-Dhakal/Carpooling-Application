import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/app_constants.dart';

/// Background message handler — must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handling — no UI updates here
  debugPrint('BG message: ${message.messageId}');
}

class NotificationHandler {
  static final _fcm = FirebaseMessaging.instance;

  /// Call once from main() after Firebase.initializeApp()
  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Register FCM token with backend
    final token = await _fcm.getToken();
    if (token != null) await _sendTokenToBackend(token);

    // Refresh handler
    _fcm.onTokenRefresh.listen((newToken) => _sendTokenToBackend(newToken));

    // Foreground messages — show in-app toast
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? '';
      final body  = message.notification?.body  ?? '';
      Fluttertoast.showToast(
        msg: '$title: $body',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
      );
    });

    // Background → foreground tap: route to correct screen
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message.data, navigatorKey);
    });

    // App opened from terminated via notification
    final initial = await _fcm.getInitialMessage();
    if (initial != null) {
      _handleTap(initial.data, navigatorKey);
    }
  }

  static Future<void> _sendTokenToBackend(String token) async {
    try {
      const storage = FlutterSecureStorage();
      final saved = await storage.read(key: AppConstants.tokenKey);
      if (saved != null) {
        await ApiService.put('/users/fcm-token', {'token': token});
      }
    } catch (_) {}
  }

  /// Route user to the correct screen based on notification type
  static void _handleTap(Map<String, dynamic> data,
      GlobalKey<NavigatorState> navigatorKey) {
    final type = data['type'] as String?;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'booking_status':
        nav.pushNamed('/passenger/bookings');
        break;
      case 'trip_started':
      case 'trip_completed':
        nav.pushNamed('/passenger/bookings');
        break;
      case 'ride_cancelled':
        nav.pushNamed('/passenger/bookings');
        break;
      case 'new_message':
        // Could route to specific chat; push to bookings as fallback
        nav.pushNamed('/passenger/bookings');
        break;
      case 'withdrawal_approved':
        nav.pushNamed('/driver/wallet');
        break;
      case 'wallet_credited':
        nav.pushNamed('/driver/wallet');
        break;
      case 'account_verified':
        nav.pushNamed('/driver/home');
        break;
      case 'verification_request':
        nav.pushNamed('/admin/home');
        break;
      default:
        break;
    }
  }
}
