import 'package:flutter/material.dart';
import 'colors.dart';

class AppText {
  AppText._();

  // Light theme styles
  static const displayLarge = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w800,
    color: AppColors.textPrimary, letterSpacing: -1.0,
  );
  static const displayMedium = TextStyle(
    fontSize: 26, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary, letterSpacing: -0.5,
  );
  static const headlineLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const headlineMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const titleLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const titleSmall = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const titleMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400,
    color: AppColors.textPrimary, height: 1.6,
  );
  static const bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: AppColors.textSecondary, height: 1.5,
  );
  static const bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
  );
  static const labelLarge = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w600,
    color: AppColors.textPrimary, letterSpacing: 0.1,
  );
  static const labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w600,
    color: AppColors.textMuted, letterSpacing: 0.5,
  );

  // ── Dark variants (context-aware helpers) ─────────────────────────────
  static TextStyle adaptive(BuildContext context, TextStyle base) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return base;
    Color? adaptedColor;
    if (base.color == AppColors.textPrimary) {
      adaptedColor = AppColors.textPrimaryDark;
    } else if (base.color == AppColors.textSecondary) {
      adaptedColor = AppColors.textSecondaryDark;
    } else if (base.color == AppColors.textMuted) {
      adaptedColor = AppColors.textMutedDark;
    }
    return adaptedColor != null ? base.copyWith(color: adaptedColor) : base;
  }
}
