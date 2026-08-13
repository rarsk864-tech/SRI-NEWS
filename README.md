# SRI News — Phone Build Package

This package is prepared for building the Android APK from a phone using GitHub Actions.

## Phone-only steps

1. Create a new GitHub repository, for example `sri-news-app`.
2. Upload all files from this folder to the repository (including `.github/workflows/android-apk.yml`).
3. Open the repository in Chrome and go to **Actions**.
4. Select **Build SRI News APK**.
5. Tap **Run workflow**.
6. Wait for the workflow to finish.
7. Open the completed workflow run and download the artifact named **sri-news-release-apk**.
8. Extract the artifact ZIP and install `app-release.apk` on Android.

## Firebase already configured

The package uses the Firebase Android app package:
`com.srinews.app`

Firebase project:
`sri-news-34bde`

`google-services.json` is included for the configured Android app.

## Branding

- Android launcher name: **SRI NEWS**
- Custom SRI NEWS launcher icon included in `assets/sri_news_icon.png`
- GitHub Actions and Codemagic builds generate the launcher icon automatically

## Current features

- SRI News Home / Read screen
- Categories
- Firestore real-time news feed
- Firebase Authentication admin login
- Admin publish / edit / delete
- Breaking News flag
- FCM topic subscription

## Important

- Cloud Storage is not required for the current text/news-feed test.
- Do not commit Firebase Admin SDK private keys or service-account JSON files.
- The admin custom claim must be assigned from a trusted server/Admin SDK; never put an Admin SDK private key in the APK.
