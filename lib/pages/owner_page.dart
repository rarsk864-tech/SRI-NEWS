import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const _ownerRed = Color(0xFFE60000);
const _ownerBg = Color(0xFFF7F8FA);

class OwnerPage extends StatefulWidget {
  const OwnerPage({super.key});

  @override
  State<OwnerPage> createState() => _OwnerPageState();
}

class _OwnerPageState extends State<OwnerPage> {
  final db = FirebaseFirestore.instance;

  bool loading = false;

  Future<bool> _isOwner() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snap = await db.collection('users').doc(user.uid).get();
    return (snap.data()?['role'] ?? '').toString() == 'owner';
  }

  Future<void> _ownerLogin() async {
    final email = TextEditingController();
    final password = TextEditingController();

    final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Owner Login'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Owner Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Login'),
              ),
            ],
          ),
        ) ??
        false;

    if (!proceed) {
      email.dispose();
      password.dispose();
      return;
    }

    if (email.text.trim().isEmpty || password.text.isEmpty) {
      email.dispose();
      password.dispose();
      _message('Email and password are required.');
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );

      final ok = await _isOwner();
      if (!ok) {
        await FirebaseAuth.instance.signOut();
        throw Exception('This account is not an Owner account.');
      }

      if (mounted) setState(() {});
    } on FirebaseAuthException catch (e) {
      _message(e.message ?? 'Owner login failed.');
    } catch (e) {
      _message(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      email.dispose();
      password.dispose();
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _setReporterStatus(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    try {
      await doc.reference.update({
        'reporterStatus': status,
        if (status == 'approved') 'role': 'reporter',
        if (status == 'rejected') 'role': 'user',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });

      _message(
        status == 'approved'
            ? 'Reporter approved.'
            : 'Reporter rejected.',
      );
    } catch (e) {
      _message('Reporter update failed: $e');
    }
  }

  Future<void> _approvePost(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final p = doc.data() ?? {};

      final title = (p['title'] ?? '').toString().trim();
      final content = (p['content'] ?? '').toString().trim();
      final category = (p['category'] ?? 'దేశం').toString();
      final imageUrl = (p['mediaUrl'] ?? '').toString();
      final reporterId = (p['reporterId'] ?? '').toString();
      final reporterName = (p['reporterName'] ?? 'Reporter').toString();

      if (title.isEmpty || content.isEmpty) {
        throw Exception('Title and content are required.');
      }

      // Publish the approved reporter post to the same news collection
      // consumed by NewsService.
      final newsRef = db.collection('news').doc();

      await newsRef.set({
        'category': category,
        'title': title,
        'description': content,
        'content': content,
        'imageUrl': imageUrl,
        'time': _timeNow(),
        'publishedAt': FieldValue.serverTimestamp(),
        'breaking': false,
        'source': 'reporter',
        'reporterId': reporterId,
        'reporterName': reporterName,
        'approvedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      await doc.reference.update({
        'status': 'approved',
        'approvedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'approvedAt': FieldValue.serverTimestamp(),
        'publishedNewsId': newsRef.id,
      });

      _message('Post approved and published.');
    } catch (e) {
      _message('Post approval failed: $e');
    }
  }

  Future<void> _rejectPost(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      await doc.reference.update({
        'status': 'rejected',
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'rejectedAt': FieldValue.serverTimestamp(),
      });
      _message('Post rejected.');
    } catch (e) {
      _message('Post rejection failed: $e');
    }
  }

  String _timeNow() {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final suffix = now.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;

    if (current == null) {
      return Scaffold(
        backgroundColor: _ownerBg,
        appBar: AppBar(
          title: const Text('Owner Login'),
          backgroundColor: Colors.white,
        ),
        body: Center(
          child: FilledButton.icon(
            onPressed: loading ? null : _ownerLogin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: const Text('Owner Login'),
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _isOwner(),
      builder: (_, ownerSnapshot) {
        if (ownerSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (ownerSnapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Owner Login')),
            body: Center(
              child: FilledButton(
                onPressed: loading ? null : _ownerLogin,
                child: const Text('Owner Login'),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _ownerBg,
          appBar: AppBar(
            title: const Text('SRI NEWS Owner'),
            backgroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Logout',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const Material(
                  color: Colors.white,
                  child: TabBar(
                    tabs: [
                      Tab(
                        icon: Icon(Icons.verified_user_outlined),
                        text: 'Reporter Approval',
                      ),
                      Tab(
                        icon: Icon(Icons.article_outlined),
                        text: 'Post Approval',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _reporterApplications(),
                      _postApprovals(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _reporterApplications() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('users')
          .where('reporterStatus', isEqualTo: 'pending')
          .snapshots(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Unable to load reporter applications:\n${snapshot.error}'),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text('No pending reporter applications.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data();
            final name = (d['name'] ?? 'Reporter').toString();
            final email = (d['email'] ?? '').toString();

            return Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(email),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () =>
                                _setReporterStatus(doc, 'approved'),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _setReporterStatus(doc, 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _postApprovals() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('reporterPosts')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Unable to load pending posts:\n${snapshot.error}'),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text('No pending posts.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final p = doc.data();

            final title = (p['title'] ?? '').toString();
            final content = (p['content'] ?? '').toString();
            final category = (p['category'] ?? 'దేశం').toString();
            final reporter = (p['reporterName'] ?? 'Reporter').toString();
            final imageUrl = (p['mediaUrl'] ?? '').toString();

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: _ownerRed,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      content,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Reporter: $reporter',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox(height: 180),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _approvePost(doc),
                            icon: const Icon(Icons.publish),
                            label: const Text('Approve & Publish'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _rejectPost(doc),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
