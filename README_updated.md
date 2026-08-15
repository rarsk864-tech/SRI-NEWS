# SRI NEWS

SRI NEWS is a Flutter + Firebase news application designed to provide a complete news-reading and news-management platform.

## What is SRI NEWS?

SRI NEWS allows normal users to read and interact with news while authorized reporters can submit news for publication. Admins and the Owner manage users, reporters, news, approvals, and other administrative functions.

The application is divided into two main areas:

- **User side** — for reading and interacting with published news.
- **Management side** — for Owner, Admin, and Reporter operations.

---

# Users and Roles

SRI NEWS has four main roles:

## 1. User

A normal registered user can:

- Create an account and log in.
- Browse published news.
- Read complete news articles.
- Explore news by category.
- Like and unlike news.
- Comment on news.
- Share news using the device share sheet.
- Manage their normal user account through the available app features.

Users do not have access to Owner/Admin management functions.

## 2. Reporter

A Reporter is a user who is authorized to submit news.

Reporter workflow:

1. A person applies/request access to become a Reporter.
2. The Owner or Admin reviews the Reporter application.
3. The application can be approved or rejected.
4. Only an approved Reporter receives Reporter access.
5. An approved Reporter can create and submit news.
6. Submitted news can go through the required Owner/Admin review and approval process before publication.

Reporter access can be removed by the Owner/Admin when required.

## 3. Admin

The Admin manages the application from the management side.

Admin responsibilities can include:

- Managing users.
- Managing Reporter applications.
- Approving or rejecting Reporters.
- Removing Reporter access when required.
- Reviewing submitted news.
- Approving news for publication.
- Managing available app content and administrative data.
- Using the available administrative editing/management controls.

Admin does not operate as a normal news reader when using the protected management area; the Admin has management privileges according to the configured Firebase permissions.

## 4. Owner

The Owner has the highest level of application management.

Owner responsibilities can include:

- Managing users.
- Managing Admins.
- Managing Reporters.
- Approving or rejecting Reporter applications.
- Removing Reporter access.
- Reviewing, editing, approving, or managing submitted news.
- Managing application-level administration.
- Monitoring the overall user/role structure.
- Performing Owner-level management operations.

The exact actions available to Admin and Owner are controlled by the application's authentication and Firestore security configuration.

---

# How SRI NEWS Works

The basic news lifecycle is:

**Reporter Application**
→ **Owner/Admin Review**
→ **Reporter Approval**
→ **Reporter Access**
→ **News Submission**
→ **Owner/Admin Review**
→ **News Approval**
→ **Published News**
→ **Users Read and Interact**

This keeps submitted content under management review before it becomes published news.

---

# User News Experience

The normal user flow is:

**Open SRI NEWS**
→ **Home**
→ **Browse News**
→ **Explore Categories**
→ **Open News**
→ **Read Article**
→ **Like / Comment / Share**

## News interactions

- Share news from cards and article details using the device share sheet.
- Like/unlike news with a per-user Firestore record and live counts.
- Commenting requires a logged-in user.
- New users can create an account from the comment login prompt.
- Comments are stored under each news item and update live.

These existing interactions are part of the SRI NEWS user experience.

---

# News Categories and Content

SRI NEWS can organize news into categories so users can discover different types of content.

The application can contain categories such as:

- Latest News
- National
- International
- State
- Politics
- Crime
- Business
- Sports
- Cinema / Entertainment
- Technology
- Health
- Education
- Lifestyle
- Astrology / Rashi Phalalu
- Other categories configured by the application

The exact categories shown in the running application depend on the category data configured for the project.

---

# News Posting and Approval

## Reporter

An approved Reporter can submit a news item with the information supported by the application, such as:

- News title
- News description/content
- Category
- Image/media
- Other available news fields

After submission, the news can remain pending until an authorized Admin or Owner reviews it.

## Admin / Owner

The management side can review submitted news and decide whether it should be approved for publication.

Possible workflow:

- **Pending** — submitted and waiting for review.
- **Approved** — accepted for publication.
- **Rejected** — not accepted for publication.
- **Published** — approved news visible to normal users.

---

# User Accounts

Users can create accounts through Firebase Authentication.

A logged-in user can use authenticated features such as commenting.

The application uses role information to determine whether an account is:

- User
- Reporter
- Admin
- Owner

Privileged functions should only be available to accounts that have the required role/permissions.

---

# Firebase

SRI NEWS uses Firebase as its backend.

## Firebase Authentication

Authentication is used for:

- User registration.
- User login.
- Protected account access.
- Reporter/Admin/Owner authentication and authorization.

Enable Email/Password sign-in in Firebase Authentication before using user login/comments.

## Cloud Firestore

Firestore stores application data such as:

- User accounts/profile information.
- Roles and permissions-related data.
- Reporter applications.
- News/posts.
- News categories.
- Likes.
- Comments.
- Other application management data.

Like/unlike data is stored per user in Firestore and live counts are displayed.

Comments are stored under each news item and update live.

## Firestore Security Rules

Firestore Security Rules control which users can read or write different types of data.

The rules should protect:

- User data.
- Reporter access.
- Admin operations.
- Owner operations.
- News submission.
- News approval.
- Likes.
- Comments.

Deploy `firestore.rules` after enabling Firestore.

---

# Role and Permission Model

A simplified permission model is:

| Role | Read Published News | Like / Share | Comment | Submit News | Approve Reporter | Manage Users | Manage Admins |
|---|---|---|---|---|---|---|---|
| User | Yes | Yes | Yes, when logged in | No | No | No | No |
| Reporter | Yes | Yes | Yes, when logged in | Yes, after approval | No | No | No |
| Admin | Yes | Yes | Yes | Management access as configured | Yes | Yes | According to rules |
| Owner | Yes | Yes | Yes | Management access | Yes | Yes | Yes |

The final permissions are determined by the application's Firebase Authentication and Firestore Rules configuration.

---

# Protected Owner/Admin Login

The Owner/Admin login is intentionally not shown anywhere in the normal user UI.

To open the protected Admin route, tap the red **SRI** logo in the Home header **7 times within 2 seconds**.

Firebase ID token claim `admin == true` is required for the protected route, and non-owner/non-authorized accounts are rejected according to the application's configured authorization logic.

---

# Management Side

The management area is intended for authorized accounts.

## Owner Management

The Owner can manage the overall application and its users/roles, including:

- Users
- Admins
- Reporters
- Reporter approvals/rejections
- Reporter access removal
- Submitted news
- News approval
- Available management controls

## Admin Management

The Admin can manage the functions granted by the application's security rules, including:

- Users
- Reporters
- Reporter approvals/rejections
- Submitted news
- News approval
- Administrative content management

## Reporter Management

Reporter access follows an approval-based model. A Reporter should not be able to submit content as an authorized Reporter until the Reporter account has been approved.

---

# Content Safety and Review Flow

The management workflow is designed so that Reporter-submitted content can be reviewed before publication.

**Reporter submits**
→ **Pending**
→ **Admin/Owner reviews**
→ **Approve or Reject**
→ **Approved content becomes publishable**

This provides a controlled publishing workflow rather than allowing every normal user to publish directly.

---

# Application Structure

A typical SRI NEWS structure contains:

- Home page
- News cards
- News detail/article page
- Explore/categories
- User login/register
- Comment system
- Reporter area
- Admin area
- Owner area
- Firebase Authentication
- Cloud Firestore
- Firestore Security Rules

The exact screens and file structure depend on the current Flutter project implementation.

---

# Main App Flow

```text
                         SRI NEWS
                            |
              +-------------+-------------+
              |                           |
          USER SIDE                 MANAGEMENT SIDE
              |                           |
          Home / News              Owner / Admin / Reporter
              |                           |
      Explore / Categories        Role-based access
              |                           |
        News Details              Reporter approval
              |                           |
     Like / Comment / Share       News review
                                          |
                                    Publish / Reject
```

---

# Data Flow

```text
User
  |
  +--> Firebase Authentication
  |
  +--> Published News
  |       |
  |       +--> Like
  |       +--> Comment
  |       +--> Share
  |
Reporter
  |
  +--> Reporter Application
          |
          +--> Owner/Admin Approval
                    |
                    +--> Reporter Access
                              |
                              +--> News Submission
                                        |
                                        +--> Owner/Admin Review
                                                  |
                                                  +--> Published News

Owner/Admin
  |
  +--> Users
  +--> Reporters
  +--> News
  +--> Approvals
  +--> Management
```

---

# Security Principles

SRI NEWS should follow these principles:

1. Normal users must not access protected management functions.
2. Reporter access must depend on approval.
3. Reporter news submissions must be controlled by Firestore permissions.
4. Only authorized Admin/Owner accounts should approve or reject Reporter applications.
5. Only authorized management accounts should approve content for publication.
6. Firestore Security Rules should enforce permissions on the backend rather than relying only on UI restrictions.
7. Firebase Authentication should be enabled for protected user functionality.

---

# Firebase Setup

Before using the application:

1. Create/configure the Firebase project.
2. Add the Flutter application to Firebase.
3. Enable Firebase Authentication.
4. Enable Email/Password sign-in.
5. Enable Cloud Firestore.
6. Deploy the project's `firestore.rules`.
7. Configure the required role/authorization data.
8. Run the Flutter application.

---

# Project Goal

The goal of SRI NEWS is to provide a complete news platform where:

- Users can easily discover and read news.
- Users can interact with published news.
- Reporters can submit news after receiving authorization.
- Admins can manage the application and review content.
- The Owner has overall control of users, roles, reporters, and publishing.
- Firebase provides authentication, database storage, live updates, and backend security.

---

# Important

The exact features, categories, screens, permissions, and Firestore field names are determined by the current Flutter source code and Firebase configuration.

This README describes the intended SRI NEWS application structure and workflow. Any feature not implemented in the current source code still needs to be implemented in the corresponding Flutter/Firebase files.

