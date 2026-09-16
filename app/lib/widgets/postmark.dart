import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/incomodo_theme.dart';

/// "2026.9.16" — the way a postmark dates things.
String formatPostmarkDate(DateTime when) =>
    '${when.year}.${when.month}.${when.day}';

/// The place as it fits on a postmark: blank means none, and a long name
/// is cut short with "…".
String? postmarkPlace(String? place) {
  final trimmed = place?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final chars = trimmed.characters;
  return chars.length <= Postmark.maxPlaceLength
      ? trimmed
      : '${chars.take(Postmark.maxPlaceLength - 1)}…';
}

/// A round postmark, the same design as the landing page's letter mock:
/// a dashed outer ring, a solid inner one, "INCOMODO POST" across the top
/// and the date below a rule.
///
/// Stamped on a letter when it is opened, so the date it carries is the
/// day someone actually went to their post, and the place is that post
/// (PRD F-03). Without a place — on the sender's side, or a letter opened
/// before places were recorded — the top reads "INCOMODO POST".
class Postmark extends StatelessWidget {
  const Postmark({
    super.key,
    required this.date,
    this.place,
    this.size = 84,
    this.tilt = -0.14,
  });

  /// Longer names are cut to this many characters; the ring is small.
  static const maxPlaceLength = 8;

  final DateTime date;
  final String? place;
  final double size;

  /// Radians. A little crooked, the way a hand stamp lands.
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    final scale = size / 80;
    final place = postmarkPlace(this.place);

    return Semantics(
      label: ['消印', ?place, formatPostmarkDate(date)].join(' '),
      excludeSemantics: true,
      child: Transform.rotate(
        angle: tilt,
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _PostmarkPainter(red),
            child: DefaultTextStyle(
              style: TextStyle(
                color: red,
                fontFamily: IncomodoFonts.typewriter,
                height: 1,
              ),
              // Both lines have to fit inside the inner ring (r=27 of 80),
              // which is only ~46 units wide where the label sits. Android's
              // monospace runs wider than the landing page's Special Elite,
              // so these are smaller than the SVG's sizes.
              child: Column(
                children: [
                  SizedBox(height: 22 * scale),
                  if (place == null)
                    Text('INCOMODO POST',
                        style: TextStyle(fontSize: 5.2 * scale))
                  else
                    // A name is set in the letter's own mincho, shrunk to
                    // fit the ring rather than wrapped or clipped.
                    SizedBox(
                      width: 40 * scale,
                      height: 10 * scale,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          place,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: IncomodoFonts.serif,
                            fontFamilyFallback: IncomodoFonts.serifFallback,
                            fontSize: 9 * scale,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(formatPostmarkDate(date),
                      style: TextStyle(
                          fontSize: 7 * scale, fontWeight: FontWeight.w700)),
                  SizedBox(height: 23 * scale),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostmarkPainter extends CustomPainter {
  _PostmarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 80;
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke;

    // Dashed outer ring: short arcs with gaps, like r=34 / dasharray 2 3.
    paint.strokeWidth = 1.4 * scale;
    final outer = 34 * scale;
    final circumference = 2 * math.pi * outer;
    final dash = 2 * scale / circumference * 2 * math.pi;
    final gap = 3 * scale / circumference * 2 * math.pi;
    for (var a = 0.0; a < 2 * math.pi; a += dash + gap) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: outer), a, dash,
          false, paint);
    }

    // Solid inner ring and the rule across the middle.
    paint.strokeWidth = 1 * scale;
    canvas.drawCircle(center, 27 * scale, paint);
    canvas.drawLine(Offset(16 * scale, center.dy),
        Offset(size.width - 16 * scale, center.dy), paint);
  }

  @override
  bool shouldRepaint(_PostmarkPainter old) => old.color != color;
}
