import 'package:flutter/material.dart';
import 'tokens.dart';

class KokuroTheme {
  KokuroTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: K.bg,
      colorScheme: ColorScheme.dark(
        surface: K.bg,
        surfaceContainerLowest: K.bgAlt,
        surfaceContainerLow: K.bgCard,
        surfaceContainer: K.bgSurface,
        primary: K.accent,
        secondary: K.cyan,
        error: K.coral,
        onSurface: K.textPrimary,
        outline: K.border,
      ),
      fontFamily: K.fontFamily,
      textTheme: const TextTheme(
        displayLarge: K.displayLarge,
        displayMedium: K.displayMedium,
        headlineLarge: K.headlineLarge,
        headlineMedium: K.headlineMedium,
        titleLarge: K.titleLarge,
        titleMedium: K.titleMedium,
        bodyLarge: K.bodyLarge,
        bodyMedium: K.bodyMedium,
        bodySmall: K.bodySmall,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: K.bgAlt.withValues(alpha: 0.8),
        elevation: 0,
        indicatorColor: K.accent.withValues(alpha: 0.15),
        labelTextStyle: WidgetStatePropertyAll(
          K.bodySmall.copyWith(color: K.textSecondary),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(K.border),
        trackColor: WidgetStatePropertyAll(Colors.transparent),
        thickness: WidgetStatePropertyAll(4),
        radius: const Radius.circular(2),
      ),
    );
  }
}
