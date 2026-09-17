import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/post.dart';
import 'package:incomodo/models/post_map.dart';
import 'package:incomodo/providers/post_provider.dart';
import 'package:incomodo/screens/post_map_screen.dart';

void main() {
  final now = DateTime(2026, 9, 17, 12);

  Post post(PostSlot slot, String name, {required Duration builtAgo}) => Post(
        slot: slot,
        name: name,
        latitude: 35.68 + slot.index * 0.01,
        longitude: 139.76,
        constructionStartedAt: now.subtract(builtAgo),
      );

  group('postPins', () {
    test('puts home first, then the other slots in order', () {
      final pins = postPins([
        post(PostSlot.slot2, '駅前', builtAgo: const Duration(days: 3)),
        post(PostSlot.home, '自宅', builtAgo: const Duration(days: 3)),
      ], now);

      expect(pins.map((p) => p.name), ['自宅', '駅前']);
    });

    test('says whether each post can open letters yet', () {
      final pins = postPins([
        post(PostSlot.home, '自宅', builtAgo: const Duration(days: 3)),
        post(PostSlot.slot1, '会社',
            builtAgo: const Duration(hours: 44, minutes: 40)),
      ], now);

      expect(pins[0].statusLabel, '使えます');
      expect(pins[1].statusLabel, '工事中（あと3時間20分）');
    });

    test('the first post of an account is ready at once', () {
      final pins = postPins([
        Post(
          slot: PostSlot.home,
          name: '自宅',
          latitude: 35.68,
          longitude: 139.76,
          constructionStartedAt: now,
          firstPost: true,
        ),
      ], now);

      expect(pins.single.active, isTrue);
    });
  });

  test('the map opens on the posts and, once known, where you are', () {
    final pins = postPins(
        [post(PostSlot.home, '自宅', builtAgo: const Duration(days: 3))], now);

    expect(pointsToShow(pins, null), hasLength(1));
    expect(
      pointsToShow(pins, (latitude: 35.7, longitude: 139.8)),
      hasLength(2),
    );
    expect(pointsToShow(const [], null), isEmpty);
  });

  group('ポストの地図', () {
    Future<void> pump(WidgetTester tester, Map<PostSlot, Post> posts) =>
        tester.pumpWidget(ProviderScope(
          overrides: [
            postsProvider.overrideWith((ref) => Stream.value(posts)),
            clockProvider.overrideWith((ref) => Stream.value(now)),
          ],
          child: const MaterialApp(home: PostMapScreen(showTiles: false)),
        ));

    testWidgets('lists each post under the map', (tester) async {
      await pump(tester, {
        PostSlot.home:
            post(PostSlot.home, '自宅', builtAgo: const Duration(days: 3)),
        PostSlot.slot1: post(PostSlot.slot1, '会社',
            builtAgo: const Duration(hours: 44, minutes: 40)),
      });
      await tester.pumpAndSettle();

      expect(find.text('自宅「自宅」・使えます'), findsOneWidget);
      expect(find.text('拠点1「会社」・工事中（あと3時間20分）'), findsOneWidget);
      expect(find.textContaining('50m以内'), findsOneWidget);
      expect(find.text('OpenStreetMap contributors'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with no posts yet, says how to set one up', (tester) async {
      await pump(tester, const {});
      await tester.pumpAndSettle();

      expect(find.textContaining('まだポストがありません'), findsOneWidget);
    });
  });
}
