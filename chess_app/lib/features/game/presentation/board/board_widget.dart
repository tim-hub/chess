import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'square_widget.dart';
import 'piece_widget.dart';
import 'highlight_layer.dart';
import 'coordinate_labels.dart';

/// Renders an 8x8 chess board with pieces, highlights, and coordinate labels.
///
/// [flipped] — true when player is black (board shown from black's perspective)
/// [pieceSet] — piece set name ('cburnett' or 'merida')
/// [boardTheme] — square colors
/// [position] — map of square name → piece char (e.g. {'e1': 'K', 'e8': 'k'})
/// [legalMoves] — UCI strings for legal moves from selected square
/// [selectedSquare] — currently selected square name (or null)
/// [lastMove] — the last move played (or null)
/// [onSquareTap] — called when user taps a square
class BoardWidget extends StatelessWidget {
  final bool flipped;
  final String pieceSet;
  final BoardTheme boardTheme;
  final Map<String, String> position; // square → piece char (uppercase=white, lowercase=black)
  final List<String> legalMoves; // UCI strings from selected square
  final String? selectedSquare;
  final Move? lastMove;
  final void Function(String square) onSquareTap;

  const BoardWidget({
    super.key,
    required this.flipped,
    required this.pieceSet,
    required this.boardTheme,
    required this.position,
    required this.legalMoves,
    required this.selectedSquare,
    required this.lastMove,
    required this.onSquareTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final squareSize = constraints.maxWidth / 8;
          return Stack(
            children: [
              _buildSquares(squareSize),
              HighlightLayer(
                squareSize: squareSize,
                flipped: flipped,
                selectedSquare: selectedSquare,
                legalMoves: legalMoves,
                lastMove: lastMove,
              ),
              _buildPieces(squareSize),
              CoordinateLabels(
                squareSize: squareSize,
                flipped: flipped,
                boardTheme: boardTheme,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSquares(double squareSize) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final square = _indexToSquare(index, flipped);
        final isLight = _isLightSquare(square);
        return SquareWidget(
          square: square,
          color: isLight ? boardTheme.lightSquare : boardTheme.darkSquare,
          onTap: () => onSquareTap(square),
        );
      },
    );
  }

  Widget _buildPieces(double squareSize) {
    return Stack(
      children: position.entries.map((entry) {
        final square = entry.key;
        final pieceChar = entry.value;
        final offset = _squareToOffset(square, squareSize, flipped);
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: GestureDetector(
            onTap: () => onSquareTap(square),
            child: PieceWidget(
              pieceChar: pieceChar,
              pieceSet: pieceSet,
              size: squareSize,
            ),
          ),
        );
      }).toList(),
    );
  }

  static String _indexToSquare(int index, bool flipped) {
    final file = flipped ? 7 - (index % 8) : index % 8;
    final rank = flipped ? index ~/ 8 : 7 - index ~/ 8;
    return '${String.fromCharCode('a'.codeUnitAt(0) + file)}${rank + 1}';
  }

  static bool _isLightSquare(String square) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    return (file + rank) % 2 == 1;
  }

  static Offset _squareToOffset(String square, double squareSize, bool flipped) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    final col = flipped ? 7 - file : file;
    final row = flipped ? rank : 7 - rank;
    return Offset(col * squareSize, row * squareSize);
  }
}
