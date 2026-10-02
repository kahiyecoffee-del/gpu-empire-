import 'package:flutter/material.dart';

/// Central color palette. Swap values here when real art direction lands.
abstract final class AppColors {
  static const background = Color(0xFF0B1020);
  static const surface = Color(0xFF151C33);
  static const accent = Color(0xFF3DDC97);
  static const accentAlt = Color(0xFF4DA3FF);
  static const warning = Color(0xFFFF5D5D);
  static const textPrimary = Color(0xFFE8ECF8);
  static const textSecondary = Color(0xFF8A94B3);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColors.surface,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
