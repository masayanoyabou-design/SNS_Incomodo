import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/widgets/letter_card.dart';

void main() {
  final sentAt = DateTime(2026, 9, 16, 15, 4);

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

  Future<void> pump(
    WidgetTester tester,
    Letter letter, {
    String? openableAtPostName,
    String? waitingAtPostName,
    bool locationKnown = false,
  }) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: LetterCard(
            letter: letter,
            openableAtPostName: openableAtPostName,
            waitingAtPostName: waitingAtPostName,
            locationKnown: locationKnown,
          ),
        ),
      ));

  group('formatStamp', () {
    test('drops the year for letters sent this year', () {
      expect(formatStamp(sentAt, now: DateTime(2026, 12, 1)), '9月16日 15:04');
    });

    test('keeps the year for older letters', () {
      expect(
        formatStamp(sentAt, now: DateTime(2027, 1, 1)),
        '2026年9月16日 15:04',
      );
    });
  });

  testWidgets('standing at a post, a sealed letter says it can be opened',
      (tester) async {
    await pump(tester, letter(),
        openableAtPostName: '自宅', locationKnown: true);

    expect(find.text('後藤さんから'), findsOneWidget);
    expect(find.textContaining('未開封'), findsOneWidget);
    expect(find.textContaining('「自宅」に着いています'), findsOneWidget);
  });

  testWidgets('standing at a post still being built, it says so',
      (tester) async {
    // Not "you aren't near a post" — you are standing right at it.
    await pump(tester, letter(),
        waitingAtPostName: '自宅', locationKnown: true);

    expect(find.textContaining('「自宅」に着いていますが'), findsOneWidget);
    expect(find.textContaining('ポストの近くではありません'), findsNothing);
  });

  testWidgets('away from every post, it says to go there', (tester) async {
    await pump(tester, letter(), locationKnown: true);

    expect(find.textContaining('ポストの近くではありません'), findsOneWidget);
  });

  testWidgets('before checking, it says to check where you are',
      (tester) async {
    await pump(tester, letter());

    expect(find.textContaining('現在地を確認すると'), findsOneWidget);
  });

  testWidgets('an opened letter has no hint left to give', (tester) async {
    await pump(tester, letter(openedAt: sentAt),
        openableAtPostName: '自宅', locationKnown: true);

    expect(find.textContaining('開封済み'), findsOneWidget);
    expect(find.textContaining('着いています'), findsNothing);
  });

  testWidgets('a sent letter shows delivery, then receipt', (tester) async {
    await pump(tester, letter(direction: LetterDirection.sent));
    expect(find.text('後藤さんへ'), findsOneWidget);
    expect(find.textContaining('配送完了'), findsOneWidget);
    // A sent letter never nags the sender about their own location.
    expect(find.textContaining('現在地'), findsNothing);

    await pump(tester,
        letter(direction: LetterDirection.sent, openedAt: sentAt));
    expect(find.textContaining('受取完了'), findsOneWidget);
  });
}
