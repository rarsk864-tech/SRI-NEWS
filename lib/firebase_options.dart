// Generated for the SRI News Firebase project.
// This file contains public Firebase app configuration values.
// Do not place server credentials or Admin SDK private keys in the app.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'SRI News starter is currently configured for Android only.',
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCr0VBqTqxVTudcnj7Rslkh0GraRHneTmc',
    appId: '1:921521114356:android:ced73f4077bdee335ea2a1',
    messagingSenderId: '921521114356',
    projectId: 'sri-news-34bde',
    storageBucket: 'sri-news-34bde.firebasestorage.app',
  );
}
