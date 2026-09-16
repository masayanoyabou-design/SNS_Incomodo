import 'dart:math' as math;

/// A mailbox location where a user can receive letters (PRD F-01).
///
/// Each user has exactly four fixed slots, so the "max 4, only one home"
/// rule is enforced by the data shape itself (and by Firestore rules).
enum PostSlot {
  home('home', '自宅'),
  slot1('slot1', '拠点1'),
  slot2('slot2', '拠点2'),
  slot3('slot3', '拠点3');

  const PostSlot(this.id, this.label);

  /// Firestore document ID for this slot.
  final String id;
  final String label;

  bool get isHome => this == PostSlot.home;

  static PostSlot fromId(String id) =>
      PostSlot.values.firstWhere((slot) => slot.id == id);
}

/// Great-circle distance in metres between two coordinates (haversine).
double distanceInMeters({
  required double fromLatitude,
  required double fromLongitude,
  required double toLatitude,
  required double toLongitude,
}) {
  const earthRadius = 6371000.0;
  double toRadians(double degrees) => degrees * math.pi / 180;

  final dLat = toRadians(toLatitude - fromLatitude);
  final dLng = toRadians(toLongitude - fromLongitude);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRadians(fromLatitude)) *
          math.cos(toRadians(toLatitude)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

class Post {
  const Post({
    required this.slot,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.constructionStartedAt,
    this.firstPost = false,
  });

  /// New or moved posts are "under construction" for this long before
  /// they can receive letters — prevents hopping posts to read letters.
  static const constructionPeriod = Duration(hours: 48);

  /// You must stand this close to a post to open its letters (PRD F-01).
  static const unlockRadiusMeters = 50.0;

  final PostSlot slot;
  final String name;
  final double latitude;
  final double longitude;

  /// Set by the server when the post is created or its location changes.
  final DateTime constructionStartedAt;

  /// The first post an account ever registers opens for letters straight
  /// away: a newcomer shouldn't have to wait two days to try the app. Only
  /// once per account (enforced in the rules), and moving it ends it.
  final bool firstPost;

  DateTime get activatesAt => firstPost
      ? constructionStartedAt
      : constructionStartedAt.add(constructionPeriod);

  bool isActive(DateTime now) => !now.isBefore(activatesAt);

  /// Time left until the post becomes active; zero once active.
  Duration remainingConstruction(DateTime now) {
    final remaining = activatesAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double distanceFrom(double latitude, double longitude) => distanceInMeters(
        fromLatitude: latitude,
        fromLongitude: longitude,
        toLatitude: this.latitude,
        toLongitude: this.longitude,
      );

  bool isWithinUnlockRadius(double latitude, double longitude) =>
      distanceFrom(latitude, longitude) <= unlockRadiusMeters;

  /// Letters here can only be opened standing at an already-active post
  /// — the whole point of Incomodo: you have to go there.
  bool canOpenLetters({
    required DateTime now,
    required double latitude,
    required double longitude,
  }) =>
      isActive(now) && isWithinUnlockRadius(latitude, longitude);

  /// Returns an error message, or null if the input is valid.
  static String? validate({
    required String name,
    required double latitude,
    required double longitude,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'ポストの名前を入力してください';
    if (trimmed.length > 20) return 'ポストの名前は20文字以内にしてください';
    if (latitude < -90 || latitude > 90) return '緯度が正しくありません';
    if (longitude < -180 || longitude > 180) return '経度が正しくありません';
    return null;
  }
}
