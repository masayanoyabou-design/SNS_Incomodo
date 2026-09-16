import 'package:flutter/material.dart';

import '../models/stamp_design.dart';
import '../theme/incomodo_theme.dart';
import '../theme/stamp_art.dart';

/// A postage stamp: perforated white edge, colored panel, motif, and
/// "INCOMODO" printed along the bottom.
class StampView extends StatelessWidget {
  const StampView({super.key, required this.design, this.width = 56});

  final StampDesign design;

  /// Height follows at 6:5, the usual shape of a stamp.
  final double width;

  @override
  Widget build(BuildContext context) {
    final art = StampArt.of(design);
    final height = width * 1.2;
    final scale = width / 56;

    return Semantics(
      label: '${design.name}の切手',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _PerforatedPainter(
            paper: IncomodoColors.card,
            shadow: IncomodoColors.inkFaintest,
            holeRadius: 2.2 * scale,
          ),
          child: Padding(
            padding: EdgeInsets.all(6 * scale),
            child: DecoratedBox(
              decoration: BoxDecoration(color: art.panel),
              child: Column(
                children: [
                  const Spacer(),
                  Icon(art.motif, color: art.ink, size: 22 * scale),
                  const Spacer(),
                  Text(
                    'INCOMODO',
                    style: TextStyle(
                      color: art.ink,
                      fontFamily: IncomodoFonts.typewriter,
                      fontSize: 5.4 * scale,
                      letterSpacing: 0.4,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The white paper of the stamp, with half-circles bitten out along every
/// edge. The bites are cleared to transparent rather than painted in a
/// background color, so the stamp looks right on paper, cards or anything.
class _PerforatedPainter extends CustomPainter {
  _PerforatedPainter({
    required this.paper,
    required this.shadow,
    required this.holeRadius,
  });

  final Color paper;
  final Color shadow;
  final double holeRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect.inflate(2), Paint());

    // A hairline all the way round, not a drop shadow: the stamp's white
    // paper sits on white-ish cards, and without an edge on every side the
    // perforations only showed along two of them.
    canvas.drawRect(rect.inflate(0.8), Paint()..color = shadow);
    canvas.drawRect(rect, Paint()..color = paper);

    final punch = Paint()..blendMode = BlendMode.clear;
    final step = holeRadius * 3;
    void edge(Offset from, Offset to) {
      final length = (to - from).distance;
      final count = (length / step).floor();
      final gap = length / count;
      final direction = (to - from) / length;
      for (var i = 0; i <= count; i++) {
        canvas.drawCircle(from + direction * (gap * i), holeRadius, punch);
      }
    }

    edge(rect.topLeft, rect.topRight);
    edge(rect.bottomLeft, rect.bottomRight);
    edge(rect.topLeft, rect.bottomLeft);
    edge(rect.topRight, rect.bottomRight);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PerforatedPainter old) =>
      old.paper != paper || old.holeRadius != holeRadius;
}
