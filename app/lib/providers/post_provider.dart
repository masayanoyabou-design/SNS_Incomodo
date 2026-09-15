import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../services/location_service.dart';
import '../services/post_service.dart';
import 'auth_provider.dart';

final postServiceProvider =
    Provider<PostService>((ref) => PostService(FirebaseFirestore.instance));

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());

/// Ticks every minute so construction countdowns stay current.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});

/// The signed-in user's posts, keyed by slot. Empty when signed out.
final postsProvider = StreamProvider<Map<PostSlot, Post>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const {});
  return ref
      .watch(postServiceProvider)
      .watchPosts(user.uid)
      .map((posts) => {for (final post in posts) post.slot: post});
});
