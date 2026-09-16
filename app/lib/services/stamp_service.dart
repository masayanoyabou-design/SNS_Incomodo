import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/stamp_wallet.dart';

/// The stamps a user is holding, at `users/{uid}/stamps/wallet`.
///
/// Spending happens inside the letter's own batch (see [walletRef] and
/// LetterService), so a letter can never be sent without its stamp.
class StampService {
  StampService(this._firestore);

  final FirebaseFirestore _firestore;

  static DocumentReference<Map<String, dynamic>> walletRef(
          FirebaseFirestore firestore, String uid) =>
      firestore.collection('users').doc(uid).collection('stamps').doc('wallet');

  DocumentReference<Map<String, dynamic>> _wallet(String uid) =>
      walletRef(_firestore, uid);

  Stream<StampWallet?> watch(String uid) =>
      _wallet(uid).snapshots().map(_toWallet);

  /// Hands out today's stamps if they haven't been handed out yet. Safe to
  /// call on every launch: the rules only accept a refill dated today, so
  /// calling it twice in a day changes nothing.
  Future<void> ensureToday({required String uid}) async {
    final doc = await _wallet(uid).get();
    final wallet = _toWallet(doc);

    if (wallet == null) {
      await _wallet(uid).set({
        'count': StampWallet.dailyRefill,
        'refilledOn': Timestamp.fromDate(jstDate(DateTime.now())),
      });
      return;
    }
    if (!wallet.isStale(DateTime.now())) return;

    await _wallet(uid).update({
      'count': StampWallet.afterRefill(wallet.count),
      'refilledOn': Timestamp.fromDate(jstDate(DateTime.now())),
    });
  }

  StampWallet? _toWallet(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    return StampWallet(
      count: (data['count'] as num?)?.toInt() ?? 0,
      refilledOn:
          (data['refilledOn'] as Timestamp?)?.toDate() ?? DateTime.utc(1970),
    );
  }
}
