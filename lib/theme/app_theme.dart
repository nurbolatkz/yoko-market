import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFFAF9F6);
  static const surface = Colors.white;
  static const navy = Color(0xFF202039);
  static const navyMuted = Color(0xFF66637A);
  static const purple = Color(0xFF6D35D4);
  static const purpleDark = Color(0xFF5428AB);
  static const purpleSoft = Color(0xFFEDE8FA);
  static const purpleDisabled = Color(0xFFC2A8E8);
  static const yellow = Color(0xFFFFD84F);
  static const yellowSoft = Color(0xFFFFF8D6);
  static const border = Color(0xFFEEECF3);
  static const success = Color(0xFF1B7F5E);
  static const error = Color(0xFFD92D2D);
}

abstract final class AppRadii {
  static const card = 20.0;
  static const button = 14.0;
  static const input = 14.0;
  static const chip = 20.0;
  static const image = 16.0;

  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const buttonBorder = BorderRadius.all(Radius.circular(button));
  static const inputBorder = BorderRadius.all(Radius.circular(input));
  static const chipBorder = BorderRadius.all(Radius.circular(chip));
  static const imageBorder = BorderRadius.all(Radius.circular(image));
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const x2l = 24.0;
  static const x3l = 32.0;
  static const screenH = 20.0;
  static const screenPadding = EdgeInsets.symmetric(horizontal: screenH);
}

abstract final class AppTheme {
  static const _fontFamily = 'NunitoSans';

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
      error: AppColors.error,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      fontFamily: _fontFamily,
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
          fontFamily: _fontFamily,
          color: AppColors.navy,
          fontSize: 24,
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
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
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
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorder,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.purple,
          minimumSize: const Size(48, 52),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: AppColors.purple),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonBorder,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: AppColors.navyMuted,
          fontWeight: FontWeight.w400,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.purple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        indicatorShape: const RoundedRectangleBorder(),
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
            fontFamily: _fontFamily,
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
    TextStyle? ns(TextStyle? style) =>
        style?.copyWith(fontFamily: _fontFamily, color: AppColors.navy);

    return base.copyWith(
      displayLarge: ns(base.displayLarge)?.copyWith(fontWeight: FontWeight.w800),
      displayMedium: ns(base.displayMedium)?.copyWith(fontWeight: FontWeight.w800),
      headlineLarge: ns(base.headlineLarge)?.copyWith(fontWeight: FontWeight.w800),
      headlineMedium: ns(base.headlineMedium)
          ?.copyWith(fontWeight: FontWeight.w800, fontSize: 20),
      headlineSmall: ns(base.headlineSmall)?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: ns(base.titleLarge)
          ?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      titleMedium: ns(base.titleMedium)?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: ns(base.titleSmall)?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: ns(base.bodyLarge),
      bodyMedium: ns(base.bodyMedium),
      bodySmall: base.bodySmall?.copyWith(
        fontFamily: _fontFamily,
        color: AppColors.navyMuted,
        fontWeight: FontWeight.w400,
        fontSize: 13,
      ),
      labelLarge: ns(base.labelLarge)?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: ns(base.labelMedium)?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall?.copyWith(
        fontFamily: _fontFamily,
        color: AppColors.navyMuted,
      ),
    );
  }
}
