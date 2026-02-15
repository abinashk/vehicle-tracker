import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles Firebase Cloud Messaging and local notification display.
///
/// Sets up FCM token registration and handles incoming push notifications
/// by displaying them as local notifications when the app is in the foreground.
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;

  /// Android notification channel for violation alerts.
  static const AndroidNotificationChannel violationChannel =
      AndroidNotificationChannel(
    'violation_alerts',
    'Violation Alerts',
    description: 'Alerts when vehicle violations are detected',
    importance: Importance.high,
    playSound: true,
  );

  /// Android notification channel for sync status.
  static const AndroidNotificationChannel syncChannel =
      AndroidNotificationChannel(
    'sync_status',
    'Sync Status',
    description: 'Background sync status notifications',
    importance: Importance.low,
  );

  /// Initialize the notification service.
  ///
  /// Requests permissions, configures local notifications, and sets up
  /// foreground message handling.
  Future<void> initialize() async {
    // Request notification permissions.
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(initSettings);

    // Create notification channels on Android.
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(violationChannel);
      await androidPlugin.createNotificationChannel(syncChannel);
    }

    // Listen for foreground messages and display them locally.
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Get the FCM token for server registration.
    await _messaging.getToken();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          violationChannel.id,
          violationChannel.name,
          channelDescription: violationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Show a local violation alert notification.
  Future<void> showViolationAlert({
    required String title,
    required String body,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          violationChannel.id,
          violationChannel.name,
          channelDescription: violationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Dispose resources.
  void dispose() {
    _foregroundSubscription?.cancel();
  }
}

/// Provider for the notification service.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});
