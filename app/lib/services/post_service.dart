import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';

/// Reads and writes a user's posts at `users/{uid}/posts/{slotId}`.
class PostService {
  PostService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _posts(String uid) =>
      _firestore.collection('users').doc(uid).collection('posts');

  Stream<List<Post>> watchPosts(String uid) {
    // Include pending local writes: the server timestamp isn't known until
    // the write lands, so estimate it rather than dropping the post.
    return _posts(uid).snapshots(includeMetadataChanges: true).map(
          (snapshot) => snapshot.docs.map(_fromDoc).toList(),
        );
  }

  /// Creates a post, or updates it. Moving an existing post restarts its
  /// construction period; renaming it does not.
  Future<void> savePost({
    required String uid,
    required PostSlot slot,
    required String name,
    required double latitude,
    required double longitude,
  }) async {
    final error =
        Post.validate(name: name, latitude: latitude, longitude: longitude);
    if (error != null) throw ArgumentError(error);

    final ref = _posts(uid).doc(slot.id);
    final existing = await ref.get();
    final data = existing.data();
    final moved = data == null ||
        data['latitude'] != latitude ||
        data['longitude'] != longitude;

    await ref.set({
      'name': name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'constructionStartedAt': moved
          ? FieldValue.serverTimestamp()
          : data['constructionStartedAt'],
    });
  }

  Future<void> deletePost({required String uid, required PostSlot slot}) =>
      _posts(uid).doc(slot.id).delete();

  Post _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final startedAt = data['constructionStartedAt'] as Timestamp?;
    return Post(
      slot: PostSlot.fromId(doc.id),
      name: data['name'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      constructionStartedAt: startedAt?.toDate() ?? DateTime.now(),
    );
  }
}
