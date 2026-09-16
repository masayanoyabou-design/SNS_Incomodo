import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/theme/incomodo_theme.dart';
import 'package:incomodo/widgets/letter_paper.dart';
import 'package:incomodo/widgets/postmark.dart';

void main() {
  final openedOn = DateTime(2026, 9, 17, 14, 5);

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(
        theme: buildIncomodoTheme(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ));

  test('a postmark dates things the way a post office does', () {
    expect(formatPostmarkDate(openedOn), '2026.9.17');
  });

  testWidgets('the postmark carries the day it was opened', (tester) async {
    await pump(tester, Postmark(date: openedOn));

    expect(find.text('INCOMODO POST'), findsOneWidget);
    expect(find.text('2026.9.17'), findsOneWidget);
  });

  testWidgets('a screen reader hears the date, not "INCOMODO POST"',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, Postmark(date: openedOn));

    expect(find.bySemanticsLabel('消印 2026.9.17'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the postmark carries where it was opened', (tester) async {
    await pump(tester, Postmark(date: openedOn, place: '自宅'));

    expect(find.text('自宅'), findsOneWidget);
    expect(find.text('INCOMODO POST'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen reader hears the place too', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, Postmark(date: openedOn, place: '自宅'));

    expect(find.bySemanticsLabel('消印 自宅 2026.9.17'), findsOneWidget);
    semantics.dispose();
  });

  test('a long place is cut to fit the ring, a blank one is none', () {
    expect(postmarkPlace('おばあちゃんの家の前の郵便局'), 'おばあちゃんの…');
    expect(postmarkPlace('自宅'), '自宅');
    expect(postmarkPlace('  '), isNull);
    expect(postmarkPlace(null), isNull);
  });

  testWidgets('the longest place a post can have still fits', (tester) async {
    await pump(tester, Postmark(date: openedOn, place: 'あ' * 20, size: 64));

    expect(tester.takeException(), isNull);
  });

  testWidgets('letter paper shows the writing', (tester) async {
    await pump(tester, const LetterPaper(body: '駅前のカフェで待ってる'));

    expect(find.text('駅前のカフェで待ってる'), findsOneWidget);
    expect(find.byType(Postmark), findsNothing);
  });

  testWidgets('an opened letter is stamped', (tester) async {
    await pump(
      tester,
      LetterPaper(body: '駅前のカフェで待ってる', corner: Postmark(date: openedOn)),
    );

    expect(find.text('2026.9.17'), findsOneWidget);
  });

  testWidgets('a long letter lays out without overflowing', (tester) async {
    await pump(tester, LetterPaper(body: 'あ' * 1000));

    expect(tester.takeException(), isNull);
  });
}
