import 'package:flutter/material.dart';

import '../models/stationery.dart';

/// A row of designs to choose from — stamps, envelopes or paper — the
/// chosen one lifted and outlined.
///
/// With only one design on offer there is nothing to choose, so this draws
/// nothing at all. That lets the write screen always include a picker for
/// every kind: it simply appears once a second design is added.
class DesignPicker<T extends StationeryDesign> extends StatelessWidget {
  const DesignPicker({
    super.key,
    required this.title,
    required this.designs,
    required this.selected,
    required this.onSelected,
    required this.preview,
    this.hint,
    this.height = 112,
  });

  final String title;
  final String? hint;
  final List<T> designs;
  final T selected;
  final ValueChanged<T> onSelected;

  /// How one design looks in the row.
  final Widget Function(T design) preview;

  final double height;

  @override
  Widget build(BuildContext context) {
    if (designs.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          SizedBox(
            height: height,
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
                      padding:
                          const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(3),
                            transform: Matrix4.translationValues(
                                0, isSelected ? -3 : 0, 0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isSelected
                                    ? scheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: preview(design),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            design.name,
                            style: theme.textTheme.labelSmall?.copyWith(
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
          ),
        ],
      ),
    );
  }
}
