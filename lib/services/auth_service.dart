
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final auth = FirebaseAuth.instance;
  Stream<User?> get state => auth.authStateChanges();

  Future<void> login(String email, String password) =>
      auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> logout() => auth.signOut();
}
