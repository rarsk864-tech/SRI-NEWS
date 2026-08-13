import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';

const _reporterRed = Color(0xFFE60000);

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
  final phone = TextEditingController();
  final location = TextEditingController();

  final picker = ImagePicker();

  bool loading = false;
  File? media;

  @override
  void dispose() {
    title.dispose();
    content.dispose();
    phone.dispose();
    location.dispose();
    super.dispose();
  }

  // ============================================================
  // REPORTER LOGIN / APPLY
  // ============================================================

  Future<void> loginOrApply() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();

    final apply = await showDialog<bool>(
          context: context,
          builder: (_) {
            return AlertDialog(
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
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!apply) {
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

    setState(() {
      loading = true;
    });

    try {
      UserCredential credential;

      // ----------------------------------------------------------
      // Existing user login
      // ----------------------------------------------------------

      try {
        credential = await auth.login(
          email.text.trim(),
          password.text,
        );
      } on FirebaseAuthException catch (e) {
        // --------------------------------------------------------
        // New user registration
        // --------------------------------------------------------

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

      // ----------------------------------------------------------
      // IMPORTANT:
      // Reporter data is stored ONLY in users/{uid}.
      //
      // We do NOT write reporterApplications/{uid}.
      // ----------------------------------------------------------

      final userRef = db.collection('users').doc(uid);

      final existing = await userRef.get();

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

        // Existing user who has never applied as reporter.
        final currentStatus =
            (data['reporterStatus'] ?? '').toString();

        if (currentStatus.isEmpty ||
            currentStatus == 'not_applied') {
          await userRef.update({
            'reporterStatus': 'pending',
          });
        }
      }

      // ----------------------------------------------------------
      // Read the final user document
      // ----------------------------------------------------------

      final userSnapshot = await userRef.get();

      final userData = userSnapshot.data() ?? {};

      final status =
          (userData['reporterStatus'] ?? 'pending').toString();

      if (!mounted) return;

      if (status == 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reporter approved. Posting access enabled.',
            ),
          ),
        );
      } else if (status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reporter application was rejected by owner.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Application submitted. Owner approval required.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reporter login failed: $e',
            ),
          ),
        );
      }
    } finally {
      email.dispose();
      password.dispose();
      name.dispose();

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // PICK PHOTO
  // ============================================================

  Future<void> pickMedia() async {
    try {
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );

      if (x != null && mounted) {
        setState(() {
          media = File(x.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to select photo: $e'),
          ),
        );
      }
    }
  }

  // ============================================================
  // UPLOAD PHOTO
  // ============================================================

  Future<String> upload() async {
    if (media == null) {
      return '';
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      throw Exception('User is not logged in.');
    }

    final uid = firebaseUser.uid;

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${media!.path.split('/').last}';

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('reporter_posts')
        .child(uid)
        .child(fileName);

    await storageRef.putFile(media!);

    return await storageRef.getDownloadURL();
  }

  // ============================================================
  // SUBMIT REPORTER POST
  // ============================================================

  Future<void> submitPost() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please login first.'),
          ),
        );
      }
      return;
    }

    final uid = firebaseUser.uid;

    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title.'),
        ),
      );
      return;
    }

    if (content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter news content.'),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      // ----------------------------------------------------------
      // Check reporter approval
      // ----------------------------------------------------------

      final userSnapshot =
          await db.collection('users').doc(uid).get();

      if (!userSnapshot.exists) {
        throw Exception('User profile not found.');
      }

      final userData = userSnapshot.data() ?? {};

      final reporterStatus =
          (userData['reporterStatus'] ?? '').toString();

      final role = (userData['role'] ?? '').toString();

      if (reporterStatus != 'approved' && role != 'reporter') {
        throw Exception(
          'Reporter is not approved by owner.',
        );
      }

      // ----------------------------------------------------------
      // Upload image
      // ----------------------------------------------------------

      final mediaUrl = await upload();

      // ----------------------------------------------------------
      // Create reporter post
      //
      // Owner will approve this before publishing.
      // ----------------------------------------------------------

      await db.collection('reporterPosts').add({
        'reporterId': uid,
        'reporterName': userData['name'] ??
            firebaseUser.displayName ??
            'Reporter',
        'reporterEmail':
            userData['email'] ?? firebaseUser.email ?? '',
        'title': title.text.trim(),
        'content': content.text.trim(),
        'mediaUrl': mediaUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      title.clear();
      content.clear();

      if (mounted) {
        setState(() {
          media = null;
        });

        Navigator.of(context).maybePop();

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
            content: Text(
              'Post failed: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget profile(
    DocumentSnapshot<Map<String, dynamic>> user,
  ) {
    final d = user.data() ?? {};

    final status =
        (d['reporterStatus'] ?? 'not_applied').toString();

    final approved = status == 'approved';

    final name =
        (d['name'] ?? 'Reporter').toString();

    final email =
        (d['email'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // --------------------------------------------------------
        // PROFILE HEADER
        // --------------------------------------------------------

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              radius: 30,
              child: Icon(
                Icons.person,
                size: 32,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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

        // --------------------------------------------------------
        // PENDING / REJECTED
        // --------------------------------------------------------

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
            child: const Text(
              'Reporter Login / Apply',
            ),
          ),
        ]

        // --------------------------------------------------------
        // APPROVED REPORTER
        // --------------------------------------------------------

        else ...[
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
            label: const Text(
              'Start Posting',
            ),
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

          // ------------------------------------------------------
          // MY POSTS
          // ------------------------------------------------------

          StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: db
                .collection('reporterPosts')
                .where(
                  'reporterId',
                  isEqualTo:
                      FirebaseAuth.instance.currentUser!.uid,
                )
                .orderBy(
                  'createdAt',
                  descending: true,
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

              final docs =
                  snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 20,
                  ),
                  child: Text(
                    'No posts yet.',
                  ),
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
                      (p['status'] ?? 'pending')
                          .toString();

                  return Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.article_outlined,
                      ),
                      title: Text(
                        postTitle,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '$postStatus • $postContent',
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],

        const SizedBox(height: 20),

        // --------------------------------------------------------
        // LOGOUT
        // --------------------------------------------------------

        OutlinedButton.icon(
          onPressed: loading
              ? null
              : () async {
                  await auth.logout();

                  if (mounted) {
                    setState(() {});
                  }
                },
          icon: const Icon(Icons.logout),
          label: const Text(
            'Logout',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CREATE POST SHEET
  // ============================================================

  Widget _postSheet() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom:
              18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            ch        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (for new reporter)')),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Continue'))],
    )) ?? false;
    if (!apply) { email.dispose(); password.dispose(); name.dispose(); return; }
    setState(() => loading = true);
    try {
      UserCredential c;
      try { c = await auth.login(email.text, password.text); }
      on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found' && e.code != 'invalid-credential') rethrow;
        c = await auth.register(email.text, password.text, displayName: name.text.trim());
      }
      final uid = c.user!.uid;
      final ref = db.collection('users').doc(uid);
      final existing = await ref.get();
      if (!existing.exists) {
        await ref.set({'uid': uid, 'name': name.text.trim().isEmpty ? (c.user!.displayName ?? '') : name.text.trim(), 'email': c.user!.email, 'role': 'user', 'reporterStatus': 'pending', 'createdAt': FieldValue.serverTimestamp()});
      }
      final u = await ref.get();
      final status = (u.data()?['reporterStatus'] ?? 'pending').toString();
      if (status == 'approved') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporter approved. Posting access enabled.')));
      } else if (status == 'rejected') {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporter application was rejected by owner.')));
      } else {
        // Reporter application is stored in users/{uid}.
        // Do NOT write to a separate reporterApplications collection.
        // The Firestore rules intentionally keep unknown collections locked.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted. Owner approval required.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reporter login failed: $e')));
    } finally { email.dispose(); password.dispose(); name.dispose(); if (mounted) setState(() => loading = false); }
  }

  Future<void> pickMedia() async {
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (x != null) setState(() => media = File(x.path));
  }

  Future<String> upload() async {
    if (media == null) return '';
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final name = '${DateTime.now().millisecondsSinceEpoch}_${media!.path.split('/').last}';
    final ref = FirebaseStorage.instance.ref('reporter_posts/$uid/$name');
    await ref.putFile(media!);
    return ref.getDownloadURL();
  }

  Future<void> submitPost() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (title.text.trim().isEmpty || content.text.trim().isEmpty) return;
    setState(() => loading = true);
    try {
      final user = await db.collection('users').doc(uid).get();
      if (user.data()?['reporterStatus'] != 'approved') throw Exception('Reporter is not approved');
      final mediaUrl = await upload();
      await db.collection('reporterPosts').add({'reporterId': uid, 'reporterName': user.data()?['name'] ?? FirebaseAuth.instance.currentUser?.displayName ?? '', 'title': title.text.trim(), 'content': content.text.trim(), 'mediaUrl': mediaUrl, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp()});
      title.clear(); content.clear(); setState(() => media = null);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post submitted. Owner approval required before publishing.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post failed: $e'))); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Widget profile(DocumentSnapshot<Map<String,dynamic>> user) {
    final d = user.data() ?? {};
    final status = (d['reporterStatus'] ?? 'not_applied').toString();
    final approved = status == 'approved';
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [const CircleAvatar(radius: 30, child: Icon(Icons.person)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['name'] ?? 'Reporter', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), Text(d['email'] ?? ''), const SizedBox(height: 4), Chip(label: Text(status == 'approved' ? 'APPROVED' : status.toUpperCase()))]))]),
      const SizedBox(height: 18),
      if (!approved) ...[
        Card(child: ListTile(leading: const Icon(Icons.verified_user_outlined), title: const Text('Owner approval required'), subtitle: Text(status == 'pending' ? 'Your reporter application is waiting for owner approval.' : 'Login below to submit your reporter application.'))),
        const SizedBox(height: 10), FilledButton(onPressed: loading ? null : loginOrApply, child: const Text('Reporter Login / Apply')),
      ] else ...[
        FilledButton.icon(onPressed: loading ? null : () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _postSheet()), icon: const Icon(Icons.add), label: const Text('Start Posting')),
        const SizedBox(height: 14),
        const Text('My Posts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: db.collection('reporterPosts').where('reporterId', isEqualTo: FirebaseAuth.instance.currentUser!.uid).orderBy('createdAt', descending: true).snapshots(), builder: (_, s) { final docs = s.data?.docs ?? []; return Column(children: docs.map((doc) { final p=doc.data(); return Card(child: ListTile(title: Text(p['title'] ?? ''), subtitle: Text('${p['status'] ?? 'pending'} • ${p['content'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis), leading: const Icon(Icons.article_outlined))); }).toList()); }),
      ],
      const SizedBox(height: 20), OutlinedButton.icon(onPressed: auth.logout, icon: const Icon(Icons.logout), label: const Text('Logout')),
    ]);
  }

  Widget _postSheet() => SafeArea(child: Padding(padding: EdgeInsets.only(left:18,right:18,top:18,bottom:18+MediaQuery.viewInsetsOf(context).bottom), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Create Reporter Post', style: TextStyle(fontSize: 24,fontWeight: FontWeight.w900)), const SizedBox(height:14), TextField(controller:title, decoration:const InputDecoration(labelText:'Title', border:OutlineInputBorder())), const SizedBox(height:12), TextField(controller:content,maxLines:7,decoration:const InputDecoration(labelText:'Content',border:OutlineInputBorder())), const SizedBox(height:12), OutlinedButton.icon(onPressed: pickMedia, icon:const Icon(Icons.photo_library_outlined), label:Text(media==null?'Add Photo':'Change Photo')), if(media!=null) Padding(padding:const EdgeInsets.only(top:8),child:Image.file(media!,height:180,fit:BoxFit.cover)), const SizedBox(height:16), FilledButton(onPressed: loading?null:submitPost, child:Text(loading?'Submitting...':'Submit for Owner Approval'))]))));

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) return Scaffold(appBar: AppBar(title: const Text('Reporter')), body: Center(child: FilledButton(onPressed: loading ? null : loginOrApply, child: const Text('Reporter Login / Apply'))));
    return Scaffold(appBar: AppBar(title: const Text('Reporter Center')), body: StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(stream: db.collection('users').doc(current.uid).snapshots(), builder: (_, s) { if(!s.hasData) return const Center(child:CircularProgressIndicator()); return profile(s.data!); }));
  }
}
