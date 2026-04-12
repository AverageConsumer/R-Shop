import 'package:flutter/material.dart';

/// Contrast-safe color extensions for dark-theme readability.
///
/// Philosophy: text should always be easy to read. Accent colors are for
/// decoration (backgrounds, borders, glows), not for body text. Small text
/// in accent color is always hard to read — especially reds and dark blues.
///
/// Usage:
///   accentColor.forText   — high-contrast white/light for text on dark bg
///   accentColor.forIcon   — softened white for icons on dark bg
extension ContrastSafeColor on Color {
  /// Returns a readable text color derived from the accent.
  /// Uses a very light tint of the accent hue so text stays legible
  /// while keeping a subtle color connection.
  Color get forText {
    final hsl = HSLColor.fromColor(this);
    return hsl.withSaturation(hsl.saturation * 0.3).withLightness(0.85).toColor();
  }

  /// Returns a visible icon color — slightly more saturated than [forText]
  /// since icons are larger and can carry more color.
  Color get forIcon {
    final hsl = HSLColor.fromColor(this);
    return hsl.withSaturation(hsl.saturation * 0.45).withLightness(0.8).toColor();
  }
}
