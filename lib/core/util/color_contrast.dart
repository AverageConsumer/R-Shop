import 'package:flutter/material.dart';

/// Contrast-safe color extensions for dark-theme readability.
///
/// Usage:
///   accentColor.forText   — guaranteed readable as text on dark backgrounds
///   accentColor.forIcon   — guaranteed visible as icon on dark backgrounds
extension ContrastSafeColor on Color {
  /// Returns a color with enough luminance for text on dark backgrounds.
  /// Equivalent to [SystemModel.textAccentColor] but usable anywhere.
  Color get forText {
    if (computeLuminance() >= 0.2) return this;
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness(hsl.lightness.clamp(0.55, 1.0)).toColor();
  }

  /// Returns a color with enough luminance for icons on dark backgrounds.
  /// Slightly lower threshold than [forText] since icons are larger.
  Color get forIcon {
    if (computeLuminance() >= 0.15) return this;
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness(hsl.lightness.clamp(0.45, 1.0)).toColor();
  }
}
