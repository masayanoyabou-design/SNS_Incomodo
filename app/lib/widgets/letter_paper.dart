import 'package:flutter/material.dart';

import '../models/stationery.dart';
import '../theme/stationery_art.dart';

/// A sheet of letter paper: a dashed inner margin, and ruled lines that sit
/// under each line of text — the landing page's letter mock, with real
/// writing on it. Its colors and whether it is ruled come from the chosen
/// [PaperDesign].
class LetterPaper extends StatelessWidget {
  const LetterPaper({
    super.key,
    required this.body,
    this.design = PaperDesign.ruled,
    this.corner,
  });

  final String body;
  final PaperDesign design;

  /// Top-right corner: the stamp, and the postmark over it once opened.
  final Widget? corner;

  static const _fontSize = 16.0;
  static const _lineHeight = 1.9;
  static const _padding = EdgeInsets.fromLTRB(24, 28, 24, 32);
  static const _cornerSpace = 96.0;

  @override
  Widget build(BuildContext context) {
    final art = PaperArt.of(design);
    final style = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: _fontSize,
          height: _lineHeight,
          color: art.ink,
        );

    return Semantics(
      label: design.name,
      child: Container(
        width: double.infinity,
        // A one-line letter should still look like a sheet of paper, with
        // empty rules below it — not a strip with a single line.
        constraints: const BoxConstraints(minHeight: 280),
        decoration: BoxDecoration(
          color: art.paper,
          border: Border.all(color: art.rule),
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
          painter: _PaperPainter(
            rule: art.ruled ? art.rule : null,
            margin: art.rule.withValues(alpha: art.rule.a * 0.5),
            firstLineTop: _padding.top + (corner == null ? 0 : _cornerSpace),
            lineHeight: _fontSize * _lineHeight,
            sidePadding: _padding.left,
          ),
          child: Padding(
            padding: _padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (corner != null)
                  SizedBox(
                    height: _cornerSpace,
                    child: Align(alignment: Alignment.topRight, child: corner),
                  ),
                SelectableText(body, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  _PaperPainter({
    required this.rule,
    required this.margin,
    required this.firstLineTop,
    required this.lineHeight,
    required this.sidePadding,
  });

  /// Null for unruled paper.
  final Color? rule;
  final Color margin;
  final double firstLineTop;
  final double lineHeight;
  final double sidePadding;

  @override
  void paint(Canvas canvas, Size size) {
    // The dashed margin 8px in, like the letter mock's ::after.
    final dashed = Paint()
      ..color = margin
      ..strokeWidth = 1;
    const inset = 8.0;
    const dash = 4.0;
    const gap = 3.0;
    void dashedLine(Offset from, Offset to) {
      final length = (to - from).distance;
      final direction = (to - from) / length;
      for (var d = 0.0; d < length; d += dash + gap) {
        canvas.drawLine(from + direction * d,
            from + direction * (d + dash).clamp(0, length), dashed);
      }
    }

    final r =
        Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset);
    dashedLine(r.topLeft, r.topRight);
    dashedLine(r.topRight, r.bottomRight);
    dashedLine(r.bottomRight, r.bottomLeft);
    dashedLine(r.bottomLeft, r.topLeft);

    // A rule under every line of writing, down to the bottom margin.
    final rule = this.rule;
    if (rule == null) return;
    final ruled = Paint()
      ..color = rule
      ..strokeWidth = 1;
    for (var y = firstLineTop + lineHeight - 4;
        y < size.height - inset - 8;
        y += lineHeight) {
      canvas.drawLine(
          Offset(sidePadding, y), Offset(size.width - sidePadding, y), ruled);
    }
  }

  @override
  bool shouldRepaint(_PaperPainter old) =>
      old.rule != rule ||
      old.margin != margin ||
      old.firstLineTop != firstLineTop ||
      old.lineHeight != lineHeight;
}
