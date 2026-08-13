
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> logout() => auth.signOut();
}
