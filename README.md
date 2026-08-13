# SRI NEWS

SRI NEWS Flutter + Firebase news application.

## News interactions
- Share news from cards and article details using the device share sheet.
- Like/unlike news with a per-user Firestore record and live counts.
- Commenting requires a logged-in user.
- New users can create an account from the comment login prompt.
- Comments are stored under each news item and update live.

## Firebase
Enable Email/Password sign-in in Firebase Authentication before using user login/comments.
Deploy `firestore.rules` after enabling Firestore.


## Hidden Owner Login
The Owner/Admin login is intentionally not shown anywhere in the normal user UI. To open it, tap the red **SRI** logo in the Home header **7 times within 2 seconds**. The app then opens the protected Admin route. Firebase ID token claim `admin == true` is required; non-owner accounts are rejected.
