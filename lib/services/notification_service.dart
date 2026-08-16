import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SriNewsNotification {
  final String title;
  final String body;
  final String? newsId;

  const SriNewsNotification({
    required this.title,
    required this.body,
    this.newsId,
  });
}

class NotificationService {
  static final List<SriNewsNotification> notifications = <SriNewsNotification>[];
  static final List<VoidCallback> _listeners = <VoidCallback>[];

  static void addListener(VoidCallback listener) => _listeners.add(listener);

  static void removeListener(VoidCallback listener) => _listeners.remove(listener);

  static void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      listener();
    }
  }

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

    await _plugin.initialize(settings: settings);

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
    final newsId = message.data['newsId']?.toString();

    notifications.insert(
      0,
      SriNewsNotification(
        title: title,
        body: body,
        newsId: newsId,
      ),
    );
    if (notifications.length > 50) {
      notifications.removeLast();
    }
    _notifyListeners();

    await _plugin.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
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
