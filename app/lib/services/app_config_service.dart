import 'package:cloud_firestore/cloud_firestore.dart';

/// Settings the server holds for every copy of the app, at `config/app`.
/// Only ever written from the Firebase console.
class AppConfigService {
  AppConfigService(this._firestore);

  final FirebaseFirestore _firestore;

  /// The oldest build still allowed to run, or null if none is set.
  Stream<int?> watchMinimumBuild() => _firestore
      .collection('config')
      .doc('app')
      .snapshots()
      .map((doc) => (doc.data()?['minBuild'] as num?)?.toInt());
}
