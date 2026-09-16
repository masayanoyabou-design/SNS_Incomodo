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

/// A row of stamps to choose from, the chosen one lifted and outlined.
class StampPicker extends StatelessWidget {
  const StampPicker({
    super.key,
    required this.designs,
    required this.selected,
    required this.onSelected,
  });

  final List<StampDesign> designs;
  final StampDesign selected;
  final ValueChanged<StampDesign> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: designs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final design = designs[index];
          final isSelected = design.id == selected.id;
          return Semantics(
            selected: isSelected,
            button: true,
            child: InkWell(
              onTap: () => onSelected(design),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(3),
                      transform: Matrix4.translationValues(0, isSelected ? -3 : 0, 0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? scheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: StampView(design: design),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      design.name,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isSelected ? scheme.primary : null,
                            fontWeight: isSelected ? FontWeight.w700 : null,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
