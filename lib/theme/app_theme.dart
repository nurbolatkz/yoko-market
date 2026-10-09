import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF9F8FF);
  static const surface = Colors.white;
  static const navy = Color(0xFF17152F);
  static const navyMuted = Color(0xFF66637A);
  static const purple = Color(0xFF6750F5);
  static const purpleDark = Color(0xFF4F37D9);
  static const purpleSoft = Color(0xFFEDE9FF);
  static const yellow = Color(0xFFFFC62F);
  static const border = Color(0xFFEAE7F2);
}

abstract final class AppRadii {
  static const card = 20.0;
  static const button = 14.0;
  static const input = 14.0;

  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const buttonBorder = BorderRadius.all(Radius.circular(button));
}

abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.purple,
      onPrimary: Colors.white,
      primaryContainer: AppColors.purpleSoft,
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.yellow,
      onSecondary: AppColors.navy,
      surface: AppColors.surface,
      onSurface: AppColors.navy,
      outline: AppColors.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      // Explicit Roboto prevents serif fallback on Android when the system font
      // doesn't ship every weight or when Cyrillic glyphs trigger a different
      // font family. Roboto ships with Android and covers ru/kz/₸ fully.
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: AppColors.navy,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.cardBorder,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorder,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.purple,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorder,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.purple,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.purple),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorder,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.navyMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.purpleSoft,
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.purple
                : AppColors.navyMuted,
            size: 24,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Roboto',
            color: states.contains(WidgetState.selected)
                ? AppColors.purple
                : AppColors.navyMuted,
            fontSize: 11,
            overflow: TextOverflow.ellipsis,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.yellow,
        textColor: AppColors.navy,
      ),
      dividerColor: AppColors.border,
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    TextStyle? navy(TextStyle? style) => style?.copyWith(color: AppColors.navy);

    return base.copyWith(
      displayLarge: navy(base.displayLarge)
          ?.copyWith(fontWeight: FontWeight.w800),
      displayMedium: navy(base.displayMedium)
          ?.copyWith(fontWeight: FontWeight.w800),
      headlineLarge: navy(base.headlineLarge)
          ?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: navy(base.headlineMedium)
          ?.copyWith(fontWeight: FontWeight.w800),
      headlineSmall: navy(base.headlineSmall)
          ?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: navy(base.titleLarge)?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: navy(base.titleMedium)
          ?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: navy(base.bodyLarge),
      bodyMedium: navy(base.bodyMedium),
      bodySmall: base.bodySmall?.copyWith(color: AppColors.navyMuted),
      labelLarge: navy(base.labelLarge)?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}
