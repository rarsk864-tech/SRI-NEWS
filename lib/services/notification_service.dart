import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'sri_news_breaking',
    'SRI NEWS Notifications',
    description: 'Breaking news and important SRI NEWS alerts.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _messaging.subscribeToTopic('all_news');

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleMessageTap(initial);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title?.trim().isNotEmpty == true
        ? notification!.title!
        : (data['title']?.toString().trim().isNotEmpty == true
            ? data['title'].toString()
            : 'SRI NEWS');

    final body = notification?.body?.trim().isNotEmpty == true
        ? notification!.body!
        : (data['body']?.toString().trim().isNotEmpty == true
            ? data['body'].toString()
            : 'తాజా వార్త వచ్చింది');

    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sri_news_breaking',
          'SRI NEWS Notifications',
          channelDescription:
              'Breaking news and important SRI NEWS alerts.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    // HomePage is already the main app page. Keeping this handler here
    // makes notification taps safe and ready for deep-link navigation.
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    // Reserved for opening a specific news item from notification payload.
  }

  Future<String?> token() => _messaging.getToken();

  Future<void> subscribeToNews() =>
      _messaging.subscribeToTopic('all_news');

  Future<void> unsubscribeFromNews() =>
      _messaging.unsubscribeFromTopic('all_news');

  static Future<void> backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
