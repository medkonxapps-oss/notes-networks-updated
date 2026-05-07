import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

// ── Local Notifications Setup ─────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'notesnet_high_importance', // id
  'NotesNet Notifications', // name
  description: 'Notifications for likes, saves, and followers',
  importance: Importance.high,
);

Future<void> _initLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await _localNotifications.initialize(settings: initSettings);

  // Create the high-importance channel for Android
  await _localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
}

void _showLocalNotification(RemoteMessage message) {
  final notification = message.notification;
  final android = message.notification?.android;

  if (notification != null && !kIsWeb) {
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class NotificationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  NotificationNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> init() async {
    // Skip on desktop platforms
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return;

    // Initialize local notifications plugin (needed for foreground display)
    await _initLocalNotifications();

    final messaging = FirebaseMessaging.instance;

    // 1. Request Permission
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // 2. Get FCM Token
      final token = await messaging.getToken();
      if (token != null) {
        await _saveToken(token);
      }

      // 3. Listen for Token Refresh
      messaging.onTokenRefresh.listen(_saveToken);

      // 4. Handle FOREGROUND messages — show local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔔 Foreground FCM: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 5. Handle notification tap when app is in background (not terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Notification tapped (background): ${message.data}');
        // TODO: Navigate to the relevant screen based on message.data['type']
      });

      // 6. Handle notification tap when app was terminated
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 App opened from terminated via notification: ${initialMessage.data}');
        // TODO: Navigate to the relevant screen
      }
    } else {
      debugPrint('⚠️ FCM permission denied: ${settings.authorizationStatus}');
    }
  }

  Future<void> _saveToken(String token) async {
    final client = _ref.read(supabaseClientProvider);
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    try {
      await client.from('users').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid);
      debugPrint('✅ FCM token saved to Supabase');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }
}

final pushNotificationProvider =
    StateNotifierProvider<NotificationNotifier, AsyncValue<void>>((ref) {
  return NotificationNotifier(ref);
});
