
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/admin_page.dart';
import 'services/auth_service.dart';

Future<void> _background(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_background);
  await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
  await FirebaseMessaging.instance.subscribeToTopic('all_news');
  runApp(const SriNewsApp());
}

class SriNewsApp extends StatelessWidget {
  const SriNewsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SRI NEWS',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD71920)),
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
    ),
    home: const HomePage(),
    routes: {
      '/admin': (_) => const AdminGate(),
    },
  );
}

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: AuthService().state,
    builder: (_, s) => s.hasData ? const AdminPage() : const LoginPage(),
  );
}
