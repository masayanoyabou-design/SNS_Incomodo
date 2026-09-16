import 'package:flutter/material.dart';

import '../models/stamp_design.dart';
import '../models/stationery.dart';
import '../theme/stationery_art.dart';
import 'stamp_view.dart';

/// A sealed letter, drawn the way everyone draws one (✉️): a closed flap
/// folded down to a point, the side folds meeting beneath it, the chosen
/// stamp in the corner and who it is from.
///
/// Before reaching the post, this is all of the letter there is to see.
class EnvelopeView extends StatelessWidget {
  const EnvelopeView({
    super.key,
    required this.design,
    required this.stamp,
    required this.from,
  });

  final EnvelopeDesign design;
  final StampDesign stamp;

  /// "後藤雅也（@goto）".
  final String from;

  static const maxWidth = 360.0;

  @override
  Widget build(BuildContext context) {
    final art = EnvelopeArt.of(design);
    final text = Theme.of(context).textTheme;

    return Semantics(
      label: '${design.name}。差出人 $from。${stamp.name}の切手',
      excludeSemantics: true,
      // An envelope is a hand-held size. Without a cap it grows with the
      // screen, and on a tablet pushes everything under it out of view.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: AspectRatio(
            aspectRatio: 5 / 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: art.ink.withValues(alpha: 0.18),
                    offset: const Offset(0, 12),
                    blurRadius: 28,
                    spreadRadius: -18,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _EnvelopePainter(art),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: StampView(design: stamp, width: 58),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '差出人',
                              style: text.labelSmall?.copyWith(color: art.ink),
                            ),
                            Text(
                              from,
                              style: text.titleSmall?.copyWith(color: art.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  _EnvelopePainter(this.art);

  final EnvelopeArt art;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = art.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Body.
    canvas.drawRect(Offset.zero & size, Paint()..color = art.paper);

    // Side folds, from the bottom corners up to where they tuck under the
    // flap.
    final meet = Offset(w / 2, h * 0.5);
    canvas.drawLine(Offset(0, h), meet, line);
    canvas.drawLine(Offset(w, h), meet, line);

    // The flap, folded down over them to a point.
    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w / 2, h * 0.58)
      ..close();
    canvas.drawPath(flap, Paint()..color = art.flap);
    canvas.drawPath(flap, line);

    // Edge.
    canvas.drawRect(Offset.zero & size, line);
  }

  @override
  bool shouldRepaint(_EnvelopePainter old) => old.art != art;
}
