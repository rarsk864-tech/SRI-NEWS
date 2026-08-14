import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'sri_news_channel',
    'SRI NEWS',
    description: 'SRI NEWS breaking and latest news notifications',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> showFromMessage(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ?? 'SRI NEWS';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['headline']?.toString() ??
        'కొత్త వార్త అందుబాటులో ఉంది';

    await _plugin.show(
      message.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'sri_news_channel',
          'SRI NEWS',
          channelDescription: 'SRI NEWS breaking and latest news notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['newsId']?.toString(),
    );
  }
}
