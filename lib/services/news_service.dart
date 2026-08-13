
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_item.dart';

class NewsService {
  final db = FirebaseFirestore.instance;
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

  // Image uploads are disabled in the SRI NEWS Spark-plan build.
  // Kept as a compatibility method for the legacy Admin page.
  Future<String> uploadImage(dynamic file) async {
    return '';
  }

  Future<String> add(NewsItem item) async =>
      (await db.collection('news').add(item.toMap())).id;

  Future<void> update(String id, NewsItem item) =>
      db.collection('news').doc(id).update(item.toMap());

  Future<void> delete(String id) =>
      db.collection('news').doc(id).delete();
}
