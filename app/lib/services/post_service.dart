import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/post.dart';
import 'slow_response.dart';

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

  /// Marks that the account's one construction-free post has been used.
  /// Never deleted, so deleting that post and registering again doesn't
  /// get a second one.
  DocumentReference<Map<String, dynamic>> _firstPostUsed(String uid) =>
      _firestore.collection('users').doc(uid).collection('meta').doc('firstPost');

  static const _readLimit = Duration(seconds: 15);
  static const _writeLimit = Duration(seconds: 20);
  static const _slowRead =
      'サーバーに接続できませんでした。電波の良い場所で、もう一度お試しください';

  /// A write that took too long may still land once the connection
  /// recovers, so this says to look again rather than to redo it.
  static const _slowWrite =
      '通信に時間がかかっています。反映されるまで少し待ってから、ポストの一覧を確認してください';

  Future<T> _read<T>(Future<T> future) =>
      answerWithin(future, limit: _readLimit, message: _slowRead);

  Future<void> _write(Future<void> future) =>
      answerWithin(future, limit: _writeLimit, message: _slowWrite);

  /// Creates a post, or updates it. Moving an existing post restarts its
  /// construction period; renaming it does not.
  ///
  /// Returns whether this was the account's first post, which needs no
  /// construction at all.
  Future<bool> savePost({
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
    final data = (await _read(ref.get())).data();

    if (data == null) {
      final used = (await _read(_firstPostUsed(uid).get())).exists;
      final fields = {
        'name': name.trim(),
        'latitude': latitude,
        'longitude': longitude,
        'constructionStartedAt': FieldValue.serverTimestamp(),
        if (!used) 'firstPost': true,
      };
      if (used) {
        await _write(ref.set(fields));
      } else {
        await _write((_firestore.batch()
              ..set(ref, fields)
              ..set(_firstPostUsed(uid),
                  {'usedAt': FieldValue.serverTimestamp()}))
            .commit());
      }
      return !used;
    }

    final moved =
        data['latitude'] != latitude || data['longitude'] != longitude;
    await _write(ref.set({
      'name': name.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'constructionStartedAt': moved
          ? FieldValue.serverTimestamp()
          : data['constructionStartedAt'],
      // A moved post is a new place, and is built like any other.
      if (!moved && data['firstPost'] == true) 'firstPost': true,
    }));
    return false;
  }

  Future<void> deletePost({required String uid, required PostSlot slot}) =>
      _write(_posts(uid).doc(slot.id).delete());

  Post _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final startedAt = data['constructionStartedAt'] as Timestamp?;
    return Post(
      slot: PostSlot.fromId(doc.id),
      name: data['name'] as String,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      constructionStartedAt: startedAt?.toDate() ?? DateTime.now(),
      firstPost: data['firstPost'] == true,
    );
  }
}
