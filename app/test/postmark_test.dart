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
