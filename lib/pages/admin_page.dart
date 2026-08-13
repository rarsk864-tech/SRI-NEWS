import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/news_item.dart';
import '../services/auth_service.dart';
import '../services/news_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final service = NewsService();
  final auth = AuthService();
  final title = TextEditingController();
  final desc = TextEditingController();
  final content = TextEditingController();
  final category = TextEditingController(text: 'తెలంగాణ');
  File? image;
  String? editingId;
  String? oldImageUrl;
  bool breaking = false, saving = false;
  int tab = 0;

  Future<void> setReporterStatus(String uid, String status, String name, String email) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({'uid': uid, 'name': name, 'email': email, 'role': status == 'approved' ? 'reporter' : 'user', 'reporterStatus': status, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('reporterApplications').doc(uid).set({'status': status, 'reviewedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> reviewPost(String id, Map<String,dynamic> p, bool approve) async {
    final ref = FirebaseFirestore.instance.collection('reporterPosts').doc(id);
    if (!approve) { await ref.update({'status': 'rejected', 'reviewedAt': FieldValue.serverTimestamp()}); return; }
    await ref.update({'status': 'published', 'reviewedAt': FieldValue.serverTimestamp()});
    await FirebaseFirestore.instance.collection('news').add({
      'category': p['category'] ?? 'తెలంగాణ',
      'title': p['title'] ?? '',
      'description': p['description'] ?? '',
      'content': p['content'] ?? '',
      'imageUrl': p['mediaUrl'] ?? '',
      'time': 'Reporter',
      'publishedAt': Timestamp.now(),
      'breaking': false,
      'reporterId': p['reporterId'],
      'reporterName': p['reporterName'],
    });
  }


  Future<void> chooseImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (x != null) setState(() => image = File(x.path));
  }

  void loadForEdit(NewsItem n) => setState(() {
    editingId = n.id; oldImageUrl = n.imageUrl; title.text = n.title; desc.text = n.description;
    content.text = n.content; category.text = n.category; breaking = n.breaking; image = null;
  });

  void clearForm() => setState(() {
    editingId = null; oldImageUrl = null; image = null; breaking = false;
    title.clear(); desc.clear(); content.clear(); category.text = 'తెలంగాణ';
  });

  Future<void> save() async {
    if (title.text.trim().isEmpty || content.text.trim().isEmpty) return;
    setState(() => saving = true);
    final wasEditing = editingId != null;
    try {
      var url = oldImageUrl ?? '';
      if (image != null) url = await service.uploadImage(image!);
      final item = NewsItem(
        id: editingId ?? '', category: category.text.trim(), title: title.text.trim(),
        description: desc.text.trim(), content: content.text.trim(), imageUrl: url,
        time: wasEditing ? 'Updated' : 'ఇప్పుడే', publishedAt: Timestamp.now().toDate(), breaking: breaking,
      );
      if (wasEditing) { await service.update(editingId!, item); } else { await service.add(item); }
      clearForm();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wasEditing ? 'News updated' : 'News published')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Operation failed: $e')));
    } finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> deleteNews(NewsItem n) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Delete news?'), content: Text(n.title),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    )) ?? false;
    if (ok) await service.delete(n.id);
  }

  Widget stat(String label, Stream<QuerySnapshot<Map<String,dynamic>>> stream, IconData icon) =>
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream: stream, builder: (_, s) => Card(
      child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        CircleAvatar(child: Icon(icon)), const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text('${s.data?.size ?? 0}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        ]),
      ])),
    ));

  Widget dashboard() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Owner Dashboard', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
    const SizedBox(height: 6), const Text('SRI NEWS control center'), const SizedBox(height: 16),
    stat('Total News', FirebaseFirestore.instance.collection('news').snapshots(), Icons.article_outlined),
    stat('Users', FirebaseFirestore.instance.collection('users').snapshots(), Icons.people_outline),
    stat('Reporter Reports', FirebaseFirestore.instance.collection('reports').snapshots(), Icons.assignment_outlined),
    const SizedBox(height: 12),
    Card(child: Column(children: [
      ListTile(leading: const Icon(Icons.bolt), title: const Text('Breaking News'), subtitle: const Text('Manage breaking status from News Management')),
      ListTile(leading: const Icon(Icons.comment_outlined), title: const Text('Comments'), subtitle: const Text('Open a news item to moderate comments')),
      ListTile(leading: const Icon(Icons.security_outlined), title: const Text('Owner access'), subtitle: Text('Signed in as ${auth.auth.currentUser?.email ?? 'Owner'}')),
    ])),
  ]);

  Widget comments(NewsItem n) => StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
    stream: FirebaseFirestore.instance.collection('news').doc(n.id).collection('comments').orderBy('createdAt', descending: true).snapshots(),
    builder: (_, s) {
      final docs = s.data?.docs ?? [];
      return AlertDialog(
        title: const Text('Comments'),
        content: SizedBox(width: 520, height: 420, child: docs.isEmpty ? const Center(child: Text('No comments')) : ListView.builder(
          itemCount: docs.length, itemBuilder: (_, i) {
            final d = docs[i].data();
            return Card(child: ListTile(
              title: Text((d['text'] ?? '').toString()), subtitle: Text((d['email'] ?? d['userId'] ?? '').toString()),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
                await FirebaseFirestore.instance.collection('news').doc(n.id).collection('comments').doc(docs[i].id).delete();
              }),
            ));
          },
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      );
    },
  );

  Widget newsManagement() => ListView(padding: const EdgeInsets.all(16), children: [
    Text(editingId == null ? 'Publish News' : 'Edit News', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const SizedBox(height: 12),
    TextField(controller: title, decoration: const InputDecoration(labelText: 'Headline')),
    TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
    TextField(controller: desc, decoration: const InputDecoration(labelText: 'Short description')),
    TextField(controller: content, maxLines: 7, decoration: const InputDecoration(labelText: 'Full article')),
    const SizedBox(height: 10),
    OutlinedButton.icon(onPressed: chooseImage, icon: const Icon(Icons.photo_library_outlined), label: Text(image == null ? 'Choose image' : 'Change image')),
    if (image != null) Padding(padding: const EdgeInsets.only(top: 8), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(image!, height: 170, fit: BoxFit.cover))),
    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Breaking News'), value: breaking, onChanged: (v) => setState(() => breaking = v)),
    Row(children: [Expanded(child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving...' : editingId == null ? 'Publish' : 'Update'))),
      if (editingId != null) ...[const SizedBox(width: 8), OutlinedButton(onPressed: clearForm, child: const Text('Cancel'))]]),
    const SizedBox(height: 22), const Divider(), const Text('News Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    StreamBuilder<List<NewsItem>>(stream: service.watchNews(), builder: (_, s) {
      final items = s.data ?? [];
      return Column(children: items.map((n) => Card(child: ListTile(
        title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('${n.category}${n.breaking ? ' • BREAKING' : ''}'),
        leading: n.imageUrl.isEmpty ? const Icon(Icons.article_outlined) : Image.network(n.imageUrl, width: 55, height: 55, fit: BoxFit.cover),
        trailing: PopupMenuButton<String>(onSelected: (v) async {
          if (v == 'edit') loadForEdit(n);
          if (v == 'delete') await deleteNews(n);
          if (v == 'comments' && mounted) showDialog(context: context, builder: (_) => comments(n));
        }, itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'comments', child: Text('Manage comments')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ]),
      ))).toList());
    }),
  ]);


  Widget reporterManagement() => ListView(padding: const EdgeInsets.all(16), children: [
    const Text('Reporter Approvals', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
    const SizedBox(height: 8),
    const Text('Owner approval is required before a reporter can upload posts.'),
    const SizedBox(height: 16),
    const Text('Reporter Applications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reporterApplications').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, s) {
        final docs = s.data?.docs ?? [];
        return Column(children: docs.map((doc) {
          final d = doc.data(); final status = (d['status'] ?? 'pending').toString();
          return Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(d['name'] ?? 'Reporter'), subtitle: Text('${d['email'] ?? ''} • ${status.toUpperCase()}'),
            trailing: status == 'pending' ? Wrap(spacing: 4, children: [
              IconButton(tooltip:'Approve', onPressed: () => setReporterStatus(doc.id, 'approved', (d['name'] ?? '').toString(), (d['email'] ?? '').toString()), icon: const Icon(Icons.check_circle, color: Colors.green)),
              IconButton(tooltip:'Reject', onPressed: () => setReporterStatus(doc.id, 'rejected', (d['name'] ?? '').toString(), (d['email'] ?? '').toString()), icon: const Icon(Icons.cancel, color: Colors.red)),
            ]) : Text(status),
          ));
        }).toList());
      },
    ),
    const SizedBox(height: 22),
    const Text('Reporter Posts — Owner Review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FirebaseFirestore.instance.collection('reporterPosts').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, s) {
        final docs = s.data?.docs ?? [];
        return Column(children: docs.map((doc) {
          final p = doc.data(); final status = (p['status'] ?? 'pending').toString();
          return Card(child: ListTile(
            title: Text(p['title'] ?? ''),
            subtitle: Text(
              '${p['reporterName'] ?? 'Reporter'} • ${status.toUpperCase()}\n${p['content'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            leading: (p['mediaUrl'] ?? '').toString().isEmpty ? const Icon(Icons.article_outlined) : Image.network(p['mediaUrl'], width: 55, height: 55, fit: BoxFit.cover),
            trailing: status == 'pending' ? Wrap(spacing: 2, children: [
              IconButton(tooltip:'Publish', onPressed: () => reviewPost(doc.id, p, true), icon: const Icon(Icons.publish, color: Colors.green)),
              IconButton(tooltip:'Reject', onPressed: () => reviewPost(doc.id, p, false), icon: const Icon(Icons.block, color: Colors.red)),
            ]) : Text(status),
          ));
        }).toList());
      },
    ),
  ]);

  @override
  void dispose() { title.dispose(); desc.dispose(); content.dispose(); category.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('SRI NEWS • OWNER'), actions: [IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout))]),
    body: IndexedStack(index: tab, children: [dashboard(), newsManagement(), reporterManagement()]),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
      NavigationDestination(icon: Icon(Icons.article_outlined), selectedIcon: Icon(Icons.article), label: 'News'),
      NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge), label: 'Reporters'),
    ]),
  );
}
