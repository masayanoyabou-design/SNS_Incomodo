import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stamp_wallet.dart';
import '../services/stamp_service.dart';
import 'auth_provider.dart';

final stampServiceProvider =
    Provider<StampService>((ref) => StampService(FirebaseFirestore.instance));

/// The stamps the signed-in user is holding, or null before the first
/// handout has landed.
final stampWalletProvider = StreamProvider<StampWallet?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(stampServiceProvider).watch(user.uid);
});
