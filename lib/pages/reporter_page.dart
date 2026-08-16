import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

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
    'అంతర్జాతీయం',
    'సినిమా',
    'క్రీడలు',
    'టెక్నాలజీ',
    'బిజినెస్',
    'విద్య',
    'ఆరోగ్యం',
    'రాశి ఫలాలు', 'దేవుళ్ళు', 'వాతావరణం', 'తెలుగు మేమ్స్',
  ];

  bool loading = false;
  List<File> selectedImages = [];

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
            suffixIcon: IconButton(
              icon: const Icon(Icons.visibility_outlined),
              onPressed: () {},
            ),
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

    if (selectedImages.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one image.')),
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

      if (reporterStatus != 'approved' && role != 'reporter') {
        throw Exception('Reporter is not approved by owner.');
      }

      final mediaUrls = <String>[];

      for (final image in selectedImages.take(20)) {
        final bytes = await image.readAsBytes();
        final uploaded = await StorageUploadService.uploadCarouselJpeg(
          folder: 'reporter_posts',
          uid: user.uid,
          bytes: bytes,
          imageCount: selectedImages.length,
        );
        mediaUrls.add(uploaded.dataUrl);
      }

      await db.collection('reporterPosts').add({
        'reporterId': user.uid,
        'reporterName': userData['name'] ??
            user.displayName ??
            'Reporter',
        'reporterEmail': userData['email'] ?? user.email ?? '',
        'title': '',
        'content': '',
        'category': '',
        'mediaUrl': mediaUrls.isNotEmpty ? mediaUrls.first : '',
        'mediaUrls': mediaUrls,
        'mediaPath': '',
        'status': 'pending',
        'imageOnly': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      title.clear();
      content.clear();
      selectedImages.clear();

      if (mounted) {
        setState(() => category = 'దేశం');
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Images submitted. Owner approval required before publishing.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _postWithDetails() async {
    final tagController = TextEditingController();
    final titleController = TextEditingController();
    final matterController = TextEditingController();
    String? selectedTag;
    const tagOptions = [
      'తెలంగాణ',
      'ఆంధ్రప్రదేశ్',
      'దేశం',
      'అంతర్జాతీయం',
      'సినిమా',
      'క్రీడలు',
      'టెక్నాలజీ',
      'బిజినెస్',
      'విద్య',
      'ఆరోగ్యం',
      'రాశి ఫలాలు',
      'దేవుళ్ళు',
      'వాతావరణం',
      'తెలుగు మేమ్స్',
    ];
    final detailImages = <File>[];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        bool saving = false;
        return StatefulBuilder(builder: (context, setSheetState) {
          Future<void> submit() async {
            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first.')));
              return;
            }
            if (detailImages.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one image.')));
              return;
            }
            setSheetState(() => saving = true);
            try {
              final userSnapshot = await db.collection('users').doc(user.uid).get();
              if (!userSnapshot.exists) throw Exception('User profile not found.');
              final userData = userSnapshot.data() ?? {};
              final reporterStatus = (userData['reporterStatus'] ?? '').toString();
              final role = (userData['role'] ?? '').toString();
              if (reporterStatus != 'approved' && role != 'reporter') {
                throw Exception('Reporter is not approved by owner.');
              }
              final mediaUrls = <String>[];
              for (final image in detailImages.take(20)) {
                final bytes = await image.readAsBytes();
                final uploaded = await StorageUploadService.uploadCarouselJpeg(folder: 'reporter_posts', uid: user.uid, bytes: bytes, imageCount: detailImages.length);
                mediaUrls.add(uploaded.dataUrl);
              }
              final tag = selectedTag?.trim() ?? '';
              final title = titleController.text.trim();
              final matter = matterController.text.trim();
              await db.collection('reporterPosts').add({
                'reporterId': user.uid,
                'reporterName': userData['name'] ?? user.displayName ?? 'Reporter',
                'reporterEmail': userData['email'] ?? user.email ?? '',
                'title': title,
                'content': matter,
                'description': matter,
                'category': tag,
                'tag': tag,
                'mediaUrl': mediaUrls.isNotEmpty ? mediaUrls.first : '',
                'mediaUrls': mediaUrls,
                'mediaPath': '',
                'status': 'pending',
                'imageOnly': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post submitted. Owner approval required before publishing.')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post upload failed: $e')));
            } finally {
              if (context.mounted) setSheetState(() => saving = false);
            }
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: 18, right: 18, top: 18, bottom: 18 + MediaQuery.viewInsetsOf(context).bottom),
              child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Images + Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedTag,
                  decoration: const InputDecoration(
                    labelText: 'Tag (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: tagOptions
                      .map((tag) => DropdownMenuItem<String>(
                            value: tag,
                            child: Text(tag),
                          ))
                      .toList(),
                  onChanged: saving
                      ? null
                      : (value) {
                          setSheetState(() => selectedTag = value);
                        },
                ),
                const SizedBox(height: 10),
                TextField(controller: titleController, enabled: !saving, decoration: const InputDecoration(labelText: 'Title (optional)', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: matterController, enabled: !saving, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'Matter (optional)', border: OutlineInputBorder(), alignLabelWithHint: true)),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: saving ? null : () async {
                    final picked = await ImagePicker().pickMultiImage(imageQuality: 88);
                    if (picked.isEmpty || !context.mounted) return;
                    final files = picked.take(20).map((x) => File(x.path)).toList();
                    setSheetState(() { detailImages..clear()..addAll(files); });
                    if (picked.length > 20 && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 20 images can be selected.')));
                  },
                  icon: const Icon(Icons.collections_outlined),
                  label: Text(detailImages.isEmpty ? 'Select up to 20 Images' : '${detailImages.length} Images Selected'),
                ),
                if (detailImages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(height: 110, child: ListView.separated(
                    scrollDirection: Axis.horizontal, itemCount: detailImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(detailImages[index], width: 120, height: 110, fit: BoxFit.cover)),
                      Positioned(top: 4, right: 4, child: Material(color: Colors.black54, shape: const CircleBorder(), child: InkWell(
                        customBorder: const CircleBorder(), onTap: saving ? null : () => setSheetState(() => detailImages.removeAt(index)),
                        child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, color: Colors.white, size: 17)),
                      ))),
                    ]),
                  )),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(onPressed: saving ? null : submit, icon: const Icon(Icons.cloud_upload_outlined), label: Text(saving ? 'Uploading...' : 'Upload Images + Details')),
              ])),
            ),
          );
        });
      },
    );
    tagController.dispose(); titleController.dispose(); matterController.dispose();
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
                'Post Images',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () async {
                        final picked = await ImagePicker().pickMultiImage(
                          imageQuality: 88,
                        );
                        if (picked.isEmpty || !mounted) return;

                        final files = picked
                            .take(20)
                            .map((x) => File(x.path))
                            .toList();

                        setState(() {
                          selectedImages
                            ..clear()
                            ..addAll(files);
                        });

                        if (picked.length > 20 && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Maximum 20 images can be selected.'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.collections_outlined),
                label: Text(
                  selectedImages.isEmpty
                      ? 'Select up to 20 Images'
                      : '${selectedImages.length} Images Selected',
                ),
              ),
              if (selectedImages.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              selectedImages[index],
                              width: 120,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: loading
                                    ? null
                                    : () => setState(
                                          () => selectedImages.removeAt(index),
                                        ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: loading ? null : submitPost,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  loading ? 'Uploading...' : 'Upload Images',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: loading ? null : () {
                  Navigator.of(context).pop();
                  _postWithDetails();
                },
                icon: const Icon(Icons.article_outlined),
                label: const Text('Images + Details'),
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
          IconButton(
            onPressed: loading ? null : loginOrApply,
            icon: const Icon(Icons.login_outlined),
            tooltip: 'Reporter Login',
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
          child: IconButton(
            onPressed: loading ? null : loginOrApply,
            icon: const Icon(Icons.login_outlined),
            tooltip: 'Reporter Login',
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
