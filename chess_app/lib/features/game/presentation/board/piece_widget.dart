import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PieceWidget extends StatelessWidget {
  final String pieceChar; // e.g. 'K', 'q', 'P'
  final String pieceSet;  // 'cburnett' or 'merida'
  final double size;

  const PieceWidget({
    super.key,
    required this.pieceChar,
    required this.pieceSet,
    required this.size,
  });

  String get _assetPath {
    final color = pieceChar == pieceChar.toUpperCase() ? 'w' : 'b';
    final piece = pieceChar.toUpperCase();
    return 'assets/pieces/$pieceSet/$color$piece.svg';
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
