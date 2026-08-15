
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final auth = FirebaseAuth.instance;
  Stream<User?> get state => auth.authStateChanges();

  Future<UserCredential> login(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> register(String email, String password, {String displayName = ''}) async {
    final credential = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (credential.user != null && displayName.trim().isNotEmpty) {
      await credential.user!.updateDisplayName(displayName.trim());
    }
    return credential;
  }

  Future<String?> currentRole() async {
    final user = auth.currentUser;
    if (user == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final role = (snap.data()?['role'] ?? '').toString().trim().toLowerCase();
    return role.isEmpty ? 'user' : role;
  }

  Future<bool> hasRole(String role) async {
    final current = await currentRole();
    return current == role.toLowerCase();
  }

  Future<void> logout() => auth.signOut();
}
