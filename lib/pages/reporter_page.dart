import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../services/auth_service.dart';

class ReporterPage extends StatefulWidget {
  const ReporterPage({super.key});

  @override
  State<ReporterPage> createState() => _ReporterPageState();
}

class _ReporterPageState extends State<ReporterPage> {
  final auth = AuthService();
  final db = FirebaseFirestore.instance;
  final title = TextEditingController();
  final content = TextEditingController();

  String category = 'దేశం';
  final categories = const [
    'తెలంగాణ',
    'ఆంధ్రప్రదేశ్',
    'దేశం',
    'సినిమా',
    'క్రీడలు',
    'టెక్నాలజీ',
    'బిజినెస్',
  ];

  bool loading = false;
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedPostImage;

  Future<void> _pickPostImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image != null && mounted) {
      setState(() => _selectedPostImage = image);
    }
  }

  Future<String> _uploadPostImage(String uid) async {
    final image = _selectedPostImage;
    if (image == null) return '';
    final ref = FirebaseStorage.instance.ref().child(
      'reporter_posts/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(File(image.path));
    return ref.getDownloadURL();
  }

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    super.dispose();
  }

  Future<void> loginOrApply() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();

    final proceed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Reporter Login / Apply'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Name (for new reporter)',
                    ),
                  ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                    ),
                  ),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;

    if (!proceed) {
      email.dispose();
      password.dispose();
      name.dispose();
      return;
    }

    if (email.text.trim().isEmpty || password.text.isEmpty) {
      email.dispose();
      password.dispose();
      name.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email and password are required.'),
          ),
        );
      }
      return;
    }

    setState(() => loading = true);

    try {
      UserCredential credential;

      try {
        credential = await auth.login(
          email.text.trim(),
          password.text,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found' &&
            e.code != 'invalid-credential') {
          rethrow;
        }

        if (name.text.trim().isEmpty) {
          throw Exception(
            'Name is required when applying as a new reporter.',
          );
        }

        credential = await auth.register(
          email.text.trim(),
          password.text,
          displayName: name.text.trim(),
        );
      }

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Unable to get Firebase user.');
      }

      final uid = firebaseUser.uid;
      final userRef = db.collection('users').doc(uid);
      final existing = await userRef.get();

      // Reporter application is stored ONLY in users/{uid}.
      // No reporterApplications collection is used.
      if (!existing.exists) {
        await userRef.set({
          'uid': uid,
          'name': name.text.trim().isEmpty
              ? (firebaseUser.displayName ?? '')
              : name.text.trim(),
          'email': firebaseUser.email ?? email.text.trim(),
          'role': 'user',
          'reporterStatus': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        final data = existing.data() ?? {};
        final status = (data['reporterStatus'] ?? '').toString();

        if (status.isEmpty || status == 'not_applied') {
          await userRef.update({
            'reporterStatus': 'pending',
          });
        }
      }

      final snapshot = await userRef.get();
      final data = snapshot.data() ?? {};
      final status =
          (data['reporterStatus'] ?? 'pending').toString();

      if (!mounted) return;

      final message = switch (status) {
        'approved' =>
          'Reporter approved. Posting access enabled.',
        'rejected' =>
          'Reporter application was rejected by owner.',
        _ =>
          'Application submitted. Owner approval required.',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reporter login failed: $e'),
          ),
        );
      }
    } finally {
      email.dispose();
      password.dispose();
      name.dispose();

      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> submitPost() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first.')),
        );
      }
      return;
    }

    if (title.text.trim().isEmpty ||
        content.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Title and content are required.'),
          ),
        );
      }
      return;
    }

    setState(() => loading = true);

    try {
      final userSnapshot =
          await db.collection('users').doc(user.uid).get();

      if (!userSnapshot.exists) {
        throw Exception('User profile not found.');
      }

      final userData = userSnapshot.data() ?? {};
      final reporterStatus =
          (userData['reporterStatus'] ?? '').toString();
      final role = (userData['role'] ?? '').toString();

      if (reporterStatus != 'approved' &&
          role != 'reporter') {
        throw Exception(
          'Reporter is not approved by owner.',
        );
      }

      final mediaUrl = await _uploadPostImage(user.uid);

      await db.collection('reporterPosts').add({
        'reporterId': user.uid,
        'reporterName': userData['name'] ??
            user.displayName ??
            'Reporter',
        'reporterEmail':
            userData['email'] ?? user.email ?? '',
        'title': title.text.trim(),
        'content': content.text.trim(),
        'category': category,
        'mediaUrl': mediaUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      title.clear();
      content.clear();
      _selectedPostImage = null;

      if (mounted) {
        setState(() => category = 'దేశం');

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Post submitted. Owner approval required before publishing.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget _postSheet() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Reporter Post',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      ),
                    )
                    .toList(),
                onChanged: loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => category = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: content,
                maxLines: 7,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_selectedPostImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(_selectedPostImage!.path),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: loading ? null : () => setState(() => _selectedPostImage = null),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove Image'),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: loading ? null : _pickPostImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('Upload Image'),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: loading ? null : submitPost,
                child: Text(
                  loading
                      ? 'Submitting...'
                      : 'Submit for Owner Approval',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget profile(
    DocumentSnapshot<Map<String, dynamic>> user,
  ) {
    final data = user.data() ?? {};

    final status =
        (data['reporterStatus'] ?? 'not_applied').toString();

    final approved = status == 'approved';

    final name =
        (data['name'] ?? 'Reporter').toString();

    final email =
        (data['email'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 30,
              child: Icon(Icons.person, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(email),
                  const SizedBox(height: 6),
                  Chip(
                    label: Text(
                      status == 'approved'
                          ? 'APPROVED'
                          : status.toUpperCase(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (!approved) ...[
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.verified_user_outlined,
              ),
              title: Text(
                status == 'rejected'
                    ? 'Application rejected'
                    : 'Owner approval required',
              ),
              subtitle: Text(
                status == 'pending'
                    ? 'Your reporter application is waiting for owner approval.'
                    : status == 'rejected'
                        ? 'Your reporter application was rejected by the owner.'
                        : 'Login below to submit your reporter application.',
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: loading ? null : loginOrApply,
            child: const Text('Reporter Login / Apply'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: loading
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _postSheet(),
                    );
                  },
            icon: const Icon(Icons.add),
            label: const Text('Start Posting'),
          ),
          const SizedBox(height: 18),
          const Text(
            'My Posts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          _myPosts(),
        ],

        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: loading
              ? null
              : () async {
                  await auth.logout();
                  if (mounted) setState(() {});
                },
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }

  Widget _myPosts() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('reporterPosts')
          .where(
            'reporterId',
            isEqualTo: user.uid,
          )
          .snapshots(),
      builder: (_, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Unable to load posts: ${snapshot.error}',
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No posts yet.'),
          );
        }

        return Column(
          children: docs.map((doc) {
            final p = doc.data();

            final postTitle =
                (p['title'] ?? '').toString();

            final postContent =
                (p['content'] ?? '').toString();

            final postStatus =
                (p['status'] ?? 'pending').toString();

            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.article_outlined,
                ),
                title: Text(
                  postTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '$postStatus • $postContent',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;

    if (current == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reporter'),
        ),
        body: Center(
          child: FilledButton(
            onPressed: loading ? null : loginOrApply,
            child: const Text('Reporter Login / Apply'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reporter Center'),
      ),
      body: StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>>(
        stream: db
            .collection('users')
            .doc(current.uid)
            .snapshots(),
        builder: (_, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load reporter profile:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData ||
              !snapshot.data!.exists) {
            return Center(
              child: FilledButton(
                onPressed: loading ? null : loginOrApply,
                child: const Text(
                  'Create Reporter Profile',
                ),
              ),
            );
          }

          return profile(snapshot.data!);
        },
      ),
    );
  }
}
