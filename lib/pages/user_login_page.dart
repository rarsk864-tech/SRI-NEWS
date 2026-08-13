import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool createAccount = false;
  bool loading = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    try {
      UserCredential result;
      if (createAccount) {
        result = await AuthService().register(
          email.text,
          password.text,
          displayName: name.text,
        );
      } else {
        result = await AuthService().login(email.text, password.text);
      }
      if (mounted) Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Email లేదా password తప్పుగా ఉంది.',
        'email-already-in-use' => 'ఈ email ఇప్పటికే ఉపయోగంలో ఉంది.',
        'weak-password' => 'Password కనీసం 6 characters ఉండాలి.',
        'invalid-email' => 'సరైన email ఇవ్వండి.',
        _ => e.message ?? 'Login failed. మళ్లీ ప్రయత్నించండి.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('SRI NEWS'),
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: Colors.white,
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Login required',
                      style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text('Comment చేయడానికి ముందుగా login అవ్వండి.'),
                    const SizedBox(height: 22),
                    if (createAccount) ...[
                      TextField(
                        controller: name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'పేరు'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: loading ? null : submit,
                      child: Text(loading
                          ? 'Please wait...'
                          : createAccount ? 'Create account' : 'Login'),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => setState(() => createAccount = !createAccount),
                      child: Text(createAccount
                          ? 'Already have an account? Login'
                          : 'New user? Create account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
