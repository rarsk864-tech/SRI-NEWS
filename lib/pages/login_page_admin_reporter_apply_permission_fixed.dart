import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_page.dart';
import 'owner_page.dart';
import 'reporter_page.dart';

enum LoginRole { owner, admin, reporter, user }

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.initialRole = LoginRole.user,
    this.initialApply = false,
  });

  final LoginRole initialRole;
  final bool initialApply;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();

  late LoginRole role;
  bool isApply = false;
  bool loading = false;
  bool showPassword = false;

  @override
  void initState() {
    super.initState();
    role = widget.initialRole;
    isApply = widget.initialApply;
  }

  String get roleLabel {
    switch (role) {
      case LoginRole.owner:
        return 'Owner';
      case LoginRole.admin:
        return 'Admin';
      case LoginRole.reporter:
        return 'Reporter';
      case LoginRole.user:
        return 'User';
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<Map<String, dynamic>> _userData(User user) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return snap.data() ?? {};
  }

  Future<void> _login() async {
    final e = email.text.trim();
    final p = password.text;

    if (e.isEmpty || p.isEmpty) {
      _message('Email and password are required.');
      return;
    }

    setState(() => loading = true);
    try {
      final credential = await AuthService().login(e, p);
      final user = credential.user;
      if (user == null) throw Exception('Login failed.');

      final data = await _userData(user);
      final storedRole =
          (data['role'] ?? 'user').toString().trim().toLowerCase();
      final reporterStatus =
          (data['reporterStatus'] ?? '').toString().trim().toLowerCase();

      bool allowed;
      switch (role) {
        case LoginRole.owner:
          allowed = storedRole == 'owner';
          break;
        case LoginRole.admin:
          allowed = storedRole == 'admin' || storedRole == 'administrator';
          break;
        case LoginRole.reporter:
          allowed = storedRole == 'reporter' || reporterStatus == 'approved';
          break;
        case LoginRole.user:
          allowed = storedRole == 'user';
          break;
      }

      if (!allowed) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not a $roleLabel account.');
      }

      if (!mounted) return;

      switch (role) {
        case LoginRole.owner:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OwnerPage()),
          );
          break;
        case LoginRole.admin:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminPage()),
          );
          break;
        case LoginRole.reporter:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ReporterPage()),
          );
          break;
        case LoginRole.user:
          Navigator.of(context).pop(true);
          break;
      }
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Login failed.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _apply() async {
    if (role != LoginRole.admin && role != LoginRole.reporter) {
      _message('Only Admin and Reporter applications are available.');
      return;
    }

    final applicantName = name.text.trim();
    final e = email.text.trim();
    final p = password.text;

    if (applicantName.isEmpty || e.isEmpty || p.isEmpty) {
      _message('Name, email and password are required.');
      return;
    }

    setState(() => loading = true);
    try {
      UserCredential credential;

      try {
        credential = await AuthService().login(e, p);
      } on FirebaseAuthException catch (ex) {
        if (ex.code != 'user-not-found' &&
            ex.code != 'invalid-credential' &&
            ex.code != 'wrong-password') {
          rethrow;
        }

        credential = await AuthService().register(
          e,
          p,
          displayName: applicantName,
        );
      }

      final user = credential.user;
      if (user == null) throw Exception('Unable to create/load account.');

      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final existing = await ref.get();
      final data = existing.data() ?? {};
      final currentRole =
          (data['role'] ?? 'user').toString().trim().toLowerCase();

      if (currentRole == 'owner' ||
          currentRole == 'admin' ||
          currentRole == 'administrator' ||
          currentRole == 'reporter' ||
          (data['reporterStatus'] ?? '').toString().toLowerCase() == 'approved') {
        throw Exception('This account already has an assigned role.');
      }

      // Keep the existing Firestore rules untouched.
      // For an existing USER document, only fields explicitly allowed
      // by firestore.rules are updated during an application.
      final update = <String, dynamic>{
        'name': applicantName,
        'displayName': applicantName,
      };

      if (role == LoginRole.admin) {
        update['adminStatus'] = 'pending';
        update['adminAppliedAt'] = FieldValue.serverTimestamp();
      } else {
        update['reporterStatus'] = 'pending';
        update['reporterAppliedAt'] = FieldValue.serverTimestamp();
      }

      await ref.set(update, SetOptions(merge: true));

      if (!mounted) return;
      _message(
        role == LoginRole.admin
            ? 'Admin application submitted. Owner approval required.'
            : 'Reporter application submitted. Owner approval required.',
      );
      setState(() => isApply = false);
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Application failed.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _roleButton(LoginRole value, String label, IconData icon) {
    final selected = role == value;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: loading ? null : () => setState(() => role = value),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? const Color(0xFFFFE7E3) : Colors.white,
          side: BorderSide(
            color: selected ? const Color(0xFFE60000) : Colors.black12,
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final applyAllowed =
        role == LoginRole.admin || role == LoginRole.reporter;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('SRI NEWS'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                color: Colors.white,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SRI NEWS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE60000),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isApply
                            ? 'Apply for a role'
                            : 'Login to your account',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _roleButton(
                            LoginRole.owner,
                            'Owner',
                            Icons.admin_panel_settings_outlined,
                          ),
                          const SizedBox(width: 8),
                          _roleButton(
                            LoginRole.admin,
                            'Admin',
                            Icons.verified_user_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _roleButton(
                            LoginRole.reporter,
                            'Reporter',
                            Icons.edit_note_outlined,
                          ),
                          const SizedBox(width: 8),
                          _roleButton(
                            LoginRole.user,
                            'User',
                            Icons.person_outline,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (applyAllowed)
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Login'),
                              icon: Icon(Icons.login_outlined),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Apply'),
                              icon: Icon(Icons.assignment_outlined),
                            ),
                          ],
                          selected: {isApply},
                          onSelectionChanged: loading
                              ? null
                              : (value) =>
                                  setState(() => isApply = value.first),
                        ),
                      if (!applyAllowed && isApply)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Apply is available only for Admin and Reporter.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      if (isApply) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: name,
                          enabled: !loading,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: email,
                        enabled: !loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        enabled: !loading,
                        obscureText: !showPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) {
                          if (!loading) {
                            isApply ? _apply() : _login();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip:
                                showPassword ? 'Hide password' : 'Show password',
                            onPressed: loading
                                ? null
                                : () => setState(
                                      () => showPassword = !showPassword,
                                    ),
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: loading
                            ? null
                            : (isApply ? _apply : _login),
                        child: Text(
                          loading
                              ? 'Please wait...'
                              : isApply
                                  ? 'Submit ${roleLabel} Application'
                                  : 'Login as $roleLabel',
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text(
                        'Why become an Admin?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Help manage news, review reporter submissions and support SRI NEWS operations.',
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Why become a Reporter?',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Submit news and breaking-news reports for Owner/Admin review and publication.',
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Application process',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Apply → Owner checks the application → Approve or Reject → Approved role gets access.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
