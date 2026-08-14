import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'profile_settings_page.dart';

const _adminRed = Color(0xFFE60000);
const _adminBg = Color(0xFFF7F8FA);

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final db = FirebaseFirestore.instance;
  File? _adminProfileImage;

  @override
  void initState() {
    super.initState();
    _loadAdminProfileImage();
  }

  Future<File?> _adminProfileFile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/sri_news_profile_$uid.jpg');
  }

  Future<void> _loadAdminProfileImage() async {
    final file = await _adminProfileFile();
    if (file != null && await file.exists() && mounted) {
      setState(() => _adminProfileImage = file);
    }
  }

  Future<void> _openAdminProfileSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
    );
    await _loadAdminProfileImage();
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final snap = await db.collection('users').doc(user.uid).get();
      final role = (snap.data()?['role'] ?? '').toString().trim().toLowerCase();
      return role == 'admin' || role == 'administrator';
    } catch (_) {
      return false;
    }
  }


  Future<void> _createNews() async {
    final title = TextEditingController();
    final description = TextEditingController();
    String category = 'తెలంగాణ';
    bool breaking = true;

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
              if (title.text.trim().isEmpty || description.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title and content are required.')),
                );
                return;
              }
              setSheetState(() => saving = true);
              try {
                final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                await db.collection('news').add({
                  'category': category,
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'content': description.text.trim(),
                  'imageUrl': '',
                  'time': _timeNow(),
                  'publishedAt': FieldValue.serverTimestamp(),
                  'breaking': breaking,
                  'source': 'admin',
                  'adminId': adminUid,
                  'publishedBy': adminUid,
                  'publishedByRole': 'admin',
                });
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                _message('News published successfully.');
              } catch (e) {
                _message('News publish failed: $e');
              } finally {
                if (context.mounted) setSheetState(() => saving = false);
              }
            }

            const categories = [
              'తెలంగాణ', 'ఆంధ్రప్రదేశ్', 'దేశం', 'సినిమా', 'క్రీడలు',
              'టెక్నాలజీ', 'బిజినెస్',
            ];

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18, right: 18, top: 18,
                  bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Post News', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        value: category,
                        decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                        items: categories.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
                        onChanged: saving ? null : (value) { if (value != null) setSheetState(() => category = value); },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: title,
                        enabled: !saving,
                        decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: description,
                        enabled: !saving,
                        maxLines: 8,
                        decoration: const InputDecoration(labelText: 'News Content', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Breaking News'),
                        value: breaking,
                        onChanged: saving ? null : (value) => setSheetState(() => breaking = value),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: saving ? null : publish,
                        icon: const Icon(Icons.publish),
                        label: Text(saving ? 'Publishing...' : 'Publish News'),
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

  Future<void> _reviewPost(
    DocumentSnapshot<Map<String, dynamic>> doc,
    bool approve,
  ) async {
    try {
      final p = doc.data() ?? {};
      final title = (p['title'] ?? '').toString().trim();
      final content = (p['content'] ?? '').toString().trim();

      if (title.isEmpty || content.isEmpty) {
        throw Exception('Title and content are required.');
      }

      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (!approve) {
        await doc.reference.update({
          'status': 'rejected',
          'reviewedBy': adminUid,
          'reviewedByRole': 'admin',
          'reviewedAt': FieldValue.serverTimestamp(),
        });
        _message('Reporter post rejected.');
        return;
      }

      final newsRef = db.collection('news').doc();
      await newsRef.set({
        'category': p['category'] ?? 'తెలంగాణ',
        'title': title,
        'description': p['description'] ?? content,
        'content': content,
        'imageUrl': p['mediaUrl'] ?? '',
        'time': _timeNow(),
        'publishedAt': FieldValue.serverTimestamp(),
        'breaking': false,
        'source': 'reporter',
        'reporterId': p['reporterId'] ?? '',
        'reporterName': p['reporterName'] ?? 'Reporter',
        'approvedBy': adminUid,
        'approvedByRole': 'admin',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      await doc.reference.update({
        'status': 'approved',
        'reviewedBy': adminUid,
        'reviewedByRole': 'admin',
        'reviewedAt': FieldValue.serverTimestamp(),
        'publishedNewsId': newsRef.id,
      });

      _message('Reporter post approved and published.');
    } catch (e) {
      _message('Post approval failed: $e');
    }
  }


  Future<void> _editNews(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final title = TextEditingController(text: (data['title'] ?? '').toString());
    final content = TextEditingController(
      text: (data['content'] ?? data['description'] ?? '').toString(),
    );
    String category = (data['category'] ?? 'తెలంగాణ').toString();
    bool breaking = data['breaking'] == true;
    bool saving = false;

    const categories = [
      'తెలంగాణ', 'ఆంధ్రప్రదేశ్', 'దేశం', 'సినిమా', 'క్రీడలు',
      'టెక్నాలజీ', 'బిజినెస్',
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> save() async {
            if (title.text.trim().isEmpty || content.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Title and content are required.')),
              );
              return;
            }
            setSheetState(() => saving = true);
            try {
              final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
              await doc.reference.update({
                'category': category,
                'title': title.text.trim(),
                'description': content.text.trim(),
                'content': content.text.trim(),
                'breaking': breaking,
                'editedBy': adminUid,
                'editedByRole': 'admin',
                'editedAt': FieldValue.serverTimestamp(),
              });
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              _message('News updated successfully.');
            } catch (e) {
              _message('News update failed: $e');
            } finally {
              if (context.mounted) setSheetState(() => saving = false);
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 18, right: 18, top: 18,
                bottom: 18 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Edit News', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: categories.contains(category) ? category : categories.first,
                      decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: saving ? null : (v) { if (v != null) setSheetState(() => category = v); },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      enabled: !saving,
                      decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: content,
                      enabled: !saving,
                      maxLines: 10,
                      decoration: const InputDecoration(labelText: 'News Content', border: OutlineInputBorder()),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Breaking News'),
                      value: breaking,
                      onChanged: saving ? null : (v) => setSheetState(() => breaking = v),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: saving ? null : save,
                      icon: const Icon(Icons.save),
                      label: Text(saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    title.dispose();
    content.dispose();
  }

  Widget _publishedNews() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('news').orderBy('publishedAt', descending: true).snapshots(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Unable to load published news:\n${snapshot.error}'));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('No published news.'));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            final data = doc.data();
            final title = (data['title'] ?? 'Untitled').toString();
            final source = (data['source'] ?? 'unknown').toString().toUpperCase();
            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('Source: $source'),
                trailing: IconButton(
                  tooltip: 'Edit News',
                  icon: const Icon(Icons.edit_outlined, color: _adminRed),
                  onPressed: () => _editNews(doc),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _timeNow() {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m ${now.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          return Center(child: Text('Unable to load reporter posts:\n${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'No pending reporter posts.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, index) {
            final doc = docs[index];
            final p = doc.data();
            final title = (p['title'] ?? '').toString();
            final reporter = (p['reporterName'] ?? 'Reporter').toString();
            final content = (p['content'] ?? '').toString();
            final media = (p['mediaUrl'] ?? '').toString();

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (media.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          media,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('Reporter: $reporter', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(content, maxLines: 7, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _reviewPost(doc, false),
                            icon: const Icon(Icons.close),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _reviewPost(doc, true),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve & Publish'),
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

  @override
  Widget build(BuildContext context) {
    final current = FirebaseAuth.instance.currentUser;
    if (current == null) {
      return const Scaffold(body: Center(child: Text('Admin login required.')));
    }

    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data != true) {
          return const Scaffold(
            backgroundColor: _adminBg,
            body: Center(child: Text('Access denied. Admin account required.')),
          );
        }

        return Scaffold(
          backgroundColor: _adminBg,
          appBar: AppBar(
            title: const Text('SRI NEWS Admin'),
            backgroundColor: Colors.white,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: FilledButton.icon(
                  onPressed: _createNews,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Post News'),
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openAdminProfileSettings,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: _adminRed,
                    backgroundImage: _adminProfileImage != null
                        ? FileImage(_adminProfileImage!)
                        : null,
                    child: _adminProfileImage == null
                        ? const Icon(Icons.person, color: Colors.white, size: 22)
                        : null,
                  ),
                ),
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
          body: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user_outlined, color: _adminRed, size: 30),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ADMIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          SizedBox(height: 3),
                          Text('Post news, and approve or reject reporter posts.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Reporter Post Approval', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Pending Posts'),
                          Tab(text: 'Published News'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _postApprovals(),
                            _publishedNews(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
