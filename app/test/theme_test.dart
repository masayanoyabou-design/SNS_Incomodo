import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:incomodo/theme/incomodo_theme.dart';

/// WCAG contrast ratio of [foreground] (alpha composited over [background])
/// against [background].
double contrast(Color foreground, Color background) {
  final fg = Color.alphaBlend(foreground, background);
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final a = luminance(fg);
  final b = luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  final theme = buildIncomodoTheme();
  final scheme = theme.colorScheme;

  test('the app sits on the same paper as the landing page', () {
    expect(theme.scaffoldBackgroundColor, IncomodoColors.paper);
    expect(scheme.primary, IncomodoColors.redDeep);
  });

  group('text stays readable against the paper (4.5:1)', () {
    // Anything that is set as text somewhere in the app. If a tweak to the
    // palette fails here, darken the color rather than loosening the test.
    final textColors = {
      'ink': scheme.onSurface,
      'secondary text (inkFaint)': scheme.onSurfaceVariant,
      'under construction (gold)': scheme.secondary,
      'you can open it here (moss)': scheme.tertiary,
      'errors (postmark red)': scheme.error,
      'text buttons (redDeep)': IncomodoColors.redDeep,
    };

    for (final surface in {
      'paper': IncomodoColors.paper,
      'card': IncomodoColors.card,
    }.entries) {
      for (final text in textColors.entries) {
        test('${text.key} on ${surface.key}', () {
          expect(contrast(text.value, surface.value),
              greaterThanOrEqualTo(4.5));
        });
      }
    }

    test('button labels on the primary color', () {
      expect(contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5));
    });
  });

  test('hairlines are for borders, and are too faint to be text', () {
    // Guards the doc comment on inkFaintest: if this ever passes 4.5, it
    // has stopped being a hairline.
    expect(contrast(IncomodoColors.inkFaintest, IncomodoColors.paper),
        lessThan(4.5));
  });
}
