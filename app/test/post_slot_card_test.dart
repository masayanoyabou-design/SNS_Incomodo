import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/post.dart';
import 'package:incomodo/widgets/post_slot_card.dart';

void main() {
  final startedAt = DateTime.utc(2026, 9, 16, 10);
  final whileBuilding = startedAt.add(const Duration(hours: 1));
  final afterBuilding = startedAt.add(const Duration(hours: 49));

  final registeredPost = Post(
    slot: PostSlot.home,
    name: '自宅',
    latitude: 35.6812,
    longitude: 139.7671,
    constructionStartedAt: startedAt,
  );

  Future<void> pumpCard(
    WidgetTester tester, {
    required DateTime now,
    Post? post,
    PostSlot slot = PostSlot.home,
    double? distanceMeters,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostSlotCard(
            slot: slot,
            post: post,
            now: now,
            busy: false,
            distanceMeters: distanceMeters,
            onRegister: () {},
            onRename: () {},
            onMove: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('an empty slot offers to register', (tester) async {
    await pumpCard(tester, now: afterBuilding, slot: PostSlot.slot1);
    expect(find.text('拠点1（未登録）'), findsOneWidget);
    expect(find.text('現在地で登録'), findsOneWidget);
  });

  testWidgets('without a known location, no distance is shown', (tester) async {
    await pumpCard(tester, now: afterBuilding, post: registeredPost);
    expect(find.textContaining('現在地から'), findsNothing);
    expect(find.textContaining('ポストに到着'), findsNothing);
  });

  testWidgets('standing at an active post, letters can be opened',
      (tester) async {
    await pumpCard(tester,
        now: afterBuilding, post: registeredPost, distanceMeters: 20);
    expect(find.text('稼働中'), findsOneWidget);
    expect(find.text('ポストに到着（ここで手紙を開けます）'), findsOneWidget);
  });

  testWidgets('standing at a post still under construction, letters stay shut',
      (tester) async {
    await pumpCard(tester,
        now: whileBuilding, post: registeredPost, distanceMeters: 20);
    expect(find.textContaining('工事中'), findsOneWidget);
    expect(find.text('ポストに到着（工事が終わるまで開けません）'), findsOneWidget);
  });

  testWidgets('from far away, the distance is shown instead', (tester) async {
    await pumpCard(tester,
        now: afterBuilding, post: registeredPost, distanceMeters: 7010);
    expect(find.text('現在地から約7.0km'), findsOneWidget);
    expect(find.textContaining('ポストに到着'), findsNothing);
  });

  testWidgets('just outside the radius is not "arrived"', (tester) async {
    await pumpCard(tester,
        now: afterBuilding, post: registeredPost, distanceMeters: 51);
    expect(find.text('現在地から約51m'), findsOneWidget);
  });
}
