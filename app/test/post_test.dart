import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/post.dart';

void main() {
  final startedAt = DateTime.utc(2026, 9, 16, 10);

  Post buildPost() => Post(
        slot: PostSlot.home,
        name: '自宅',
        latitude: 35.6812,
        longitude: 139.7671,
        constructionStartedAt: startedAt,
      );

  group('PostSlot', () {
    test('there are exactly four slots, and only one is home', () {
      expect(PostSlot.values, hasLength(4));
      expect(PostSlot.values.where((s) => s.isHome), hasLength(1));
    });

    test('round-trips through its Firestore document ID', () {
      for (final slot in PostSlot.values) {
        expect(PostSlot.fromId(slot.id), slot);
      }
    });
  });

  group('construction period', () {
    test('lasts 48 hours', () {
      expect(buildPost().activatesAt, startedAt.add(const Duration(hours: 48)));
    });

    test('post is under construction just before 48 hours', () {
      final now = startedAt.add(const Duration(hours: 47, minutes: 59));
      final post = buildPost();
      expect(post.isActive(now), isFalse);
      expect(post.remainingConstruction(now), const Duration(minutes: 1));
    });

    test('post becomes active exactly at 48 hours', () {
      final now = startedAt.add(const Duration(hours: 48));
      final post = buildPost();
      expect(post.isActive(now), isTrue);
      expect(post.remainingConstruction(now), Duration.zero);
    });

    test('remaining time never goes negative after activation', () {
      final now = startedAt.add(const Duration(days: 10));
      expect(buildPost().remainingConstruction(now), Duration.zero);
    });

    test('the first post of an account needs no construction', () {
      final first = Post(
        slot: PostSlot.home,
        name: '自宅',
        latitude: 35.6812,
        longitude: 139.7671,
        constructionStartedAt: startedAt,
        firstPost: true,
      );
      expect(first.isActive(startedAt), isTrue);
      expect(first.remainingConstruction(startedAt), Duration.zero);
      expect(
        first.canOpenLetters(
            now: startedAt, latitude: 35.6812, longitude: 139.7671),
        isTrue,
      );
    });
  });

  group('unlock radius', () {
    // Tokyo Station. 0.001 degrees of latitude is about 111 m.
    const postLat = 35.6812;
    const postLng = 139.7671;
    final activeNow = startedAt.add(const Duration(hours: 49));

    Post postAt() => Post(
          slot: PostSlot.home,
          name: '自宅',
          latitude: postLat,
          longitude: postLng,
          constructionStartedAt: startedAt,
        );

    test('distance to the same point is zero', () {
      expect(postAt().distanceFrom(postLat, postLng), closeTo(0, 0.1));
    });

    test('0.001 degrees of latitude is about 111 m', () {
      expect(
        postAt().distanceFrom(postLat + 0.001, postLng),
        closeTo(111, 1),
      );
    });

    test('30 m away is inside the radius, 80 m away is outside', () {
      // 0.00027 deg ≈ 30 m, 0.00072 deg ≈ 80 m.
      expect(postAt().isWithinUnlockRadius(postLat + 0.00027, postLng), isTrue);
      expect(postAt().isWithinUnlockRadius(postLat + 0.00072, postLng), isFalse);
    });

    test('an active post within the radius can be opened', () {
      expect(
        postAt().canOpenLetters(
            now: activeNow, latitude: postLat, longitude: postLng),
        isTrue,
      );
    });

    test('standing at a post still under construction cannot be opened', () {
      expect(
        postAt().canOpenLetters(
          now: startedAt.add(const Duration(hours: 47)),
          latitude: postLat,
          longitude: postLng,
        ),
        isFalse,
      );
    });

    test('an active post cannot be opened from far away', () {
      expect(
        postAt().canOpenLetters(
            now: activeNow, latitude: postLat + 0.01, longitude: postLng),
        isFalse,
      );
    });
  });

  group('validate', () {
    String? check({String name = '会社', double lat = 35.0, double lng = 139.0}) =>
        Post.validate(name: name, latitude: lat, longitude: lng);

    test('accepts a normal post', () {
      expect(check(), isNull);
    });

    test('rejects an empty or whitespace-only name', () {
      expect(check(name: ''), isNotNull);
      expect(check(name: '   '), isNotNull);
    });

    test('rejects names longer than 20 characters', () {
      expect(check(name: 'あ' * 20), isNull);
      expect(check(name: 'あ' * 21), isNotNull);
    });

    test('rejects out-of-range coordinates', () {
      expect(check(lat: 90.1), isNotNull);
      expect(check(lat: -90.1), isNotNull);
      expect(check(lng: 180.1), isNotNull);
      expect(check(lng: -180.1), isNotNull);
    });
  });
}
