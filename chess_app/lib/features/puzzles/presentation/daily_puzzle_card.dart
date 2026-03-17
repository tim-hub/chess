import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/puzzles/domain/puzzle.dart';
import 'package:go_router/go_router.dart';

class DailyPuzzleCard extends StatelessWidget {
  final Puzzle? puzzle;

  const DailyPuzzleCard({super.key, required this.puzzle});

  @override
  Widget build(BuildContext context) {
    if (puzzle == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      color: AppColors.accent,
      child: InkWell(
        onTap: () => context.push('/puzzles/play/${puzzle!.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Daily',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Puzzle",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    Text(
                      puzzle!.themes.isNotEmpty ? puzzle!.themes.first : 'Chess Puzzle',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                '${puzzle!.rating}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
