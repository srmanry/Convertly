import 'dart:math' as math;

import 'package:convertly/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance of [color].
double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colours, 1:1 to 21:1.
double contrast(Color a, Color b) {
  final double la = _luminance(a);
  final double lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  /// The floor for label text. Buttons carry words, not decoration, so the
  /// normal-text threshold is the one that applies.
  const double readable = 4.5;

  for (final (String name, ThemeData theme) in <(String, ThemeData)>[
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    group('$name theme', () {
      final ColorScheme colors = theme.colorScheme;

      test('text on a filled button is readable', () {
        // The regression this guards: dark mode's accents are light, and
        // white ink on them measured 2.8:1 and 1.7:1.
        expect(
          contrast(colors.onPrimary, colors.primary),
          greaterThanOrEqualTo(readable),
          reason: 'onPrimary must be readable on primary',
        );
        expect(
          contrast(colors.onSecondary, colors.secondary),
          greaterThanOrEqualTo(readable),
          reason: 'onSecondary must be readable on secondary',
        );
        expect(
          contrast(colors.onTertiary, colors.tertiary),
          greaterThanOrEqualTo(readable),
          reason: 'onTertiary must be readable on tertiary',
        );
      });

      test('body text is readable on every surface it lands on', () {
        for (final (String label, Color surface) in <(String, Color)>[
          ('surface', colors.surface),
          ('surfaceContainerLowest', colors.surfaceContainerLowest),
          ('surfaceContainerLow', colors.surfaceContainerLow),
          ('surfaceContainer', colors.surfaceContainer),
          ('surfaceContainerHigh', colors.surfaceContainerHigh),
          ('surfaceContainerHighest', colors.surfaceContainerHighest),
        ]) {
          expect(
            contrast(colors.onSurface, surface),
            greaterThanOrEqualTo(readable),
            reason: 'onSurface must be readable on $label',
          );
        }
      });

      test('the quieter text colour is still readable', () {
        expect(
          contrast(colors.onSurfaceVariant, colors.surface),
          greaterThanOrEqualTo(readable),
          reason: 'subtitles and captions use onSurfaceVariant',
        );
      });

      test('container text is readable on its own container', () {
        expect(
          contrast(colors.onPrimaryContainer, colors.primaryContainer),
          greaterThanOrEqualTo(readable),
        );
        expect(
          contrast(colors.onSecondaryContainer, colors.secondaryContainer),
          greaterThanOrEqualTo(readable),
        );
      });

      test('an outlined button label stands out from the page', () {
        // Outlined and text buttons draw their label in primary straight on
        // the background, with no filled chip behind it.
        expect(
          contrast(colors.primary, colors.surface),
          greaterThanOrEqualTo(3),
          reason: 'primary is used as ink on the page itself',
        );
      });
    });
  }

  test('the contrast helper agrees with known values', () {
    // Sanity check on the maths, so a broken helper cannot quietly pass
    // every assertion above.
    expect(contrast(Colors.white, Colors.black), closeTo(21, 0.01));
    expect(contrast(Colors.white, Colors.white), closeTo(1, 0.001));
  });
}
