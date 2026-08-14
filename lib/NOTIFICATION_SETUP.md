# SRI NEWS notification patch

## Files
1. Replace `lib/main.dart` with `main.dart` from this patch.
2. Copy `services/notification_service.dart` to `lib/services/notification_service.dart`.
3. Ensure `pubspec.yaml` contains:
   `firebase_messaging`
   `flutter_local_notifications`
4. Deploy the `functions` folder with Firebase CLI.

## What it does
- Owner publishing a document under `news/{newsId}` automatically sends an FCM notification to topic `all_news`.
- App foreground: local notification is shown.
- App background/closed: FCM notification is shown by Android.
- Notification title: `SRI NEWS`.
- Body: `BREAKING • category • headline` for breaking news, otherwise `category • headline`.
- Android notification channel: `SRI NEWS`.

## Firebase deployment
From the project root:

    firebase init functions

Keep the existing Firebase project and use JavaScript/Node 20. Replace the generated `functions/index.js` and `functions/package.json` with the files in this patch, then:

    cd functions
    npm install
    cd ..
    firebase deploy --only functions:notifyNewNews

Important: Cloud Functions deployment generally requires the Firebase project to be on the Blaze billing plan. Do not paste service-account private keys into the Flutter app.
