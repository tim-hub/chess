import 'package:flutter/material.dart';

abstract final class AppColors {
  // App
  static const Color background = Color(0xFFF5F5F0);
  static const Color accent = Color(0xFF769656);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);

  // Board — Green & Clean
  static const Color greenLightSquare = Color(0xFFEEEED2);
  static const Color greenDarkSquare = Color(0xFF769656);

  // Board — Classic Wood
  static const Color woodLightSquare = Color(0xFFF0D9B5);
  static const Color woodDarkSquare = Color(0xFFB58863);

  // Board highlights
  static const Color lastMoveHighlight = Color(0x80F6F669);
  static const Color selectedSquare = Color(0x80F6F669);
  static const Color legalMoveDot = Color(0x33000000);
  static const Color legalCaptureDot = Color(0x33000000);
  static const Color checkHighlight = Color(0xCCFF4444);

  // Puzzle
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFE53935);

  // Hint
  static const Color hintPiece = Color(0xAAFFD700);        // amber — marks the piece to move
  static const Color hintDestination = Color(0xAA4CAF50);  // green — marks the destination square
}
