
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

  Future<void> chooseImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 88,
    );
    if (x != null) setState(() => image = File(x.path));
  }

  void loadForEdit(NewsItem n) {
    setState(() {
      editingId = n.id;
      oldImageUrl = n.imageUrl;
      title.text = n.title;
      desc.text = n.description;
      content.text = n.content;
      category.text = n.category;
      breaking = n.breaking;
      image = null;
    });
  }

  void clearForm() {
    setState(() {
      editingId = null; oldImageUrl = null; image = null; breaking = false;
      title.clear(); desc.clear(); content.clear(); category.text = 'తెలంగాణ';
    });
  }

  Future<void> save() async {
    if (title.text.trim().isEmpty || content.text.trim().isEmpty) return;
    setState(() => saving = true);
    try {
      var url = oldImageUrl ?? '';
      if (image != null) url = await service.uploadImage(image!);
      final item = NewsItem(
        id: editingId ?? '',
        category: category.text.trim(),
        title: title.text.trim(),
        description: desc.text.trim(),
        content: content.text.trim(),
        imageUrl: url,
        time: editingId == null ? 'ఇప్పుడే' : 'Updated',
        publishedAt: Timestamp.now().toDate(),
        breaking: breaking,
      );
      if (editingId == null) {
        await service.add(item);
      } else {
        await service.update(editingId!, item);
      }
      clearForm();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(editingId == null ? 'News published' : 'News updated')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    title.dispose(); desc.dispose(); content.dispose(); category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SRI News Admin'),
        actions: [IconButton(onPressed: auth.logout, icon: const Icon(Icons.logout))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(editingId == null ? 'Publish News' : 'Edit News',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Headline')),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
          TextField(controller: desc, decoration: const InputDecoration(labelText: 'Short description')),
          TextField(controller: content, maxLines: 7,
            decoration: const InputDecoration(labelText: 'Full article')),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: chooseImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(image == null ? 'Choose image' : 'Change image'),
          ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(image!, height: 170, fit: BoxFit.cover),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Breaking News'),
            value: breaking,
            onChanged: (v) => setState(() => breaking = v),
          ),
          Row(children: [
            Expanded(child: FilledButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : editingId == null ? 'Publish' : 'Update'),
            )),
            if (editingId != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: clearForm, child: const Text('Cancel')),
            ],
          ]),
          const SizedBox(height: 22),
          const Divider(),
          const Text('News Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          StreamBuilder<List<NewsItem>>(
            stream: service.watchNews(),
            builder: (_, s) {
              final items = s.data ?? [];
              if (items.isEmpty) return const Padding(
                padding: EdgeInsets.all(20), child: Text('No news published yet.'));
              return Column(
                children: items.map((n) => Card(
                  child: ListTile(
                    title: Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(n.category),
                    leading: n.imageUrl.isEmpty
                      ? const Icon(Icons.article_outlined)
                      : Image.network(n.imageUrl, width: 55, height: 55, fit: BoxFit.cover),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') loadForEdit(n);
                        if (v == 'delete') await service.delete(n.id);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
