
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);
    try {
      await AuthService().login(email.text, pass.text);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid admin login')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(children: [
          const Text('SRI News', style: TextStyle(
            fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFFD71920))),
          const Text('Admin Login'),
          const SizedBox(height: 28),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: pass, obscureText: true,
            decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: loading ? null : login,
            child: Text(loading ? 'Signing in...' : 'Sign in'),
          )),
        ]),
      ),
    )),
  );
}
