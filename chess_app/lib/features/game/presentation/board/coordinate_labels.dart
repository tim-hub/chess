import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/board_theme.dart';

class CoordinateLabels extends StatelessWidget {
  final double squareSize;
  final bool flipped;
  final BoardTheme boardTheme;

  const CoordinateLabels({
    super.key,
    required this.squareSize,
    required this.flipped,
    required this.boardTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // File labels (a-h) at bottom
        ...List.generate(8, (i) {
          final fileIndex = flipped ? 7 - i : i;
          final label = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
          final isLight = (fileIndex + 0) % 2 == 0; // bottom rank is rank 1
          return Positioned(
            left: i * squareSize + squareSize * 0.05,
            bottom: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: squareSize * 0.18,
                fontWeight: FontWeight.w600,
                color: isLight ? boardTheme.darkSquare : boardTheme.lightSquare,
              ),
            ),
          );
        }),
        // Rank labels (1-8) on left
        ...List.generate(8, (i) {
          final rankIndex = flipped ? i : 7 - i;
          final label = '${rankIndex + 1}';
          final isLight = (rankIndex + 0) % 2 == 0;
          return Positioned(
            top: i * squareSize + squareSize * 0.05,
            left: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: squareSize * 0.18,
                fontWeight: FontWeight.w600,
                color: isLight ? boardTheme.darkSquare : boardTheme.lightSquare,
              ),
            ),
          );
        }),
      ],
    );
  }
}
