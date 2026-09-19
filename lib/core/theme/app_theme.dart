import 'package:flutter/material.dart';

import '../constants/app_dimens.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Builds the light and dark [ThemeData] used by the whole app.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme generated = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final ColorScheme scheme = generated.copyWith(
      primary: isDark ? const Color(0xFFCE74FF) : const Color(0xFF7D25D2),
      // Dark mode's accents are light colours, so what sits on top of them has
      // to be dark. White on this violet measures 2.8:1 and white on the cyan
      // 1.7:1, against the 4.5:1 a label needs — which is why filled buttons
      // read as washed out. Light mode's accents are dark, so white stays.
      onPrimary: isDark ? const Color(0xFF2A0A45) : Colors.white,
      primaryContainer: isDark
          ? const Color(0xFF55207E)
          : const Color(0xFFEBD4FF),
      onPrimaryContainer: isDark
          ? const Color(0xFFF6E8FF)
          : const Color(0xFF35104E),
      secondary: isDark ? AppColors.accentAudio : const Color(0xFF006782),
      onSecondary: isDark ? const Color(0xFF04283A) : Colors.white,
      secondaryContainer: isDark
          ? const Color(0xFF123F63)
          : const Color(0xFFC9F1FF),
      onSecondaryContainer: isDark
          ? const Color(0xFFDBF6FF)
          : const Color(0xFF003547),
      tertiary: isDark ? AppColors.accentVideo : const Color(0xFFB61978),
      // Overriding tertiary without its ink would leave the generated pairing
      // behind, matched to a colour the scheme no longer uses.
      onTertiary: isDark ? const Color(0xFF450026) : Colors.white,
      surface: isDark ? const Color(0xFF100B2B) : const Color(0xFFFCF8FF),
      onSurface: isDark ? const Color(0xFFF8F3FF) : const Color(0xFF20162C),
      onSurfaceVariant: isDark
          ? const Color(0xFFCFC2DD)
          : const Color(0xFF655A70),
      surfaceContainerLowest: isDark ? const Color(0xFF0A071D) : Colors.white,
      surfaceContainerLow: isDark
          ? const Color(0xE61D1740)
          : const Color(0xF2FFFFFF),
      surfaceContainer: isDark
          ? const Color(0xF2251B4A)
          : const Color(0xFFF6ECFF),
      surfaceContainerHigh: isDark
          ? const Color(0xFF302257)
          : const Color(0xFFECE0F5),
      surfaceContainerHighest: isDark
          ? const Color(0xFF3B2B64)
          : const Color(0xFFE3D6ED),
      outline: isDark ? const Color(0xFF8E78A9) : const Color(0xFF82748D),
      outlineVariant: isDark
          ? const Color(0xFF4F3B70)
          : const Color(0xFFD3C3DE),
    );
    final ThemeData base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      canvasColor: scheme.surface,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: AppTextStyles.textTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Every plain Card in the app rides the same light as the hand-built
      // depth surfaces: a real drop shadow instead of a hairline outline, and
      // no Material 3 surface tint, which would wash the neon palette out.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: isDark ? 6 : 4,
        shadowColor:
            (isDark ? const Color(0xFF04000E) : const Color(0xFF3B2757))
                .withValues(alpha: isDark ? 0.4 : 0.2),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.4),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          textStyle: base.textTheme.labelLarge,
          // colorScheme.onPrimary is a near-black purple in dark mode, tuned
          // for contrast against the light violet primary; on a filled
          // button that reads as washed out, and white is what every screen
          // asks for instead.
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppDimens.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
          textStyle: base.textTheme.labelLarge,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: base.textTheme.labelLarge,
          foregroundColor: Colors.white,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceLg,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceLg,
          vertical: AppDimens.spaceXs,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        // The frosted panel behind it supplies the fill; a colour here would
        // paint over the blur.
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.16),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final bool selected = states.contains(WidgetState.selected);
          return base.textTheme.labelSmall!.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimens.radiusXl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.16),
        circularTrackColor: scheme.primary.withValues(alpha: 0.16),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        space: 1,
        thickness: 1,
      ),
    );
  }
}
