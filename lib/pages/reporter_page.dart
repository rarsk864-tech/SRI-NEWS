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
  @override State<ReporterPage> createState() => _ReporterPageState();
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
  void dispose() { title.dispose(); content.dispose(); phone.dispose(); location.dispose(); super.dispose(); }

  Future<void> loginOrApply() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final name = TextEditingController();
    final apply = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Reporter Login / Apply'),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name (for new reporter)')),
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
        await db.collection('reporterApplications').doc(uid).set({'uid': uid, 'name': name.text.trim().isEmpty ? (c.user!.displayName ?? '') : name.text.trim(), 'email': c.user!.email, 'status': 'pending', 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted. Owner approval required.')));
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
