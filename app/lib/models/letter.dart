import 'post.dart';

/// Whose side of a letter we are looking at.
enum LetterDirection { received, sent }

/// A letter between two people (PRD F-02, F-03 text).
///
/// The sender never learns where the recipient's posts are: a letter is
/// addressed to a person, and the recipient can open it at any post of
/// theirs that is finished and that they are standing at.
///
/// This is the envelope. For a letter you have received, the text itself
/// is a separate document the server refuses to hand over until the
/// letter has been opened — otherwise "you have to go there" would be
/// broken by simply reading what the phone already downloaded.
class Letter {
  const Letter({
    required this.id,
    required this.direction,
    required this.counterpartUid,
    required this.counterpartDisplayName,
    required this.counterpartHandle,
    required this.sentAt,
    this.openedAt,
    this.body,
  });

  static const maxBodyLength = 1000;

  final String id;
  final LetterDirection direction;

  /// The other person: the sender for a received letter, the recipient
  /// for a sent one.
  final String counterpartUid;
  final String counterpartDisplayName;
  final String counterpartHandle;

  final DateTime sentAt;

  /// When the recipient opened it at one of their posts; null until then.
  final DateTime? openedAt;

  /// The text. Always present on a letter you sent (you wrote it), and on
  /// a received letter only once it has been fetched after opening.
  final String? body;

  bool get isOpened => openedAt != null;

  String get counterpartHandleWithAt => '@$counterpartHandle';

  Letter withBody(String? body) => Letter(
        id: id,
        direction: direction,
        counterpartUid: counterpartUid,
        counterpartDisplayName: counterpartDisplayName,
        counterpartHandle: counterpartHandle,
        sentAt: sentAt,
        openedAt: openedAt,
        body: body,
      );

  /// The wording the PRD asks for: a sender sees delivery, then receipt.
  String get statusLabel => switch ((direction, isOpened)) {
        (LetterDirection.sent, false) => '配送完了',
        (LetterDirection.sent, true) => '受取完了',
        (LetterDirection.received, false) => '未開封',
        (LetterDirection.received, true) => '開封済み',
      };

  /// Returns an error message, or null if the letter can be sent.
  static String? validateBody(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '手紙の本文を入力してください';
    if (trimmed.length > maxBodyLength) {
      return '手紙は$maxBodyLength文字以内にしてください';
    }
    return null;
  }
}

/// The post you are standing at that letters may be opened at, or null if
/// there isn't one. Letters aren't tied to a particular post, so any
/// finished post you have reached will do.
Post? openablePost({
  required Iterable<Post> posts,
  required DateTime now,
  required double latitude,
  required double longitude,
}) {
  for (final post in posts) {
    if (post.canOpenLetters(
        now: now, latitude: latitude, longitude: longitude)) {
      return post;
    }
  }
  return null;
}

/// The post you are standing at, finished or not.
///
/// Telling "you haven't got there yet" apart from "you are there, but it
/// is still being built" matters: walking to a post and being told you
/// aren't near it would just look broken.
Post? postYouAreAt({
  required Iterable<Post> posts,
  required double latitude,
  required double longitude,
}) {
  for (final post in posts) {
    if (post.isWithinUnlockRadius(latitude, longitude)) return post;
  }
  return null;
}
