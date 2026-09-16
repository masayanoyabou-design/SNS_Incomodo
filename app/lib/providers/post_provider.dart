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

/// Where the user last asked us to check they are. Null until they tap
/// the button — Incomodo never looks in the background. Shared so the
/// home screen and the letters both work off the same answer.
class HereNotifier extends Notifier<({double latitude, double longitude})?> {
  @override
  ({double latitude, double longitude})? build() => null;

  /// Asks the device where we are and remembers it.
  Future<void> check() async {
    final position =
        await ref.read(locationServiceProvider).getCurrentPosition();
    state = (latitude: position.latitude, longitude: position.longitude);
  }
}

final hereProvider =
    NotifierProvider<HereNotifier, ({double latitude, double longitude})?>(
        HereNotifier.new);

/// The signed-in user's posts, keyed by slot. Empty when signed out.
final postsProvider = StreamProvider<Map<PostSlot, Post>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const {});
  return ref
      .watch(postServiceProvider)
      .watchPosts(user.uid)
      .map((posts) => {for (final post in posts) post.slot: post});
});
