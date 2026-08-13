import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Every installation receives notifications sent to this topic.
    await _messaging.subscribeToTopic('all_news');

    FirebaseMessaging.onMessage.listen((message) {
      // When the app is in the foreground, Android does not automatically
      // display the notification banner. The message is still delivered here.
      // Background/terminated notification display is handled by FCM.
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      // Ready for news deep-link navigation.
    });

    await _messaging.getInitialMessage();
  }

  Future<String?> token() => _messaging.getToken();

  Future<void> subscribeToNews() =>
      _messaging.subscribeToTopic('all_news');

  Future<void> unsubscribeFromNews() =>
      _messaging.unsubscribeFromTopic('all_news');

  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
