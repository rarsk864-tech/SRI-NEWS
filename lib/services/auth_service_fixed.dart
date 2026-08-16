import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore db = FirebaseFirestore.instance;

  /// Firebase Auth state only.
  /// User document creation is handled explicitly by register/login,
  /// so the auth-state listener does not race with Firestore writes.
  Stream<User?> get state => auth.authStateChanges();

  /// Creates the Firestore profile for the signed-in user if it does not exist.
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

  Future<UserCredential> login(
    String email,
    String password,
  ) async {
    final credential = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await _ensureUserDocument(user);
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

    final user = credential.user;

    if (user != null && displayName.trim().isNotEmpty) {
      await user.updateDisplayName(displayName.trim());
    }

    if (user != null) {
      await _ensureUserDocument(user);
    }

    return credential;
  }

  Future<void> logout() => auth.signOut();
}
