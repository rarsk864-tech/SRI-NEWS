import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_upload_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'profile_settings_page.dart';

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

    try {
      final snap = await db.collection('users').doc(user.uid).get();

      if (!snap.exists) {
        debugPrint('OWNER CHECK: users/${user.uid} not found');
        return false;
      }

      final data = snap.data() ?? {};
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      final storedUid = (data['uid'] ?? '').toString().trim();

      // Owner access is granted only when the signed-in Firebase UID
      // matches the Firestore user document and its role is exactly owner.
      return role == 'owner' &&
          (storedUid.isEmpty || storedUid == user.uid);
    } catch (e) {
      debugPrint('OWNER CHECK ERROR: $e');
      return false;
    }
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


  Future<void> _createNews() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String category = 'తెలంగాణ';
    bool breaking = true;
    File? selectedImage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> publish() async {
              if (title.text.trim().isEmpty ||
                  description.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Title and content are required.'),
                  ),
                );
                return;
              }

              setSheetState(() => saving = true);
              try {
                String imageUrl = '';
                String imagePath = '';
                final image = selectedImage;
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
                if (image != null && uid.isNotEmpty) {
                  final bytes = await image.readAsBytes();
                  final uploaded = await StorageUploadService.uploadJpeg(
                    folder: 'news_images',
                    uid: uid,
                    bytes: bytes,
                  );
                  imageUrl = uploaded.dataUrl;
                  imagePath = '';
                }
                final now = DateTime.now();
                final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
                final m = now.minute.toString().padLeft(2, '0');
                final suffix = now.hour >= 12 ? 'PM' : 'AM';

                await db.collection('news').add({
                  'category': category,
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'content': description.text.trim(),
                  'imageUrl': imageUrl,
                  'imagePath': imagePath,
                  'time': '$h:$m $suffix',
                  'publishedAt': FieldValue.serverTimestamp(),
                  'breaking': breaking,
                  'source': 'owner',
                  'ownerId': FirebaseAuth.instance.currentUser?.uid ?? '',
                });

                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
                _message('News published successfully.');
              } catch (e) {
                _message('News publish failed: $e');
              } finally {
                if (context.mounted) {
                  setSheetState(() => saving = false);
                }
              }
            }

            const categories = [
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
                        'Post News',
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
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setSheetState(() => category = value);
                                }
                              },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: saving ? null : () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
                          if (picked != null && context.mounted) {
                            setSheetState(() => selectedImage = File(picked.path));
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(selectedImage == null ? 'Select News Image' : 'Change News Image'),
                      ),
                      if (selectedImage != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(selectedImage!, height: 170, width: double.infinity, fit: BoxFit.cover),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: saving ? null : () => setSheetState(() => selectedImage = null),
                            icon: const Icon(Icons.close),
                            label: const Text('Remove Image'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: title,
                        enabled: !saving,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: description,
                        enabled: !saving,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'News Content',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Breaking News'),
                        value: breaking,
                        onChanged: saving
                            ? null
                            : (value) {
                                setSheetState(() => breaking = value);
                              },
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: saving ? null : publish,
                        icon: const Icon(Icons.publish),
                        label: Text(
                          saving ? 'Publishing...' : 'Publish News',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    title.dispose();
    description.dispose();
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
      final imageUrls = p['mediaUrls'] is List
          ? List<String>.from(p['mediaUrls'])
          : (imageUrl.isNotEmpty ? <String>[imageUrl] : <String>[]);
      const mediaPath = '';
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
        'imageUrls': imageUrls,
        'imagePath': mediaPath,
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

  Future<void> _editNews(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data() ?? {};
    final title = TextEditingController(
      text: (data['title'] ?? '').toString(),
    );
    final content = TextEditingController(
      text: (data['content'] ?? data['description'] ?? '').toString(),
    );

    String category = (data['category'] ?? 'దేశం').toString();
    bool breaking = data['breaking'] == true;

    // Reporter posts use `mediaUrl`, while normal news uses `imageUrl`.
    // Keep the edit dialog compatible with both, just like Admin.
    final bool usesMediaUrl = data.containsKey('mediaUrl');
    String currentImageUrl = (data['mediaUrl'] ?? '').toString();
    if (currentImageUrl.isEmpty) {
      currentImageUrl = (data['imageUrl'] ?? '').toString();
    }

    File? selectedImage;
    bool removeImage = false;

    const categories = [
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

    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (title.text.trim().isEmpty ||
                  content.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Title and content are required.'),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);

              try {
                String imageUrl = currentImageUrl;
                final image = selectedImage;
                final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

                if (image != null && uid.isNotEmpty) {
                  final bytes = await image.readAsBytes();
                  final uploaded = await StorageUploadService.uploadJpeg(
                    folder: 'news_images',
                    uid: uid,
                    bytes: bytes,
                  );
                  imageUrl = uploaded.dataUrl;
                } else if (removeImage) {
                  imageUrl = '';
                }

                await doc.reference.update({
                  'title': title.text.trim(),
                  'description': content.text.trim(),
                  'content': content.text.trim(),
                  'category': category,
                  if (usesMediaUrl) 'mediaUrl': imageUrl,
                  if (!usesMediaUrl) 'imageUrl': imageUrl,
                  'breaking': breaking,
                  'editedAt': FieldValue.serverTimestamp(),
                  'editedBy': uid,
                });

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Edit failed: $e')),
                  );
                }
              } finally {
                if (context.mounted) {
                  setDialogState(() => saving = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit News'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: categories.contains(category) ? category : 'దేశం',
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
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setDialogState(() => category = value);
                              }
                            },
                    ),
                    if (!removeImage && selectedImage == null && currentImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _dataImage(currentImageUrl, height: 150),
                      ),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              final picked = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 88,
                              );
                              if (picked != null && context.mounted) {
                                setDialogState(() {
                                  selectedImage = File(picked.path);
                                  removeImage = false;
                                });
                              }
                            },
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        selectedImage == null ? 'Edit News Image' : 'Change News Image',
                      ),
                    ),
                    if (selectedImage != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          selectedImage!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: saving
                              ? null
                              : () => setDialogState(() {
                                    selectedImage = null;
                                    removeImage = false;
                                  }),
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel Image Change'),
                        ),
                      ),
                    ] else if (currentImageUrl.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: saving
                              ? null
                              : () => setDialogState(() {
                                    removeImage = true;
                                  }),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove Image'),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      enabled: !saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: content,
                      enabled: !saving,
                      minLines: 5,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: 'News Content',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Breaking News'),
                      value: breaking,
                      onChanged: saving
                          ? null
                          : (value) {
                              setDialogState(() => breaking = value);
                            },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving...' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    content.dispose();

    if (updated == true) {
      _message('News updated successfully.');
    }
  }

  Future<void> _deleteNews(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final title = (data['title'] ?? 'this news').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete News'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _ownerRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await doc.reference.delete();
      _message('News deleted successfully.');
    } catch (e) {
      _message('News delete failed: $e');
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
      return const Scaffold(
        backgroundColor: _ownerBg,
        body: Center(
          child: Text('Owner login required.'),
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

        // Never render the Owner Dashboard for a non-owner account.
        if (ownerSnapshot.data != true) {
          return const Scaffold(
            backgroundColor: _ownerBg,
            body: Center(
              child: Text('Access denied.'),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _ownerBg,
          appBar: AppBar(
            title: const Text('SRI NEWS Owner'),
            backgroundColor: Colors.white,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilledButton.icon(
                  onPressed: loading ? null : _createNews,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Post News'),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Profile Settings',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
                ),
                icon: const Icon(Icons.account_circle_outlined),
              ),
              IconButton(
                tooltip: 'Logout',
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _userStats(),
                _userDirectory(),
                const SizedBox(height: 10),
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
                      Tab(
                        icon: Icon(Icons.delete_outline),
                        text: 'Published News',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _reporterApplications(),
                      _postApprovals(),
                      _publishedNews(),
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

  Future<void> _changeUserRole({
    required String uid,
    required String name,
    required String newRole,
  }) async {
    final isRemovingAdmin = newRole == 'user';
    final action = newRole == 'admin' ? 'make $name an Admin' : 'remove Admin access from $name';
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(newRole == 'admin' ? 'Make Admin' : 'Remove Admin'),
            content: Text('Are you sure you want to $action?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(newRole == 'admin' ? 'Make Admin' : 'Remove Admin'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final userRef = db.collection('users').doc(uid);
      final current = await userRef.get();
      final currentRole = (current.data()?['role'] ?? '').toString().toLowerCase();
      final roleBeforeAdmin = (current.data()?['roleBeforeAdmin'] ?? '').toString().toLowerCase();
      final restoreRole = roleBeforeAdmin == 'reporter' ? 'reporter' : 'user';

      await userRef.set({
        'role': isRemovingAdmin ? restoreRole : newRole,
        'roleLabel': isRemovingAdmin
            ? (restoreRole == 'reporter' ? 'REPORTER' : 'USER')
            : 'ADMIN',
        'roleChangedAt': FieldValue.serverTimestamp(),
        'roleChangedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        if (!isRemovingAdmin) 'roleBeforeAdmin': currentRole,
        if (isRemovingAdmin) 'adminRemovedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _message(
        newRole == 'admin'
            ? '$name is now an Admin.'
            : (restoreRole == 'reporter'
                ? 'Admin access removed. $name is back as Reporter.'
                : 'Admin access removed from $name.'),
      );
    } catch (e) {
      _message('Role update failed: $e');
    }
  }

  Future<void> _makeReporter({
    required String uid,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Add Reporter'),
            content: Text('Make $name a Reporter?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Add Reporter'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    try {
      await db.collection('users').doc(uid).set({
        'role': 'reporter',
        'roleLabel': 'REPORTER',
        'reporterStatus': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      }, SetOptions(merge: true));
      _message('$name is now a Reporter.');
    } catch (e) {
      _message('Reporter update failed: $e');
    }
  }

  Future<void> _removeReporter({
    required String uid,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove Reporter'),
            content: Text('Remove Reporter access from $name?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Remove Reporter'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    try {
      final userRef = db.collection('users').doc(uid);
      await userRef.set({
        'role': 'user',
        'roleLabel': 'USER',
        'reporterStatus': 'rejected',
        'roleChangedAt': FieldValue.serverTimestamp(),
        'roleChangedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'roleBeforeAdmin': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {});
      _message('Reporter access removed from $name.');
    } catch (e) {
      _message('Reporter removal failed: $e');
    }
  }

  Widget _userStats() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').snapshots(),
      builder: (_, snapshot) {
        int users = 0;
        int reporters = 0;
        int admins = 0;
        int owners = 0;

        if (snapshot.hasData) {
          users = snapshot.data!.docs.length;

          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final role = (data['role'] ?? '').toString().trim().toLowerCase();
            final roleLabel =
                (data['roleLabel'] ?? '').toString().trim().toLowerCase();
            final effectiveRole = role == 'administrator' || role == 'admin' ||
                    roleLabel == 'administrator' || roleLabel == 'admin'
                ? 'admin'
                : (role == 'owner' || roleLabel == 'owner'
                    ? 'owner'
                    : (role == 'reporter' || roleLabel == 'reporter' ||
                            (data['reporterStatus'] ?? '')
                                    .toString()
                                    .trim()
                                    .toLowerCase() ==
                                'approved'
                        ? 'reporter'
                        : 'user'));

            if (effectiveRole == 'owner') {
              owners++;
            } else if (effectiveRole == 'admin') {
              admins++;
            } else if (effectiveRole == 'reporter') {
              reporters++;
            }
          }
        }

        final cards = [
          ['Users', users],
          ['Reporters', reporters],
          ['Admins', admins],
          ['Owners', owners],
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards.map((entry) => SizedBox(
              width: (MediaQuery.sizeOf(context).width - 38) / 2,
              child: Card(
                color: Colors.white,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry[0] as String,
                          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('${entry[1]}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ),
            )).toList(),
          ),
        );
      },
    );
  }

  Widget _userDirectory() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').snapshots(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Unable to load users:\n${snapshot.error}'),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        final allUsers = <Map<String, dynamic>>[];
        final reporters = <Map<String, dynamic>>[];
        final admins = <Map<String, dynamic>>[];
        final owners = <Map<String, dynamic>>[];

        for (final doc in docs) {
          final data = doc.data();
          final role = (data['role'] ?? '').toString().trim().toLowerCase();
          final roleLabel =
              (data['roleLabel'] ?? '').toString().trim().toLowerCase();
          final reporterStatus =
              (data['reporterStatus'] ?? '').toString().trim().toLowerCase();

          final effectiveRole =
              role == 'owner' || roleLabel == 'owner'
                  ? 'owner'
                  : role == 'admin' ||
                          role == 'administrator' ||
                          roleLabel == 'admin' ||
                          roleLabel == 'administrator'
                      ? 'admin'
                      : role == 'reporter' ||
                              roleLabel == 'reporter' ||
                              reporterStatus == 'approved'
                          ? 'reporter'
                          : 'user';

          final name = (data['name'] ??
                  data['displayName'] ??
                  data['email'] ??
                  'Unnamed User')
              .toString()
              .trim();

          final person = <String, dynamic>{
            'uid': doc.id,
            'name': name.isEmpty ? 'Unnamed User' : name,
            'email': (data['email'] ?? '').toString().trim(),
            'role': effectiveRole,
          };

          // Users section = ALL members, not only normal users.
          allUsers.add(person);

          if (effectiveRole == 'owner') {
            owners.add(person);
          } else if (effectiveRole == 'admin') {
            admins.add(person);
          } else if (effectiveRole == 'reporter') {
            reporters.add(person);
          }
        }

        String roleText(String role) {
          switch (role) {
            case 'owner':
              return 'OWNER';
            case 'admin':
              return 'ADMIN';
            case 'reporter':
              return 'REPORTER';
            default:
              return 'USER';
          }
        }

        Widget actionButton({
          required String label,
          required IconData icon,
          required VoidCallback onPressed,
        }) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
            ),
          );
        }

        Widget people(
          List<Map<String, dynamic>> list,
          String emptyText, {
          bool canManageRoles = false,
        }) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                emptyText,
                style: const TextStyle(color: Colors.black54),
              ),
            );
          }

          return Column(
            children: list.map((person) {
              final role = (person['role'] ?? 'user').toString();
              final isOwner = role == 'owner';
              final isAdmin = role == 'admin';
              final isReporter = role == 'reporter';
              final label = roleText(role);

              Widget? actions;

              if (canManageRoles && !isOwner) {
                if (isReporter) {
                  actions = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actionButton(
                        label: 'Make Admin',
                        icon: Icons.admin_panel_settings_outlined,
                        onPressed: () => _changeUserRole(
                          uid: person['uid'] as String,
                          name: person['name'] as String,
                          newRole: 'admin',
                        ),
                      ),
                      const SizedBox(height: 8),
                      actionButton(
                        label: 'Remove Reporter',
                        icon: Icons.person_remove_outlined,
                        onPressed: () => _removeReporter(
                          uid: person['uid'] as String,
                          name: person['name'] as String,
                        ),
                      ),
                    ],
                  );
                } else if (isAdmin) {
                  actions = actionButton(
                    label: 'Remove Admin',
                    icon: Icons.person_remove_outlined,
                    onPressed: () => _changeUserRole(
                      uid: person['uid'] as String,
                      name: person['name'] as String,
                      newRole: 'user',
                    ),
                  );
                } else {
                  actions = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      actionButton(
                        label: 'Make Admin',
                        icon: Icons.admin_panel_settings_outlined,
                        onPressed: () => _changeUserRole(
                          uid: person['uid'] as String,
                          name: person['name'] as String,
                          newRole: 'admin',
                        ),
                      ),
                      const SizedBox(height: 8),
                      actionButton(
                        label: 'Make Reporter',
                        icon: Icons.edit_note_outlined,
                        onPressed: () => _makeReporter(
                          uid: person['uid'] as String,
                          name: person['name'] as String,
                        ),
                      ),
                    ],
                  );
                }
              }

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE5E5E5)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor:
                              isOwner ? Colors.blueGrey : _ownerRed,
                          child: Icon(
                            isOwner
                                ? Icons.verified_user_outlined
                                : isAdmin
                                    ? Icons.admin_panel_settings_outlined
                                    : isReporter
                                        ? Icons.edit_note_outlined
                                        : Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                person['name'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                (person['email'] as String).isEmpty
                                    ? label
                                    : '${person['email'] as String} • $label',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (actions != null) ...[
                      const SizedBox(height: 12),
                      actions,
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ExpansionTile(
                leading: const Icon(Icons.people_outline),
                title: Text(
                  'Users (${allUsers.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                children: [
                  SizedBox(
                    height: 420,
                    child: SingleChildScrollView(
                      child: people(
                        allUsers,
                        'No users found.',
                        canManageRoles: true,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1),
              ExpansionTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: Text(
                  'Reporters (${reporters.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                children: [
                  people(
                    reporters,
                    'No reporters found.',
                    canManageRoles: true,
                  ),
                ],
              ),
              const Divider(height: 1),
              ExpansionTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(
                  'Admins (${admins.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                children: [
                  people(
                    admins,
                    'No admins found.',
                    canManageRoles: true,
                  ),
                ],
              ),
              const Divider(height: 1),
              ExpansionTile(
                leading: const Icon(Icons.verified_user_outlined),
                title: Text(
                  'Owners (${owners.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                children: [
                  people(
                    owners,
                    'No owners found.',
                  ),
                ],
              ),
            ],
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

  Widget _publishedNews() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db
          .collection('news')
          .orderBy('publishedAt', descending: true)
          .snapshots(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Unable to load published news:\n${snapshot.error}'),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No published news.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final data = doc.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final category = (data['category'] ?? 'దేశం').toString();
            final content = (data['content'] ?? data['description'] ?? '')
                .toString();

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
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
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _editNews(doc),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteNews(doc),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _ownerRed,
                            ),
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

  Widget _dataImage(String value, {double height = 190}) {
    if (!value.startsWith('data:image/')) {
      return const SizedBox.shrink();
    }
    try {
      final comma = value.indexOf(',');
      if (comma <= 0) return const SizedBox.shrink();
      final bytes = base64Decode(value.substring(comma + 1));
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          bytes,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
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
                    const SizedBox(height: 10),
                    if (imageUrl.isNotEmpty) _dataImage(imageUrl, height: 190),
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
                            onPressed: () => _editNews(doc),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectPost(doc),
                        icon: const Icon(Icons.close),
                        label: const Text('Reject'),
                      ),
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
