import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/models/post.dart';

void main() {
  final sentAt = DateTime(2026, 9, 16, 10, 0);

  Letter letter({
    LetterDirection direction = LetterDirection.received,
    DateTime? openedAt,
  }) =>
      Letter(
        id: 'l1',
        direction: direction,
        counterpartUid: 'u2',
        counterpartDisplayName: '後藤',
        counterpartHandle: 'goto',
        sentAt: sentAt,
        openedAt: openedAt,
      );

  group('status', () {
    test('a sent letter is delivered, then received', () {
      expect(letter(direction: LetterDirection.sent).statusLabel, '配送完了');
      expect(
        letter(direction: LetterDirection.sent, openedAt: sentAt).statusLabel,
        '受取完了',
      );
    });

    test('a received letter is sealed, then opened', () {
      expect(letter().statusLabel, '未開封');
      expect(letter(openedAt: sentAt).statusLabel, '開封済み');
    });
  });

  test('a received letter carries no text until it is fetched', () {
    expect(letter().body, isNull);
    expect(letter().withBody('やあ').body, 'やあ');
    // Everything else survives the copy.
    expect(letter(openedAt: sentAt).withBody('やあ').openedAt, sentAt);
  });

  group('validateBody', () {
    test('rejects an empty letter', () {
      expect(Letter.validateBody(''), isNotNull);
      expect(Letter.validateBody('   \n '), isNotNull);
    });

    test('accepts a letter up to the limit and rejects one past it', () {
      expect(Letter.validateBody('あ' * Letter.maxBodyLength), isNull);
      expect(Letter.validateBody('あ' * (Letter.maxBodyLength + 1)), isNotNull);
    });
  });

  group('openablePost', () {
    final now = DateTime(2026, 9, 16, 12, 0);
    // 48 hours is the construction period, so this one is finished.
    final finished = now.subtract(const Duration(hours: 49));
    final justStarted = now.subtract(const Duration(hours: 1));

    Post post(String name, DateTime startedAt, {double lat = 35.0}) => Post(
          slot: PostSlot.home,
          name: name,
          latitude: lat,
          longitude: 139.0,
          constructionStartedAt: startedAt,
        );

    test('finds the finished post you are standing at', () {
      final at = openablePost(
        posts: [post('自宅', finished)],
        now: now,
        latitude: 35.0,
        longitude: 139.0,
      );
      expect(at?.name, '自宅');
    });

    test('a post still under construction does not count', () {
      expect(
        openablePost(
          posts: [post('自宅', justStarted)],
          now: now,
          latitude: 35.0,
          longitude: 139.0,
        ),
        isNull,
      );
    });

    test('a post you are far from does not count', () {
      expect(
        openablePost(
          posts: [post('自宅', finished)],
          now: now,
          latitude: 35.1, // about 11km away
          longitude: 139.0,
        ),
        isNull,
      );
    });

    test('any finished post you have reached will do', () {
      final at = openablePost(
        posts: [
          post('自宅', finished, lat: 35.1), // finished, but far
          post('拠点1', justStarted), // here, but unfinished
          post('拠点2', finished), // here and finished
        ],
        now: now,
        latitude: 35.0,
        longitude: 139.0,
      );
      expect(at?.name, '拠点2');
    });

    test('with no posts at all, there is nowhere to open a letter', () {
      expect(
        openablePost(
            posts: const [], now: now, latitude: 35.0, longitude: 139.0),
        isNull,
      );
    });
  });
}
