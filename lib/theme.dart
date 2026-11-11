import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const bg = Color(0xFF140F0C);
  static const bgLift = Color(0xFF1E1713);
  static const surface = Color(0xFF2A221C);
  static const surfaceLift = Color(0xFF3A2E26);
  static const cream = Color(0xFFF6EDE6);
  static const creamMuted = Color(0xFFC9B8AA);
  static const line = Color(0x33F6EDE6);
  static const accent = Color(0xFFE07A5F);
  static const accentSoft = Color(0x33E07A5F);
  static const danger = Color(0xFFE25B5B);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    surface: AppColors.bg,
    primary: AppColors.accent,
    onPrimary: Color(0xFF2A120C),
    secondary: AppColors.creamMuted,
    onSurface: AppColors.cream,
    error: AppColors.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      foregroundColor: AppColors.cream,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceLift,
      contentTextStyle: const TextStyle(color: AppColors.cream),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.creamMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
