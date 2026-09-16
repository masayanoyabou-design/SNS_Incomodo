import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/models/letter.dart';
import 'package:incomodo/models/stamp_design.dart';
import 'package:incomodo/models/stationery.dart';
import 'package:incomodo/theme/stationery_art.dart';
import 'package:incomodo/widgets/design_picker.dart';
import 'package:incomodo/widgets/envelope_view.dart';
import 'package:incomodo/widgets/letter_paper.dart';

/// What every kind of stationery — stamp, envelope, paper — has to get
/// right, whichever designs it has at the time.
void main() {
  final kinds = <String, List<StationeryDesign>>{
    'freeStamp': StampDesign.free,
    'freeEnvelope': EnvelopeDesign.free,
    'freePaper': PaperDesign.free,
  };

  for (final kind in kinds.entries) {
    group(kind.key, () {
      test('has at least one design, each with its own id', () {
        final ids = kind.value.map((d) => d.id).toList();
        expect(ids, isNotEmpty);
        expect(ids.toSet(), hasLength(ids.length));
      });

      test('firestore.rules allows exactly these designs', () {
        // The rules keep their own copy of each list. If one drifts, either
        // a design can't be sent, or one nobody was given can be. Adding a
        // design means adding its id in the rules too.
        final rules = File('firestore.rules').readAsStringSync();
        final match = RegExp(
          'function ${kind.key}\\(id\\)\\s*\\{\\s*return id in \\[([^\\]]*)\\]',
        ).firstMatch(rules);
        expect(match, isNotNull, reason: '${kind.key}() not found in the rules');

        final inRules = RegExp("'([^']+)'")
            .allMatches(match!.group(1)!)
            .map((m) => m.group(1))
            .toSet();
        expect(inRules, kind.value.map((d) => d.id).toSet());
      });
    });
  }

  test('every envelope and paper design has a look', () {
    // Falling back to the default look would hide a forgotten entry in
    // theme/stationery_art.dart, so compare against the fallback.
    for (final design in EnvelopeDesign.free) {
      if (design.id == EnvelopeDesign.defaultId) continue;
      expect(EnvelopeArt.of(design),
          isNot(same(EnvelopeArt.of(EnvelopeDesign.plain))));
    }
    for (final design in PaperDesign.free) {
      if (design.id == PaperDesign.defaultId) continue;
      expect(PaperArt.of(design), isNot(same(PaperArt.of(PaperDesign.ruled))));
    }
  });

  test('unknown envelopes and paper fall back to the defaults', () {
    expect(EnvelopeDesign.byId(null), EnvelopeDesign.plain);
    expect(EnvelopeDesign.byId('from_the_future'), EnvelopeDesign.plain);
    expect(PaperDesign.byId(null), PaperDesign.ruled);
    expect(PaperDesign.byId('from_the_future'), PaperDesign.ruled);
  });

  test('a received letter learns its paper only from its contents', () {
    final sealed = Letter(
      id: 'l1',
      direction: LetterDirection.received,
      counterpartUid: 'u2',
      counterpartDisplayName: '後藤',
      counterpartHandle: 'goto',
      sentAt: DateTime(2026, 9, 16),
      stampId: 'sakura',
      envelopeId: 'plain',
    );
    expect(sealed.paperId, PaperDesign.defaultId);

    final opened = sealed
        .markOpened(DateTime(2026, 9, 17))
        .withContents(body: 'やあ', paperId: 'ruled');
    expect(opened.body, 'やあ');
    expect(opened.paper, PaperDesign.ruled);
    // Nothing else is lost on the way.
    expect(opened.stamp, StampDesign.sakura);
    expect(opened.envelope, EnvelopeDesign.plain);
    expect(opened.isOpened, isTrue);
  });

  group('DesignPicker', () {
    Future<void> pump(WidgetTester tester, List<StampDesign> designs,
            ValueChanged<StampDesign> onSelected) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: DesignPicker<StampDesign>(
              title: '貼る切手',
              designs: designs,
              selected: designs.first,
              onSelected: onSelected,
              preview: (d) => SizedBox.square(dimension: 40, child: Text(d.id)),
            ),
          ),
        ));

    testWidgets('offers the choice when there is one', (tester) async {
      StampDesign? picked;
      await pump(tester, StampDesign.free, (d) => picked = d);

      expect(find.text('貼る切手'), findsOneWidget);
      await tester.tap(find.text('青空'));
      expect(picked, StampDesign.aozora);
    });

    testWidgets('stays out of the way when there is nothing to choose',
        (tester) async {
      await pump(tester, [StampDesign.basic], (_) {});

      expect(find.text('貼る切手'), findsNothing);
    });
  });

  testWidgets('an envelope shows who it is from and its stamp',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320,
          child: EnvelopeView(
            design: EnvelopeDesign.plain,
            stamp: StampDesign.yoru,
            from: '後藤（@goto）',
          ),
        ),
      ),
    ));

    expect(find.text('後藤（@goto）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paper takes its look from the design', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LetterPaper(body: '元気？', design: PaperDesign.ruled),
        ),
      ),
    ));

    expect(find.text('元気？'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
