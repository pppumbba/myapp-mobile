import 'package:flutter/material.dart';

/// The app's font (bundled, as on the web). Text styles that replace the theme's must name it.
const appFont = 'Inter';

/// Hairlines and faint fills drawn in the text colour, so they read on the dark and the light theme.
extension Tones on ColorScheme {
  bool get isDark => brightness == Brightness.dark;

  /// A 1–2 px edge on cards, pills and sheets.
  Color get hairline => onSurface.withValues(alpha: isDark ? 0.08 : 0.10);

  /// A form field's outline at rest.
  Color get restLine => onSurface.withValues(alpha: isDark ? 0.14 : 0.2);

  /// The quiet fill behind soft buttons and grouped rows.
  Color get softFill => onSurface.withValues(alpha: isDark ? 0.07 : 0.05);
}
