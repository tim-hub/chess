import 'package:flutter/material.dart';
import 'package:chess_app/features/game/presentation/board/piece_widget.dart';

/// Shows a bottom sheet for pawn promotion piece selection.
/// Returns the chosen promotion char ('q', 'r', 'b', 'n') or null if dismissed.
Future<String?> showPromotionPicker(
  BuildContext context, {
  required bool isWhite,
  required String pieceSet,
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (context) => _PromotionPicker(isWhite: isWhite, pieceSet: pieceSet),
  );
}

class _PromotionPicker extends StatelessWidget {
  final bool isWhite;
  final String pieceSet;

  const _PromotionPicker({required this.isWhite, required this.pieceSet});

  @override
  Widget build(BuildContext context) {
    final pieces = isWhite
        ? [('Q', 'q'), ('R', 'r'), ('B', 'b'), ('N', 'n')]
        : [('q', 'q'), ('r', 'r'), ('b', 'b'), ('n', 'n')];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Promote pawn to:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: pieces.map((p) {
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(p.$2),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: PieceWidget(
                      pieceChar: p.$1,
                      pieceSet: pieceSet,
                      size: 60,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
