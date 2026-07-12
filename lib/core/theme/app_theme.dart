import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Builds the Material 3 [ThemeData] instances used across VOID LAN.
///
/// Two themes are exposed: [dark] (default, cyber-styled) and [light].
/// Both share shape, typography, and motion tokens; only the color
/// scheme and surface treatment differ.
class AppTheme {
  const AppTheme._();

  static const double radiusSmall = 10;
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;

  static ThemeData get dark {
    final colorScheme = const ColorScheme.dark(
      primary: AppColors.voidCyan,
      secondary: AppColors.voidPurple,
      tertiary: AppColors.voidPink,
      surface: AppColors.darkSurface,
      error: AppColors.statusError,
      onPrimary: Colors.black,
      onSurface: Colors.white,
    );

    return _base(colorScheme, AppColors.darkBackground).copyWith(
      cardColor: AppColors.darkSurfaceAlt,
      dividerColor: AppColors.darkBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.voidCyan.withOpacity(0.18),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.voidCyan,
      ),
    );
  }

  static ThemeData get light {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.voidPurple,
      secondary: AppColors.voidCyan,
      tertiary: AppColors.voidPink,
      surface: AppColors.lightSurface,
      error: AppColors.statusError,
      onPrimary: Colors.white,
      onSurface: Colors.black,
    );

    return _base(colorScheme, AppColors.lightBackground).copyWith(
      cardColor: AppColors.lightSurfaceAlt,
      dividerColor: AppColors.lightBorder,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.voidPurple.withOpacity(0.14),
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme, Color scaffoldColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldColor,
      fontFamily: 'Roboto',
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSmall),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        side: BorderSide.none,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
      ),
    );
  }
}
