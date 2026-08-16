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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _reporterLogin() async {
    final email = TextEditingController();
    final password = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool obscure = true;
        bool dialogLoading = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> login() async {
              final e = email.text.trim();
              final p = password.text;

              if (e.isEmpty || p.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Enter reporter email and password.')),
                );
                return;
              }

              setDialogState(() => dialogLoading = true);

              try {
                final credential = await FirebaseAuth.instance
                    .signInWithEmailAndPassword(email: e, password: p);
                final user = credential.user;
                if (user == null) throw Exception('Login failed.');

                final doc = await db.collection('users').doc(user.uid).get();
                if (!doc.exists) {
                  await FirebaseAuth.instance.signOut();
                  throw Exception('Reporter profile not found.');
                }

                final data = doc.data() ?? {};
                final role = (data['role'] ?? '').toString().trim().toLowerCase();
                final reporterStatus = (data['reporterStatus'] ?? '')
                    .toString().trim().toLowerCase();

                final isReporter =
                    role == 'reporter' || reporterStatus == 'approved';

                if (!isReporter) {
                  await FirebaseAuth.instance.signOut();
                  if (reporterStatus == 'pending') {
                    throw Exception('Reporter application is still waiting for owner approval.');
                  }
                  if (reporterStatus == 'rejected') {
                    throw Exception('Reporter application was rejected by owner.');
                  }
                  throw Exception('This account is not an approved reporter.');
                }

                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reporter login successful.')),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (dialogContext.mounted) {
                  final message = switch (e.code) {
                    'invalid-credential' || 'wrong-password' || 'user-not-found' =>
                      'Invalid reporter email or password.',
                    'user-disabled' => 'This reporter account is disabled.',
                    'too-many-requests' =>
                      'Too many login attempts. Please try again later.',
                    _ => e.message ?? 'Reporter login failed.',
                  };
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
                  );
                }
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => dialogLoading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Reporter Login', style: TextStyle(fontWeight: FontWeight.w900)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Reporter Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => dialogLoading ? null : login(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: dialogLoading
                            ? null
                            : () => setDialogState(() => obscure = !obscure),
                        icon: Icon(obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: dialogLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: dialogLoading ? null : login,
                  child: dialogLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Login'),
                ),
              ],
            );
          },
        );
      },
    );

    email.dispose();
    password.dispose();
  }

  Future<void> _applyAsReporter() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();

    final proceed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            bool obscure = true;
            return StatefulBuilder(
              builder: (context, setDialogState) => AlertDialog(
                title: const Text('Reporter Application',
                    style: TextStyle(fontWeight: FontWeight.w900)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Name', border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email', border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: password,
                        obscureText: obscure,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setDialogState(() => obscure = !obscure),
                            icon: Icon(obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            );
          },
        ) ?? false;

    if (!proceed) {
      name.dispose(); email.dispose(); password.dispose();
      return;
    }

    final nameText = name.text.trim();
    final emailText = email.text.trim();
    final passwordText = password.text;

    if (nameText.isEmpty || emailText.isEmpty || passwordText.isEmpty) {
      name.dispose(); email.dispose(); password.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name, email and password are required.')),
        );
      }
      return;
    }

    setState(() => loading = true);
    try {
      final credential = await auth.register(
        emailText,
        passwordText,
        displayName: nameText,
      );
      final user = credential.user;
      if (user == null) throw Exception('Unable to create reporter account.');

      await db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': nameText,
        'email': user.email ?? emailText,
        'role': 'user',
        'reporterStatus': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await auth.logout();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporter application submitted. Owner approval is required before login.'),
          ),
        );
        setState(() {});
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        final message = e.code == 'email-already-in-use'
            ? 'This email is already registered. Please use Reporter Login.'
            : (e.message ?? 'Reporter application failed.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reporter application failed: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      name.dispose(); email.dispose(); password.dispose();
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
            // Images are optional here. No image means this is a Breaking News submission.
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
              // Upload images in small parallel batches instead of waiting for
              // every image one-by-one. This makes the Send button much faster
              // while avoiding an excessive number of simultaneous uploads.
              final images = detailImages.take(20).toList();
              final mediaUrls = <String>[];
              const batchSize = 4;

              for (var start = 0; start < images.length; start += batchSize) {
                final batch = images.skip(start).take(batchSize).toList();

                final uploadedBatch = await Future.wait(
                  batch.map((image) async {
                    final bytes = await image.readAsBytes();
                    return StorageUploadService.uploadCarouselJpeg(
                      folder: 'reporter_posts',
                      uid: user.uid,
                      bytes: bytes,
                      imageCount: images.length,
                    );
                  }),
                );

                mediaUrls.addAll(
                  uploadedBatch.map((uploaded) => uploaded.dataUrl),
                );
              }
              final tag = selectedTag?.trim() ?? '';
              final enteredTitle = titleController.text.trim();
              final matter = matterController.text.trim();
              final isBreaking = detailImages.isEmpty;
              final postTitle = enteredTitle.isEmpty && isBreaking
                  ? 'BREAKING NEWS'
                  : enteredTitle;
              await db.collection('reporterPosts').add({
                'reporterId': user.uid,
                'reporterName': userData['name'] ?? user.displayName ?? 'Reporter',
                'reporterEmail': userData['email'] ?? user.email ?? '',
                'title': postTitle,
                'content': matter,
                'description': matter,
                'category': tag,
                'tag': tag,
                'mediaUrl': mediaUrls.isNotEmpty ? mediaUrls.first : '',
                'mediaUrls': mediaUrls,
                'mediaPath': '',
                'status': 'pending',
                'imageOnly': false,
                'breaking': isBreaking,
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isBreaking
                          ? 'Breaking News submitted. Owner/Admin approval required.'
                          : 'Post submitted. Owner approval required before publishing.',
                    ),
                  ),
                );
              }
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
                const SizedBox(height: 6),
                const Text(
                  'Image optional. If no image is selected, it will be sent as BREAKING NEWS.',
                  style: TextStyle(color: Colors.black54),
                ),
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
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : _reporterLogin,
                  icon: const Icon(Icons.login_outlined),
                  label: const Text('Reporter Login'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : _applyAsReporter,
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Apply'),
                ),
              ),
            ],
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: loading ? null : _postWithDetails,
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Reporter Access',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _reporterLogin,
                    icon: const Icon(Icons.login_outlined),
                    label: const Text('Reporter Login'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : _applyAsReporter,
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('New Reporter - Apply'),
                  ),
                ),
              ],
            ),
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
                onPressed: loading ? null : _reporterLogin,
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
