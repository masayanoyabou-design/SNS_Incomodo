import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/incomodo_theme.dart';

/// "2026.9.16" — the way a postmark dates things.
String formatPostmarkDate(DateTime when) =>
    '${when.year}.${when.month}.${when.day}';

/// A round postmark, the same design as the landing page's letter mock:
/// a dashed outer ring, a solid inner one, "INCOMODO POST" across the top
/// and the date below a rule.
///
/// Stamped on a letter when it is opened, so the date it carries is the
/// day someone actually went to their post (PRD F-03).
class Postmark extends StatelessWidget {
  const Postmark({
    super.key,
    required this.date,
    this.size = 84,
    this.tilt = -0.14,
  });

  final DateTime date;
  final double size;

  /// Radians. A little crooked, the way a hand stamp lands.
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final red = Theme.of(context).colorScheme.error;
    final scale = size / 80;

    return Semantics(
      label: '消印 ${formatPostmarkDate(date)}',
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
                  Text('INCOMODO POST', style: TextStyle(fontSize: 5.2 * scale)),
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
