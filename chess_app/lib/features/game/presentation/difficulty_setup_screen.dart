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
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
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
              runSpacing: 10,
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
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('White'),
                  selected: _color == Side.white,
                  onSelected: (_) => setState(() => _color = Side.white),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: _color == Side.white
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Black'),
                  selected: _color == Side.black,
                  onSelected: (_) => setState(() => _color = Side.black),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(
                    color: _color == Side.black
                        ? Colors.white
                        : AppColors.textPrimary,
                  ),
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

