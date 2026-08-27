import 'package:flutter/material.dart';

/// Shorthands for the theme lookups used on nearly every screen.
extension ContextExtensions on BuildContext {
  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get textStyles => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Size get screenSize => MediaQuery.sizeOf(this);

  /// True on phones in portrait, where cards should stack in a single column.
  bool get isCompact => MediaQuery.sizeOf(this).width < 600;
}
