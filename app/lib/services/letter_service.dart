import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/letter.dart';
import '../models/stamp_design.dart';
import '../models/stationery.dart';
import '../models/user_profile.dart';
import 'slow_response.dart';
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
  ///
  /// The stamp and envelope go on the envelope document, which the
  /// recipient sees straight away. The paper goes with the text, which
  /// they don't get until they open it.
  Future<void> sendLetter({
    required UserProfile from,
    required UserProfile to,
    required String body,
    required StampDesign stamp,
    required EnvelopeDesign envelope,
    required PaperDesign paper,
  }) async {
    final error = Letter.validateBody(body);
    if (error != null) throw ArgumentError(error);
    final trimmed = body.trim();

    final id = _received(to.uid).doc().id;
    await handOver(
        (_firestore.batch()
          ..update(StampService.walletRef(_firestore, from.uid),
              {'count': FieldValue.increment(-1)})
          ..set(_received(to.uid).doc(id), {
            'fromUid': from.uid,
            'fromDisplayName': from.displayName,
            'fromHandle': from.handle,
            'stampId': stamp.id,
            'envelopeId': envelope.id,
            'sentAt': FieldValue.serverTimestamp(),
            'openedAt': null,
          })
          ..set(_body(to.uid, id), {'body': trimmed, 'paperId': paper.id})
          ..set(_sent(from.uid).doc(id), {
            'toUid': to.uid,
            'toDisplayName': to.displayName,
            'toHandle': to.handle,
            'stampId': stamp.id,
            'envelopeId': envelope.id,
            'paperId': paper.id,
            'body': trimmed,
            'sentAt': FieldValue.serverTimestamp(),
            'openedAt': null,
          }))
        .commit(),
        limit: _writeLimit,
        message: '電波が戻りしだい、自動で届きます。「送った手紙」で「送信待ち」になっています。'
            'もう一度送る必要はありません',
    );
  }

  /// How long a write is waited on before the screen moves on (B32). The
  /// write itself isn't cancelled: it is queued and goes out later.
  static const _writeLimit = Duration(seconds: 20);

  Stream<List<Letter>> watchReceived(String uid) =>
      _received(uid).orderBy('sentAt', descending: true).snapshots().map(
            (s) => s.docs
                .map((doc) => _toLetter(doc, LetterDirection.received))
                .toList(),
          );

  /// Includes letters the server hasn't confirmed yet, marked pending, so one
  /// sent without signal shows as waiting instead of looking delivered.
  Stream<List<Letter>> watchSent(String uid) => _sent(uid)
      .orderBy('sentAt', descending: true)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.docs
          .map((doc) => _toLetter(doc, LetterDirection.sent))
          .toList());

  /// Marks a letter opened, on both copies, so the sender sees "受取完了".
  ///
  /// [place] is the name of the post it was opened at, for the postmark.
  /// It goes on the recipient's copy only — see [Letter.openedPlace].
  ///
  /// Whether the reader is actually standing at one of their posts is
  /// decided by the app — the rules can't check location (see MANUAL 15).
  Future<void> open({
    required String uid,
    required Letter letter,
    required String place,
  }) async {
    final mine = _received(uid).doc(letter.id);
    final opening = {
      'openedAt': FieldValue.serverTimestamp(),
      'openedPlace': place,
    };
    final both = (_firestore.batch()
          ..update(mine, opening)
          ..update(_sent(letter.counterpartUid).doc(letter.id),
              {'openedAt': FieldValue.serverTimestamp()}))
        .commit();
    // The fallback hangs off the write itself rather than the waiting, so it
    // still happens if the refusal only arrives after the screen gave up.
    final opened = both.then<void>((_) {}, onError: (Object e) {
      // The sender may have thrown their copy away (B25). Nobody is left to
      // tell, but that mustn't stop the letter being opened.
      if (e is! FirebaseException ||
          (e.code != 'not-found' && e.code != 'permission-denied')) {
        throw e;
      }
      debugPrint('Sender\'s copy of ${letter.id} is gone; opening ours only');
      return mine.update(opening);
    });
    await handOver(
      opened,
      limit: _writeLimit,
      message: '開封を受け付けました。電波が戻ると、手紙が読めるようになります',
    );
  }

  /// Throws a letter away — only your own copy (B25).
  ///
  /// A received letter goes with its text, sealed or not; a sealed one is
  /// then never read. A sent letter only loses the sender's copy: what was
  /// delivered stays with the recipient.
  Future<void> delete({required String uid, required Letter letter}) =>
      handOver(
        switch (letter.direction) {
          LetterDirection.received => (_firestore.batch()
                ..delete(_body(uid, letter.id))
                ..delete(_received(uid).doc(letter.id)))
              .commit(),
          LetterDirection.sent => _sent(uid).doc(letter.id).delete(),
        },
        limit: _writeLimit,
        message: '電波が戻ると、手紙が一覧から消えます',
      );

  /// Fetches what is inside a received letter: its text and the paper it is
  /// written on. The server only answers once the letter has been opened.
  Future<({String body, String paperId})?> readContents({
    required String uid,
    required String letterId,
  }) async {
    final data = (await answerWithin(
      _body(uid, letterId).get(),
      limit: const Duration(seconds: 15),
      message: '手紙を読み込めませんでした。電波の良い場所で、開き直してください',
    ))
        .data();
    final body = data?['body'] as String?;
    if (body == null) return null;
    return (
      body: body,
      paperId: data?['paperId'] as String? ?? PaperDesign.defaultId,
    );
  }

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
      openedPlace: data['openedPlace'] as String?,
      body: data['body'] as String?,
      stampId: data['stampId'] as String? ?? StampDesign.defaultId,
      envelopeId: data['envelopeId'] as String? ?? EnvelopeDesign.defaultId,
      // Only the sender's copy has it; a received letter learns its paper
      // from readContents once opened.
      paperId: data['paperId'] as String? ?? PaperDesign.defaultId,
      pending: doc.metadata.hasPendingWrites,
    );
  }
}
