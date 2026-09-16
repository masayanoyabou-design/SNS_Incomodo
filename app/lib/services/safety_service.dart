import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report.dart';
import '../models/user_profile.dart';
import 'slow_response.dart';

/// Blocking and reporting (B33).
///
/// Blocking needs no one else's cooperation: letters may only be written
/// by people on the recipient's own friends list, so taking someone off it
/// stops their letters, and the rules refuse friend requests and letters
/// from anyone on the recipient's blocked list besides.
class SafetyService {
  SafetyService(this._firestore);

  final FirebaseFirestore _firestore;

  static const _writeLimit = Duration(seconds: 20);

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _firestore.collection('users').doc(uid);

  /// Blocks [target]: they stop being a friend, any request from them is
  /// cleared, and they can't send either again. Letters already received
  /// stay until thrown away.
  Future<void> block({required String uid, required UserProfile target}) =>
      handOver(
        (_firestore.batch()
              ..set(_user(uid).collection('blocked').doc(target.uid), {
                'displayName': target.displayName,
                'handle': target.handle,
                'blockedAt': FieldValue.serverTimestamp(),
              })
              ..delete(_user(uid).collection('friends').doc(target.uid))
              ..delete(
                  _user(uid).collection('friendRequests').doc(target.uid)))
            .commit(),
        limit: _writeLimit,
        message: '電波が戻ると、ブロックが反映されます',
      );

  /// Lifts a block. It doesn't make them a friend again: that takes a new
  /// request, like the first time.
  Future<void> unblock({required String uid, required String targetUid}) =>
      handOver(
        _user(uid).collection('blocked').doc(targetUid).delete(),
        limit: _writeLimit,
        message: '電波が戻ると、ブロックの解除が反映されます',
      );

  Stream<List<UserProfile>> watchBlocked(String uid) => _user(uid)
      .collection('blocked')
      .snapshots()
      .map((s) => [
            for (final doc in s.docs)
              UserProfile(
                uid: doc.id,
                displayName: doc.data()['displayName'] as String? ?? '',
                handle: doc.data()['handle'] as String? ?? '',
              ),
          ]);

  /// Sends a report for the operator to look at in the Firebase console.
  /// Nobody can read reports from the app — not even the reporter.
  Future<void> report({
    required String reporterUid,
    required String targetUid,
    required ReportReason reason,
    String detail = '',
    String? letterId,
  }) {
    final trimmed = detail.trim();
    if (trimmed.length > maxReportDetailLength) {
      throw ArgumentError('$maxReportDetailLength文字以内にしてください');
    }
    return handOver(
      _firestore.collection('reports').doc().set({
        'reporterUid': reporterUid,
        'targetUid': targetUid,
        'reason': reason.id,
        'detail': trimmed,
        'letterId': ?letterId,
        'createdAt': FieldValue.serverTimestamp(),
      }),
      limit: _writeLimit,
      message: '電波が戻ると、通報が送られます',
    );
  }
}
