import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/core/theme/app_text_styles.dart';
import 'package:chess_app/features/game/domain/models.dart';

Future<void> showGameOverSheet(
  BuildContext context, {
  required GameStatus status,
  required Side playerColor,
  required Side? winnerSide, // null for draws/stalemate
  required VoidCallback onPlayAgain,
  required VoidCallback onHome,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _GameOverSheet(
      status: status,
      playerColor: playerColor,
      winnerSide: winnerSide,
      onPlayAgain: onPlayAgain,
      onHome: onHome,
    ),
  );
}

class _GameOverSheet extends StatelessWidget {
  final GameStatus status;
  final Side playerColor;
  final Side? winnerSide;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  const _GameOverSheet({
    required this.status,
    required this.playerColor,
    required this.winnerSide,
    required this.onPlayAgain,
    required this.onHome,
  });

  bool get _playerWon => winnerSide == playerColor;

  String get _title {
    return switch (status) {
      GameStatus.checkmate => _playerWon ? 'You Win!' : 'Checkmate',
      GameStatus.stalemate => 'Stalemate',
      GameStatus.draw => 'Draw',
      GameStatus.resigned => 'You Resigned',
      GameStatus.playing => '',
    };
  }

  String get _subtitle {
    return switch (status) {
      GameStatus.checkmate =>
        _playerWon ? 'Congratulations!' : 'Opponent wins',
      GameStatus.stalemate => 'The game is drawn',
      GameStatus.draw => 'The game is drawn',
      GameStatus.resigned => 'Opponent wins',
      GameStatus.playing => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_title, style: AppTextStyles.heading1),
            const SizedBox(height: 8),
            Text(_subtitle, style: AppTextStyles.bodySecondary),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onHome();
                    },
                    child: const Text('Home'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      onPlayAgain();
                    },
                    child: const Text('Play Again'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
