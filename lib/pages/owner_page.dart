import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
                final now = DateTime.now();
                final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
                final m = now.minute.toString().padLeft(2, '0');
                final suffix = now.hour >= 12 ? 'PM' : 'AM';

                await db.collection('news').add({
                  'category': category,
                  'title': title.text.trim(),
                  'description': description.text.trim(),
                  'content': description.text.trim(),
                  'imageUrl': '',
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
              'సినిమా',
              'క్రీడలు',
              'టెక్నాలజీ',
              'బిజినెస్',
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

    const categories = [
      'తెలంగాణ',
      'ఆంధ్రప్రదేశ్',
      'దేశం',
      'సినిమా',
      'క్రీడలు',
      'టెక్నాలజీ',
      'బిజినెస్',
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
                await doc.reference.update({
                  'title': title.text.trim(),
                  'description': content.text.trim(),
                  'content': content.text.trim(),
                  'category': category,
                  'breaking': breaking,
                  'editedAt': FieldValue.serverTimestamp(),
                  'editedBy':
                      FirebaseAuth.instance.currentUser?.uid ?? '',
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

  Widget _userStats() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: db.collection('users').snapshots(),
      builder: (_, snapshot) {
        int users = 0;
        int admins = 0;

        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data();
            final role = (data['role'] ?? '').toString().trim().toLowerCase();

            if (role == 'admin') {
              admins++;
            } else if (role == 'user' ||
                role == 'reporter' ||
                role.isEmpty) {
              users++;
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Users',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$users',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Card(
                  color: Colors.white,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Admins',
                          style: TextStyle(
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$admins',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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

        final docs = snapshot.data?.docs ?? [];
        final users = <Map<String, String>>[];
        final admins = <Map<String, String>>[];

        for (final doc in docs) {
          final data = doc.data();
          final role = (data['role'] ?? '').toString().trim().toLowerCase();
          final name = (data['name'] ??
                  data['displayName'] ??
                  data['email'] ??
                  'Unnamed User')
              .toString()
              .trim();
          final email = (data['email'] ?? '').toString().trim();

          final person = {
            'name': name.isEmpty ? 'Unnamed User' : name,
            'email': email,
          };

          if (role == 'admin') {
            admins.add(person);
          } else if (role == 'user' ||
              role == 'reporter' ||
              role.isEmpty) {
            users.add(person);
          }
        }

        Widget people(List<Map<String, String>> list, String emptyText) {
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
            children: list
                .map(
                  (person) => ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 18,
                      backgroundColor: _ownerRed,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                    title: Text(
                      person['name']!,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: person['email']!.isEmpty
                        ? null
                        : Text(person['email']!),
                  ),
                )
                .toList(),
          );
        }

        return Card(
          margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          color: Colors.white,
          child: Column(
            children: [
              ExpansionTile(
                leading: const Icon(Icons.people_outline),
                title: Text(
                  'Users (${users.length})',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                children: [
                  people(users, 'No users found.'),
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
                  people(admins, 'No admins found.'),
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
                    Container(
                      height: 120,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0D47A1),
                            Color(0xFF1976D2),
                            Color(0xFF001B44),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'BREAKING NEWS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
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
