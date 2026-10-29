import 'package:flutter/material.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_shapes.dart';
import 'tokens/app_typography.dart';

class AppTheme {
  AppTheme._();

  /// Builds a Material 3 Expressive ThemeData strictly from the provided [colorScheme].
  /// Adheres to anti-slop rules: zero hardcoded colors, token-based typography & shapes,
  /// predictive back transitions on Android, and pill-shaped primary actions.
  static ThemeData build({
    required ColorScheme colorScheme,
    required Brightness brightness,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: _buildTextTheme(colorScheme),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: AppShapes.pill,
          textStyle: AppTypography.bodyMd.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        color: colorScheme.surfaceContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide(
            color: colorScheme.error,
          ),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: AppTypography.displayXl.copyWith(color: colorScheme.onSurface),
      displayMedium: AppTypography.displayLg.copyWith(color: colorScheme.onSurface),
      displaySmall: AppTypography.displayMd.copyWith(color: colorScheme.onSurface),
      headlineLarge: AppTypography.displaySm.copyWith(color: colorScheme.onSurface),
      headlineMedium: AppTypography.displaySm.copyWith(color: colorScheme.onSurface),
      headlineSmall: AppTypography.bodyLg.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleLarge: AppTypography.bodyLg.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleMedium: AppTypography.bodyMd.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      titleSmall: AppTypography.bodySm.copyWith(
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: AppTypography.bodyLg.copyWith(color: colorScheme.onSurface),
      bodyMedium: AppTypography.bodyMd.copyWith(color: colorScheme.onSurface),
      bodySmall: AppTypography.bodySm.copyWith(color: colorScheme.onSurfaceVariant),
      labelLarge: AppTypography.bodyMd.copyWith(
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelMedium: AppTypography.bodySm.copyWith(
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurface,
      ),
      labelSmall: AppTypography.bodyXs.copyWith(
        fontWeight: FontWeight.w500,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

