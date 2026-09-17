import 'post.dart';

/// One post as the map shows it — worked out without reference to any map
/// package, so the map widget can be swapped without touching this.
class PostPin {
  const PostPin({
    required this.slot,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.active,
    required this.remaining,
  });

  final PostSlot slot;
  final String name;
  final double latitude;
  final double longitude;

  /// Finished: letters can be opened within [Post.unlockRadiusMeters].
  final bool active;

  /// Construction left; zero once [active].
  final Duration remaining;

  /// "工事中（あと3時間20分）", or "使えます".
  String get statusLabel {
    if (active) return '使えます';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    return hours > 0 ? '工事中（あと$hours時間$minutes分）' : '工事中（あと$minutes分）';
  }
}

/// The user's posts as pins, home first then the other slots in order.
List<PostPin> postPins(Iterable<Post> posts, DateTime now) => [
      for (final post in posts.toList()
        ..sort((a, b) => a.slot.index.compareTo(b.slot.index)))
        PostPin(
          slot: post.slot,
          name: post.name,
          latitude: post.latitude,
          longitude: post.longitude,
          active: post.isActive(now),
          remaining: post.remainingConstruction(now),
        ),
    ];

/// Every point the map should have in view when it opens: the posts, and
/// where you are if that is known. Empty when there is nothing to show.
List<({double latitude, double longitude})> pointsToShow(
  List<PostPin> pins,
  ({double latitude, double longitude})? here,
) =>
    [
      for (final pin in pins) (latitude: pin.latitude, longitude: pin.longitude),
      ?here,
    ];
