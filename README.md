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
