
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/news_item.dart';

class NewsService {
  final db = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;

  Stream<List<NewsItem>> watchNews([String? category]) {
    Query<Map<String, dynamic>> q = db.collection('news');
    if (category != null && category != 'అన్నీ') {
      q = q.where('category', isEqualTo: category);
    }
    q = q.orderBy('publishedAt', descending: true);
    return q.snapshots().map(
      (s) => s.docs.map((d) => NewsItem.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<String> uploadImage(File file) async {
    final ref = storage.ref(
      'news_images/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Future<String> add(NewsItem item) async =>
      (await db.collection('news').add(item.toMap())).id;

  Future<void> update(String id, NewsItem item) =>
      db.collection('news').doc(id).update(item.toMap());

  Future<void> delete(String id) =>
      db.collection('news').doc(id).delete();
}
