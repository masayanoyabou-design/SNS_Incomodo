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

class Post {
  const Post({
    required this.slot,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.constructionStartedAt,
  });

  /// New or moved posts are "under construction" for this long before
  /// they can receive letters — prevents hopping posts to read letters.
  static const constructionPeriod = Duration(hours: 48);

  final PostSlot slot;
  final String name;
  final double latitude;
  final double longitude;

  /// Set by the server when the post is created or its location changes.
  final DateTime constructionStartedAt;

  DateTime get activatesAt => constructionStartedAt.add(constructionPeriod);

  bool isActive(DateTime now) => !now.isBefore(activatesAt);

  /// Time left until the post becomes active; zero once active.
  Duration remainingConstruction(DateTime now) {
    final remaining = activatesAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

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
