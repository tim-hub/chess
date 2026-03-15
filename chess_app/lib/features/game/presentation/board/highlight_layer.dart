import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/models.dart';

class HighlightLayer extends StatelessWidget {
  final double squareSize;
  final bool flipped;
  final String? selectedSquare;
  final List<String> legalMoves; // UCI strings
  final Move? lastMove;

  const HighlightLayer({
    super.key,
    required this.squareSize,
    required this.flipped,
    required this.selectedSquare,
    required this.legalMoves,
    required this.lastMove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Last move highlight
        if (lastMove != null) ...[
          _highlight(lastMove!.from, AppColors.lastMoveHighlight),
          _highlight(lastMove!.to, AppColors.lastMoveHighlight),
        ],
        // Selected square
        if (selectedSquare != null)
          _highlight(selectedSquare!, AppColors.selectedSquare),
        // Legal move dots
        ...legalMoves.map((uci) => _dot(uci.substring(2, 4))),
      ],
    );
  }

  Widget _highlight(String square, Color color) {
    final offset = _squareToOffset(square);
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: squareSize,
      height: squareSize,
      child: Container(color: color),
    );
  }

  Widget _dot(String square) {
    final offset = _squareToOffset(square);
    final dotSize = squareSize * 0.3;
    return Positioned(
      left: offset.dx + (squareSize - dotSize) / 2,
      top: offset.dy + (squareSize - dotSize) / 2,
      width: dotSize,
      height: dotSize,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.legalMoveDot,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Offset _squareToOffset(String square) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    final col = flipped ? 7 - file : file;
    final row = flipped ? rank : 7 - rank;
    return Offset(col * squareSize, row * squareSize);
  }
}
