import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/letter.dart';
import '../models/user_profile.dart';
import 'stamp_service.dart';

/// Letters, written in three pieces by one batch:
///
/// - `users/{to}/letters/{id}` — the envelope the recipient sees
/// - `users/{to}/letters/{id}/content/body` — the text, which the rules
///   refuse to serve until the envelope has been opened
/// - `users/{from}/sentLetters/{id}` — the sender's own copy, so they can
///   watch it go from delivered to received
class LetterService {
  LetterService(this._firestore);

  final FirebaseFirestore _firestore;

  static const _bodyDocId = 'body';

  CollectionReference<Map<String, dynamic>> _received(String uid) =>
      _firestore.collection('users').doc(uid).collection('letters');

  CollectionReference<Map<String, dynamic>> _sent(String uid) =>
      _firestore.collection('users').doc(uid).collection('sentLetters');

  DocumentReference<Map<String, dynamic>> _body(String uid, String letterId) =>
      _received(uid).doc(letterId).collection('content').doc(_bodyDocId);

  /// Delivers a letter. Only works if [to] has accepted [from] as a friend
  /// — that entry is what grants the permission (enforced in the rules).
  ///
  /// The stamp is spent in the same batch: out of stamps means the whole
  /// thing is refused, so a letter can never go out unpaid.
  Future<void> sendLetter({
    required UserProfile from,
    required UserProfile to,
    required String body,
  }) async {
    final error = Letter.validateBody(body);
    if (error != null) throw ArgumentError(error);
    final trimmed = body.trim();

    final id = _received(to.uid).doc().id;
    await (_firestore.batch()
          ..update(StampService.walletRef(_firestore, from.uid),
              {'count': FieldValue.increment(-1)})
          ..set(_received(to.uid).doc(id), {
            'fromUid': from.uid,
            'fromDisplayName': from.displayName,
            'fromHandle': from.handle,
            'sentAt': FieldValue.serverTimestamp(),
            'openedAt': null,
          })
          ..set(_body(to.uid, id), {'body': trimmed})
          ..set(_sent(from.uid).doc(id), {
            'toUid': to.uid,
            'toDisplayName': to.displayName,
            'toHandle': to.handle,
            'body': trimmed,
            'sentAt': FieldValue.serverTimestamp(),
            'openedAt': null,
          }))
        .commit();
  }

  Stream<List<Letter>> watchReceived(String uid) =>
      _received(uid).orderBy('sentAt', descending: true).snapshots().map(
            (s) => s.docs
                .map((doc) => _toLetter(doc, LetterDirection.received))
                .toList(),
          );

  Stream<List<Letter>> watchSent(String uid) =>
      _sent(uid).orderBy('sentAt', descending: true).snapshots().map(
            (s) => s.docs
                .map((doc) => _toLetter(doc, LetterDirection.sent))
                .toList(),
          );

  /// Marks a letter opened, on both copies, so the sender sees "受取完了".
  ///
  /// Whether the reader is actually standing at one of their posts is
  /// decided by the app — the rules can't check location (see MANUAL 15).
  Future<void> open({required String uid, required Letter letter}) =>
      (_firestore.batch()
            ..update(_received(uid).doc(letter.id),
                {'openedAt': FieldValue.serverTimestamp()})
            ..update(_sent(letter.counterpartUid).doc(letter.id),
                {'openedAt': FieldValue.serverTimestamp()}))
          .commit();

  /// Fetches the text of a received letter. The server only answers once
  /// the letter has been opened.
  Future<String?> readBody({required String uid, required String letterId}) =>
      _body(uid, letterId).get().then((doc) => doc.data()?['body'] as String?);

  Letter _toLetter(
    DocumentSnapshot<Map<String, dynamic>> doc,
    LetterDirection direction,
  ) {
    final data = doc.data()!;
    final prefix = direction == LetterDirection.received ? 'from' : 'to';
    final sentAt = data['sentAt'] as Timestamp?;
    final openedAt = data['openedAt'] as Timestamp?;
    return Letter(
      id: doc.id,
      direction: direction,
      counterpartUid: data['${prefix}Uid'] as String? ?? '',
      counterpartDisplayName: data['${prefix}DisplayName'] as String? ?? '',
      counterpartHandle: data['${prefix}Handle'] as String? ?? '',
      // Pending local writes have no server time yet; show it as just now.
      sentAt: sentAt?.toDate() ?? DateTime.now(),
      openedAt: openedAt?.toDate(),
      body: data['body'] as String?,
    );
  }
}
