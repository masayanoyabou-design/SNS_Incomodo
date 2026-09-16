import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/user_service.dart';
import 'auth_provider.dart';

final userServiceProvider =
    Provider<UserService>((ref) => UserService(FirebaseFirestore.instance));

/// The signed-in user's profile, or null if they haven't set one up yet.
final myProfileProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(null);
  return ref.watch(userServiceProvider).watchProfile(user.uid);
});

final friendsProvider = StreamProvider<List<UserProfile>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(userServiceProvider).watchFriends(user.uid);
});

final friendRequestsProvider = StreamProvider<List<UserProfile>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(userServiceProvider).watchFriendRequests(user.uid);
});
