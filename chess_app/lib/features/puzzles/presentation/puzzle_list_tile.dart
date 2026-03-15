import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/puzzles/domain/puzzle.dart';
import 'package:go_router/go_router.dart';

class PuzzleListTile extends StatelessWidget {
  final Puzzle puzzle;
  final bool solved;

  const PuzzleListTile({
    super.key,
    required this.puzzle,
    this.solved = false,
  });

  Color _ratingColor(int rating) {
    if (rating < 1200) return Colors.green;
    if (rating < 1600) return Colors.orange;
    if (rating < 2000) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/puzzles/${puzzle.id}'),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _ratingColor(puzzle.rating).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            '${puzzle.rating}',
            style: TextStyle(
              color: _ratingColor(puzzle.rating),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
      title: Text(
        puzzle.themes.take(2).join(' · '),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text('Puzzle ${puzzle.id}'),
      trailing: solved
          ? const Icon(Icons.check_circle, color: AppColors.successGreen)
          : const Icon(Icons.chevron_right),
    );
  }
}
