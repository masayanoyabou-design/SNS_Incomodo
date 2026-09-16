import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/letter.dart';
import '../services/letter_service.dart';
import 'auth_provider.dart';

final letterServiceProvider =
    Provider<LetterService>((ref) => LetterService(FirebaseFirestore.instance));

/// Letters delivered to the signed-in user, newest first.
final receivedLettersProvider = StreamProvider<List<Letter>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(letterServiceProvider).watchReceived(user.uid);
});

/// Letters the signed-in user has sent, newest first.
final sentLettersProvider = StreamProvider<List<Letter>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(letterServiceProvider).watchSent(user.uid);
});

/// How many delivered letters are still sealed — the badge on the home
/// screen. Deliberately the only hint you get: there are no notifications.
final unopenedCountProvider = Provider<int>((ref) =>
    ref.watch(receivedLettersProvider).value?.where((l) => !l.isOpened).length ??
    0);
