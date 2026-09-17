import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/account_service.dart';
import '../services/safety_service.dart';
import 'auth_provider.dart';

final safetyServiceProvider =
    Provider<SafetyService>((ref) => SafetyService(FirebaseFirestore.instance));

final accountServiceProvider = Provider<AccountService>((ref) =>
    AccountService(FirebaseFirestore.instance, ref.watch(authServiceProvider)));

/// People the signed-in user has blocked.
final blockedProvider = StreamProvider<List<UserProfile>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(safetyServiceProvider).watchBlocked(user.uid);
});

/// Whether the operator has suspended the signed-in account (B35), by
/// creating `suspended/{uid}` in the Firebase console. Anything short of a
/// clear yes — loading, offline — counts as no: the rules enforce it anyway.
final suspendedProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('suspended')
      .doc(user.uid)
      .snapshots()
      .map((doc) => doc.exists);
});
