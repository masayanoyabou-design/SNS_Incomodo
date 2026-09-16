import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/models/stamp_design.dart';
import 'package:incomodo/theme/stamp_art.dart';
import 'package:incomodo/widgets/stamp_view.dart';

void main() {
  test('every design has its own id', () {
    final ids = StampDesign.free.map((d) => d.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

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
      final art = StampArt.of(design);
      if (design != StampDesign.basic) {
        expect(art, isNot(same(StampArt.of(StampDesign.basic))),
            reason: '${design.id} is drawn as the ordinary stamp');
      }
    }
  });

  test('firestore.rules allows exactly the free designs', () {
    // The rules keep their own copy of the list. If the two drift apart,
    // either a design can't be sent, or one nobody was given can be.
    final rules = File('firestore.rules').readAsStringSync();
    final match =
        RegExp(r"function freeStamp\(id\)\s*\{\s*return id in \[([^\]]*)\]")
            .firstMatch(rules);
    expect(match, isNotNull, reason: 'freeStamp() not found in the rules');

    final inRules = RegExp(r"'([^']+)'")
        .allMatches(match!.group(1)!)
        .map((m) => m.group(1))
        .toSet();
    expect(inRules, StampDesign.free.map((d) => d.id).toSet());
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

  testWidgets('the picker marks the chosen stamp and reports taps',
      (tester) async {
    StampDesign? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StampPicker(
          designs: StampDesign.free,
          selected: StampDesign.basic,
          onSelected: (d) => picked = d,
        ),
      ),
    ));

    await tester.tap(find.text('青空'));
    expect(picked, StampDesign.aozora);
  });
}
