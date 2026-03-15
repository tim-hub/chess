import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_filter.dart';

class PuzzleFilterBar extends StatelessWidget {
  final PuzzleFilter filter;
  final ValueChanged<PuzzleFilter> onFilterChanged;

  const PuzzleFilterBar({
    super.key,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // "All" chip
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: filter.theme == null,
                  onSelected: (_) => onFilterChanged(filter.copyWith(theme: null)),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: filter.theme == null ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              ...kPuzzleThemes.map((theme) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(theme),
                  selected: filter.theme == theme,
                  onSelected: (_) => onFilterChanged(filter.copyWith(theme: theme)),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: filter.theme == theme ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }
}
