import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;

  Stream<User?> get state => auth.authStateChanges().asyncMap((user) async {
        if (user != null) {
          await _ensureUserDocument(user);
        }
        return user;
      });

  Future<void> _ensureUserDocument(User user) async {
    final ref = db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'role': 'user',
        'roleLabel': 'USER',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<UserCredential> login(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user != null) {
      await _ensureUserDocument(credential.user!);
    }

    return credential;
  }

  Future<UserCredential> register(
    String email,
    String password, {
    String displayName = '',
  }) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if (credential.user != null && displayName.trim().isNotEmpty) {
      await credential.user!.updateDisplayName(displayName.trim());
    }

    if (credential.user != null) {
      await _ensureUserDocument(credential.user!);
    }

    return credential;
  }

  Future<void> logout() => auth.signOut();
}
