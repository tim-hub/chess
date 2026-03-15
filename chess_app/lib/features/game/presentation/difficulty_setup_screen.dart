import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/core/theme/app_text_styles.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/models.dart';

class DifficultySetupScreen extends ConsumerStatefulWidget {
  const DifficultySetupScreen({super.key});

  @override
  ConsumerState<DifficultySetupScreen> createState() =>
      _DifficultySetupScreenState();
}

class _DifficultySetupScreenState
    extends ConsumerState<DifficultySetupScreen> {
  DifficultyLevel _difficulty = DifficultyLevel.medium;
  Side _color = Side.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Game'),
        backgroundColor: AppColors.background,
      ),
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Difficulty', style: AppTextStyles.heading2),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: DifficultyLevel.values.map((d) {
                return ChoiceChip(
                  label: Text(d.label),
                  selected: _difficulty == d,
                  onSelected: (_) => setState(() => _difficulty = d),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: _difficulty == d
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            Text('Play as', style: AppTextStyles.heading2),
            const SizedBox(height: 12),
            Row(
              children: [
                _ColorOption(
                  label: 'White',
                  isSelected: _color == Side.white,
                  onTap: () => setState(() => _color = Side.white),
                ),
                const SizedBox(width: 12),
                _ColorOption(
                  label: 'Black',
                  isSelected: _color == Side.black,
                  onTap: () => setState(() => _color = Side.black),
                ),
                const SizedBox(width: 12),
                _ColorOption(
                  label: 'Random',
                  isSelected: false,
                  onTap: () {
                    setState(() {
                      _color =
                          DateTime.now().millisecondsSinceEpoch.isEven
                              ? Side.white
                              : Side.black;
                    });
                  },
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  ref.read(gameNotifierProvider.notifier).startGame(
                    playerColor: _color,
                    difficulty: _difficulty,
                  );
                  context.go('/game/play');
                },
                child: const Text('Play', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
