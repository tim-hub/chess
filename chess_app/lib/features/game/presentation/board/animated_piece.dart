import 'package:flutter/material.dart';
import 'piece_widget.dart';

/// Renders a chess piece animating from [fromOffset] to [toOffset].
/// Calls [onComplete] when the animation finishes (via TweenAnimationBuilder.onEnd).
/// Place this in a Stack on top of BoardWidget for the duration of the animation.
class AnimatedPiece extends StatelessWidget {
  final String pieceChar;
  final String pieceSet;
  final Offset fromOffset;
  final Offset toOffset;
  final double squareSize;
  final VoidCallback onComplete;

  const AnimatedPiece({
    super.key,
    required this.pieceChar,
    required this.pieceSet,
    required this.fromOffset,
    required this.toOffset,
    required this.squareSize,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: fromOffset, end: toOffset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      onEnd: onComplete,
      builder: (context, offset, child) {
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: child!,
        );
      },
      child: PieceWidget(
        pieceChar: pieceChar,
        pieceSet: pieceSet,
        size: squareSize,
      ),
    );
  }
}
