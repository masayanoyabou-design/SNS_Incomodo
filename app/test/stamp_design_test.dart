import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/models/stamp_design.dart';
import 'package:incomodo/theme/stamp_art.dart';
import 'package:incomodo/widgets/stamp_view.dart';

void main() {
  test('the ordinary stamp is the default', () {
    expect(StampDesign.byId(StampDesign.defaultId), StampDesign.basic);
    expect(StampDesign.free, contains(StampDesign.basic));
  });

  test('an unknown or missing design falls back to the ordinary stamp', () {
    // Letters sent before designs existed have no stampId; a newer app may
    // send a design this one has never heard of.
    expect(StampDesign.byId(null), StampDesign.basic);
    expect(StampDesign.byId('from_the_future'), StampDesign.basic);
  });

  test('every free design has artwork of its own', () {
    for (final design in StampDesign.free) {
      if (design == StampDesign.basic) continue;
      expect(StampArt.of(design), isNot(same(StampArt.of(StampDesign.basic))),
          reason: '${design.id} is drawn as the ordinary stamp');
    }
  });

  test('opening a letter keeps its stamp', () {
    final letter = Letter(
      id: 'l1',
      direction: LetterDirection.received,
      counterpartUid: 'u2',
      counterpartDisplayName: '後藤',
      counterpartHandle: 'goto',
      sentAt: DateTime(2026, 9, 16),
      stampId: 'sakura',
    );
    final opened = letter.markOpened(DateTime(2026, 9, 17)).withBody('やあ');

    expect(opened.stamp, StampDesign.sakura);
    expect(opened.isOpened, isTrue);
  });

  testWidgets('a stamp says which one it is to a screen reader',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: StampView(design: StampDesign.sakura))),
    ));

    expect(find.bySemanticsLabel('桜の切手'), findsOneWidget);
    semantics.dispose();
  });
}
