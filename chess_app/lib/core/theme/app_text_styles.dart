import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static const TextStyle moveHistory = TextStyle(
    fontSize: 13,
    fontFamily: 'monospace',
    color: AppColors.textPrimary,
  );

  static const TextStyle moveHistoryActive = TextStyle(
    fontSize: 13,
    fontFamily: 'monospace',
    color: AppColors.accent,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}
