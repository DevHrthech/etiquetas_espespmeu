import 'package:flutter/material.dart';

/// Paleta e tipografia inspiradas no espespmeu.com.br: fundo creme quente,
/// bordô como cor principal, rosa blush como destaque, serifada nos
/// títulos (Playfair Display) e sans-serif limpa no corpo (Plus Jakarta
/// Sans).
class AppColors {
  static const cream = Color(0xFFFDF9F4);
  static const creamSoft = Color(0xFFF7F3EE);
  static const creamCard = Color(0xFFF1EDE8);
  static const border = Color(0xFFE6E2DD);
  static const wine = Color(0xFF7A1926);
  static const wineDark = Color(0xFF5A0013);
  static const blush = Color(0xFFFFB3B4);
  static const blushSoft = Color(0xFFFDBDB3);
  static const gold = Color(0xFFF1BE77);
  static const textMuted = Color(0xFF8A7171);
}

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.wine,
    brightness: Brightness.light,
    primary: AppColors.wine,
    onPrimary: Colors.white,
    secondary: AppColors.blush,
    onSecondary: AppColors.wineDark,
    surface: AppColors.cream,
    onSurface: AppColors.wineDark,
    tertiary: AppColors.gold,
  );

  final baseTextTheme = const TextTheme().apply(
    bodyColor: AppColors.wineDark,
    displayColor: AppColors.wineDark,
    fontFamily: 'PlusJakartaSans',
  );

  final textTheme = baseTextTheme.copyWith(
    headlineSmall: baseTextTheme.headlineSmall?.copyWith(
      fontFamily: 'PlayfairDisplay',
      fontWeight: FontWeight.w600,
    ),
    titleLarge: baseTextTheme.titleLarge?.copyWith(
      fontFamily: 'PlayfairDisplay',
      fontWeight: FontWeight.w600,
    ),
    titleMedium: baseTextTheme.titleMedium?.copyWith(
      fontFamily: 'PlayfairDisplay',
      fontWeight: FontWeight.w600,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.cream,
    textTheme: textTheme,
    fontFamily: 'PlusJakartaSans',
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.wineDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.wine, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.wine,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.wine,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.wine,
        side: const BorderSide(color: AppColors.wine),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.wine),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
