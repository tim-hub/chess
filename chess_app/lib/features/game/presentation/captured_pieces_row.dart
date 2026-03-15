import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shows captured pieces sorted by value, with +N material advantage.
class CapturedPiecesRow extends StatelessWidget {
  final List<String> capturedPieces; // piece chars of captured pieces
  final String pieceSet;
  final bool showWhitePieces; // true = show white's captures (black pieces captured)

  const CapturedPiecesRow({
    super.key,
    required this.capturedPieces,
    required this.pieceSet,
    required this.showWhitePieces,
  });

  static const _pieceValues = {'q': 9, 'r': 5, 'b': 3, 'n': 3, 'p': 1};

  List<String> _sortedCaptured() {
    final sorted = List<String>.from(capturedPieces)
      ..sort((a, b) => (_pieceValues[b.toLowerCase()] ?? 0)
          .compareTo(_pieceValues[a.toLowerCase()] ?? 0));
    return sorted;
  }

  int _materialValue() => capturedPieces.fold(
      0, (sum, p) => sum + (_pieceValues[p.toLowerCase()] ?? 0));

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedCaptured();
    final value = _materialValue();

    return Row(
      children: [
        ...sorted.map((piece) => SizedBox(
              width: 18,
              height: 18,
              child: SvgPicture.asset(
                'assets/pieces/$pieceSet/${piece == piece.toUpperCase() ? 'w' : 'b'}${piece.toUpperCase()}.svg',
              ),
            )),
        if (value > 0) ...[
          const SizedBox(width: 4),
          Text('+$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
