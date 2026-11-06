import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class HayColors {
  static const page = Color(0xFF10160F);
  static const deep = Color(0xFF16211C);
  static const card = Color(0xFF1D2A23);
  static const elevated = Color(0xFF24352B);
  static const input = Color(0xFF1A2620);
  static const gold = Color(0xFFC6A15B);
  static const goldSoft = Color(0xFFE4CA92);
  static const sage = Color(0xFF92AC93);
  static const sageDim = Color(0xFF6E8C74);
  static const emerald = Color(0xFF33513F);
  static const emeraldBright = Color(0xFF4C7A5C);
  static const clay = Color(0xFFC98F72);
  static const ivory = Color(0xFFF4EFE4);
  static const ivoryDim = Color(0xFFC9C6BA);
  static const muted = Color(0xFF8C978C);
  static const hairline = Color(0x38C6A15B);
  static const hairlineSoft = Color(0x14F4EFE4);
}

abstract final class HayTheme {
  static const displayFont = 'Georgia';

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: HayColors.gold,
      onPrimary: Color(0xFF23180B),
      secondary: HayColors.sage,
      onSecondary: HayColors.page,
      surface: HayColors.deep,
      onSurface: HayColors.ivory,
      error: HayColors.clay,
      onError: HayColors.page,
    );

    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: HayColors.page,
      splashColor: HayColors.gold.withValues(alpha: 0.10),
      highlightColor: Colors.transparent,
      dividerColor: HayColors.hairlineSoft,
      textTheme: base.textTheme
          .apply(
            bodyColor: HayColors.ivory,
            displayColor: HayColors.ivory,
            fontFamily: 'Inter',
          )
          .copyWith(
            displaySmall: const TextStyle(
              fontFamily: displayFont,
              fontSize: 34,
              height: 1.14,
              fontWeight: FontWeight.w500,
              color: HayColors.ivory,
            ),
            headlineMedium: const TextStyle(
              fontFamily: displayFont,
              fontSize: 27,
              height: 1.16,
              fontWeight: FontWeight.w500,
              color: HayColors.ivory,
            ),
            headlineSmall: const TextStyle(
              fontFamily: displayFont,
              fontSize: 23,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: HayColors.ivory,
            ),
            titleMedium: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: HayColors.ivory,
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: HayColors.ivoryDim,
            ),
            bodySmall: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: HayColors.muted,
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF23180B),
            ),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HayColors.input,
        hintStyle: const TextStyle(color: HayColors.muted, fontSize: 13),
        prefixIconColor: HayColors.muted,
        suffixIconColor: HayColors.ivoryDim,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HayColors.hairlineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HayColors.gold, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HayColors.clay),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HayColors.clay, width: 1.2),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: HayColors.deep,
        indicatorColor: HayColors.elevated,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: 21)),
        height: 70,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HayColors.elevated,
        contentTextStyle: const TextStyle(color: HayColors.ivory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: HayColors.ivory,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
    );
  }
}
