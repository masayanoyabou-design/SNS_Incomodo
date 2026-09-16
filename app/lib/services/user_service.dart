import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

class HandleTakenException implements Exception {
  @override
  String toString() => 'そのIDは既に使われています';
}

/// Profiles, handle lookup, and the friend connections that letters need.
///
/// Letters may only be sent to someone who has accepted you, so the
/// "friends" entry under a user is what grants others permission to
/// write to them (enforced in firestore.rules).
class UserService {
  UserService(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  Stream<UserProfile?> watchProfile(String uid) =>
      _user(uid).snapshots().map((doc) => _toProfile(doc));

  /// Claims [handle] and creates the profile in one atomic write, so two
  /// people racing for the same handle can't both win.
  Future<void> createProfile({
    required String uid,
    required String displayName,
    required String handle,
  }) async {
    final normalized = UserProfile.normalizeHandle(handle);
    final nameError = UserProfile.validateDisplayName(displayName);
    if (nameError != null) throw ArgumentError(nameError);
    final handleError = UserProfile.validateHandle(normalized);
    if (handleError != null) throw ArgumentError(handleError);

    final handleRef = _firestore.collection('handles').doc(normalized);
    if ((await handleRef.get()).exists) throw HandleTakenException();

    final batch = _firestore.batch()
      ..set(handleRef, {'uid': uid})
      ..set(_user(uid), {
        'displayName': displayName.trim(),
        'handle': normalized,
      });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      // The rules reject a create on an existing handle document.
      if (e.code == 'permission-denied') throw HandleTakenException();
      rethrow;
    }
  }

  Future<void> updateDisplayName({
    required String uid,
    required String displayName,
  }) async {
    final error = UserProfile.validateDisplayName(displayName);
    if (error != null) throw ArgumentError(error);
    await _user(uid).update({'displayName': displayName.trim()});
  }

  /// Looks up a user by the handle someone typed, or null if nobody has it.
  Future<UserProfile?> findByHandle(String handle) async {
    final normalized = UserProfile.normalizeHandle(handle);
    final handleDoc =
        await _firestore.collection('handles').doc(normalized).get();
    final uid = handleDoc.data()?['uid'] as String?;
    if (uid == null) return null;
    return _toProfile(await _user(uid).get());
  }

  /// Asks [target] to connect. They see it in their requests and accept.
  ///
  /// [reply] marks the request sent back automatically on accepting one,
  /// so that accepting *that* doesn't send yet another back.
  Future<void> sendFriendRequest({
    required UserProfile from,
    required String targetUid,
    bool reply = false,
  }) =>
      _user(targetUid).collection('friendRequests').doc(from.uid).set({
        'displayName': from.displayName,
        'handle': from.handle,
        'createdAt': FieldValue.serverTimestamp(),
        'reply': reply,
      });

  Stream<List<UserProfile>> watchFriendRequests(String uid) => _user(uid)
      .collection('friendRequests')
      .snapshots()
      .map((s) => s.docs.map(_toProfile).whereType<UserProfile>().toList());

  Stream<List<UserProfile>> watchFriends(String uid) => _user(uid)
      .collection('friends')
      .snapshots()
      .map((s) => s.docs.map(_toProfile).whereType<UserProfile>().toList());

  /// Accepting adds them to my friends (letting them write to me) and asks
  /// them back, so letters can flow both ways once they accept too.
  ///
  /// Only an original request is answered with one of our own. If this
  /// was already the answer to ours, they have accepted us and asking
  /// again would bounce requests back and forth forever.
  Future<void> acceptFriendRequest({
    required UserProfile me,
    required UserProfile requester,
  }) async {
    final requestRef =
        _user(me.uid).collection('friendRequests').doc(requester.uid);
    final wasReply = (await requestRef.get()).data()?['reply'] == true;

    await _user(me.uid).collection('friends').doc(requester.uid).set({
      'displayName': requester.displayName,
      'handle': requester.handle,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await requestRef.delete();
    if (!wasReply) {
      await sendFriendRequest(from: me, targetUid: requester.uid, reply: true);
    }
  }

  Future<void> declineFriendRequest({
    required String uid,
    required String requesterUid,
  }) =>
      _user(uid).collection('friendRequests').doc(requesterUid).delete();

  UserProfile? _toProfile(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      handle: data['handle'] as String? ?? '',
    );
  }
}
