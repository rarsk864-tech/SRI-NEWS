import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InteractionService {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _likes(String newsId) =>
      db.collection('news').doc(newsId).collection('likes');

  CollectionReference<Map<String, dynamic>> _comments(String newsId) =>
      db.collection('news').doc(newsId).collection('comments');

  Stream<int> likeCount(String newsId) =>
      _likes(newsId).snapshots().map((s) => s.size);

  Stream<int> commentCount(String newsId) =>
      _comments(newsId).snapshots().map((s) => s.size);

  Stream<bool> likedByMe(String newsId) {
    return auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream<bool>.value(false);
      return _likes(newsId).doc(user.uid).snapshots().map((d) => d.exists);
    });
  }

  Future<void> toggleLike(String newsId) async {
    final user = auth.currentUser;
    if (user == null) throw StateError('LOGIN_REQUIRED');
    final ref = _likes(newsId).doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> comments(String newsId) =>
      _comments(newsId).orderBy('createdAt', descending: true).snapshots();

  Future<void> addComment(String newsId, String text) async {
    final user = auth.currentUser;
    final value = text.trim();
    if (user == null) throw StateError('LOGIN_REQUIRED');
    if (value.isEmpty) return;

    await _comments(newsId).add({
      'userId': user.uid,
      'userName': user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'SRI News User'),
      'text': value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
