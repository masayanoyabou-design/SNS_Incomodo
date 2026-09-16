import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Deleting an account from inside the app (B34), as both app stores
/// require.
///
/// What is removed is everything that is the user's own: profile, handle,
/// posts, stamps, friends, requests, blocks, and the letters in their
/// boxes (received ones with their text). Letters they sent stay with
/// whoever received them, as the terms say.
///
/// One thing is kept on purpose: the marker that the account's
/// construction-free first post was used (MANUAL 28). Signing in again
/// with the same Google account gives the same uid, and deleting the
/// account must not be a way to get another one.
class AccountService {
  AccountService(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final AuthService _auth;

  /// Firestore allows 500 writes to a batch; stay well inside it.
  static const _batchSize = 400;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Deletes the signed-in account. [handle] is the user's ID, to free it.
  ///
  /// Asks the user to sign in with Google again first: Firebase only
  /// deletes an account that signed in recently, and finding that out after
  /// the data is gone would leave an empty account behind.
  Future<void> deleteAccount({
    required String uid,
    required String handle,
  }) async {
    await _auth.reauthenticateWithGoogle();

    final refs = <DocumentReference<Map<String, dynamic>>>[];
    for (final name in ['friends', 'friendRequests', 'blocked', 'posts',
        'sentLetters']) {
      refs.addAll((await _user(uid).collection(name).get()).docs
          .map((d) => d.reference));
    }
    // A received letter's text is a subdocument, and it would outlive its
    // envelope. Its path is known, so it can go without being read — which
    // the rules wouldn't allow for a sealed letter anyway.
    for (final letter in (await _user(uid).collection('letters').get()).docs) {
      refs
        ..add(letter.reference.collection('content').doc('body'))
        ..add(letter.reference);
    }
    for (var i = 0; i < refs.length; i += _batchSize) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(i).take(_batchSize)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    // Last, and together: the rules only let the stamp wallet go in the same
    // write as the profile (or it could be deleted and refilled at will).
    // Keeping the profile to the end also means that if anything above
    // fails, the account still works and deleting can be tried again.
    await (_firestore.batch()
          ..delete(_user(uid).collection('stamps').doc('wallet'))
          ..delete(_firestore.collection('handles').doc(handle))
          ..delete(_user(uid)))
        .commit();

    await _auth.deleteCurrentUser();
  }
}
