import 'package:flutter/material.dart';
import 'app_colors.dart';

class BoardTheme {
  final Color lightSquare;
  final Color darkSquare;
  final String name;
  final String key;

  const BoardTheme({
    required this.lightSquare,
    required this.darkSquare,
    required this.name,
    required this.key,
  });

  static const greenClean = BoardTheme(
    lightSquare: AppColors.greenLightSquare,
    darkSquare: AppColors.greenDarkSquare,
    name: 'Green & Clean',
    key: 'greenClean',
  );

  static const classicWood = BoardTheme(
    lightSquare: AppColors.woodLightSquare,
    darkSquare: AppColors.woodDarkSquare,
    name: 'Classic Wood',
    key: 'classicWood',
  );

  static const List<BoardTheme> all = [greenClean, classicWood];

  static BoardTheme fromKey(String key) =>
      all.firstWhere((t) => t.key == key, orElse: () => greenClean);

  @override
  bool operator ==(Object other) => other is BoardTheme && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
