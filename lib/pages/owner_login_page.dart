import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'owner_page.dart';

const _ownerLoginBg = Color(0xFFF7F8FA);
const _ownerLoginRed = Color(0xFF9E5048);

class OwnerLoginPage extends StatefulWidget {
  const OwnerLoginPage({super.key});

  @override
  State<OwnerLoginPage> createState() => _OwnerLoginPageState();
}

class _OwnerLoginPageState extends State<OwnerLoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _checkOwner(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) return false;

    final data = doc.data() ?? {};
    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final storedUid = (data['uid'] ?? '').toString().trim();

    return role == 'owner' &&
        (storedUid.isEmpty || storedUid == user.uid);
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _message('Email and password are required.');
      return;
    }

    setState(() => loading = true);

    try {
      // Remove any currently signed-in normal/reporter account first.
      await FirebaseAuth.instance.signOut();

      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw Exception('Owner account could not be loaded.');
      }

      final isOwner = await _checkOwner(user);

      if (!isOwner) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not an Owner account.');
      }

      if (!mounted) return;

      // Open dashboard only after the Firestore owner check succeeds.
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OwnerPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Owner login failed.');
    } on FirebaseException catch (e) {
      _message(e.message ?? 'Unable to verify Owner account.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ownerLoginBg,
      appBar: AppBar(
        title: const Text('Owner Login'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF241B1B),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Card(
              elevation: 1,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 58,
                      color: _ownerLoginRed,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'SRI NEWS Owner',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in with the registered Owner account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: emailController,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Owner Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: passwordController,
                      enabled: !loading,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!loading) _login();
                      },
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: loading
                              ? null
                              : () => setState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: loading ? null : _login,
                        icon: loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                        label: Text(
                          loading ? 'Checking...' : 'Owner Login',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _ownerLoginRed,
                        ),
                      ),
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
