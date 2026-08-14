
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_item.dart';

class NewsService {
  final db = FirebaseFirestore.instance;
  Stream<List<NewsItem>> watchNews([String? category]) {
    Query<Map<String, dynamic>> q = db.collection('news');
    if (category != null && category != 'అన్నీ') {
      q = q.where('category', isEqualTo: category);
    }
    // Do not use Firestore orderBy here: documents created by older
    // versions may not have publishedAt, and Firestore excludes those
    // documents from an orderBy query. Read every news document and sort
    // locally so no published news disappears from the app.
    return q.snapshots().map((s) {
      final items = s.docs
          .map((d) => NewsItem.fromMap(d.id, d.data()))
          .toList();

      items.sort((a, b) {
        final ad = a.publishedAt;
        final bd = b.publishedAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

      return items;
    });
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
