import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../models/news_item.dart';
import '../widgets/matter_color_editor.dart';

import '../services/auth_service.dart';
import 'login_page.dart';

const _newsColors = <int>[0xFF171313, 0xFF0D47A1, 0xFFE60000, 0xFF2E7D32, 0xFFF57C00, 0xFF6A1B9A, 0xFFC2185B, 0xFF795548];

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

  Future<void> loginOrApply() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LoginPage(
          initialRole: LoginRole.reporter,
          initialApply: true,
        ),
      ),
    );
    if (mounted) setState(() {});
  }


  Future<void> _postWithDetails() async {
    final tagController = TextEditingController();
    final titleController = TextEditingController();
    final matterController = TextEditingController();
    const tagOptions = [
      'ఆంధ్రప్రదేశ్',
      'తెలంగాణ',
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
        int titleColor = 0xFF171313;
        int matterColor = 0xFF6C6767;
        List<MatterSegment> matterSegments = [];
        final matterEditorKey = GlobalKey<MatterColorEditorState>();
        final titleColorEditorKey = GlobalKey<TitleColorEditorState>();
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
              final titleEditor = titleColorEditorKey.currentState;
              final matterEditor = matterEditorKey.currentState;
              if (titleEditor == null || !titleEditor.isSaved ||
                  (matterController.text.trim().isNotEmpty && (matterEditor == null || !matterEditor.isSaved))) {
                setSheetState(() => saving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title Colour and Matter Colour Apply chesi Save cheyyandi.')),
                );
                return;
              }
              titleColor = titleEditor.color;
              matterColor = matterEditor?.color ?? matterColor;
              final userSnapshot = await db.collection('users').doc(user.uid).get();
              if (!userSnapshot.exists) throw Exception('User profile not found.');
              final userData = userSnapshot.data() ?? {};
              final reporterStatus = (userData['reporterStatus'] ?? '').toString();
              final role = (userData['role'] ?? '').toString();
              if (reporterStatus != 'approved' && role != 'reporter') {
                throw Exception('Reporter is not approved by owner.');
              }
              final mediaUrls = <String>[];
              final imagesToUpload = detailImages.take(10).toList();
              for (var i = 0; i < imagesToUpload.length; i++) {
                final image = imagesToUpload[i];
                if (context.mounted) {
                  setSheetState(() => saving = true);
                }
                final bytes = await image.readAsBytes();
                final uploaded = await StorageUploadService.uploadCarouselJpeg(
                  folder: 'reporter_posts',
                  uid: user.uid,
                  bytes: bytes,
                  imageCount: imagesToUpload.length,
                );
                mediaUrls.add(uploaded.dataUrl);
              }
              final tag = tagController.text.trim();
              final enteredTitle = titleController.text.trim();
              final matter = matterController.text.trim();
              final currentMatterSegments = matterEditor?.segments ?? matterSegments;
              final savedMatterSegments = normalizedMatterSegments(matter, currentMatterSegments, matterColor);
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
                'titleColor': titleColor,
                  'titleColorHex': '#${titleColor.toRadixString(16).padLeft(8, '0').substring(2)}',
                'matterColor': matterColor,
                  'matterColorHex': '#${matterColor.toRadixString(16).padLeft(8, '0').substring(2)}',
                  'matterSegments': savedMatterSegments.map((e) => e.toMap()).toList(),
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
                        'Images + Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Image optional. If no image is selected, it will be sent as BREAKING NEWS.',
                        style: TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 14),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tags',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tagOptions.map((tag) {
                          final selected = tagController.text.trim() == tag;
                          return ChoiceChip(
                            label: Text(tag),
                            selected: selected,
                            onSelected: saving
                                ? null
                                : (value) {
                                    setSheetState(() {
                                      tagController.text = value ? tag : '';
                                    });
                                  },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: tagController,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Tag (optional)',
                          hintText: 'Select a tag above or type your own',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TitleColorEditor(
                        key: titleColorEditorKey,
                        controller: titleController,
                        colors: _newsColors,
                        defaultColor: titleColor,
                        enabled: !saving,
                        onSaved: (color) => setSheetState(() => titleColor = color),
                      ),
                      const SizedBox(height: 14),
                      MatterColorEditor(
                        key: matterEditorKey,
                        controller: matterController,
                        colors: _newsColors,
                        defaultColor: matterColor,
                        initialSegments: matterSegments,
                        enabled: !saving,
                        onChanged: (segments) => matterSegments = segments,
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: saving
                            ? null
                            : () async {
                                final picked =
                                    await ImagePicker().pickMultiImage();
                                if (picked.isEmpty || !context.mounted) {
                                  return;
                                }

                                if (picked.length > 10) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Maximum 10 images can be selected. Please select 10 or fewer.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                final files = picked
                                    .take(10)
                                    .map((x) => File(x.path))
                                    .toList();

                                setSheetState(() {
                                  detailImages
                                    ..clear()
                                    ..addAll(files);
                                });

                                if (picked.length > 20 && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Maximum 10 images can be selected.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.collections_outlined),
                        label: Text(
                          detailImages.isEmpty
                              ? 'Select up to 10 Images'
                              : '${detailImages.length} Images Selected',
                        ),
                      ),
                      if (detailImages.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: detailImages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, index) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    detailImages[index],
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
                                      onTap: saving
                                          ? null
                                          : () => setSheetState(
                                                () => detailImages
                                                    .removeAt(index),
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
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          saving
                              ? 'Uploading...'
                              : 'Upload Post',
                        ),
                      ),
                    ],
                  ),
                ),
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
          IconButton(
            onPressed: loading ? null : loginOrApply,
            icon: const Icon(Icons.login_outlined),
            tooltip: 'Reporter Login',
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
