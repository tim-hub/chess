import 'dart:async';
import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'square_widget.dart';
import 'piece_widget.dart';
import 'animated_piece.dart';
import 'highlight_layer.dart';
import 'coordinate_labels.dart';

class BoardWidget extends StatefulWidget {
  final bool flipped;
  final String pieceSet;
  final BoardTheme boardTheme;
  final Map<String, String> position;
  final List<String> legalMoves;
  final String? selectedSquare;
  final Move? lastMove;
  final void Function(String square) onSquareTap;
  final String? hidePieceOnSquare;
  final String? hintFromSquare;
  final String? hintToSquare;
  final bool animateLastMove; // true only for bot moves; defaults false

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
    this.hidePieceOnSquare,
    this.hintFromSquare,
    this.hintToSquare,
    this.animateLastMove = false,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  Map<String, String> _prevPosition = {};
  Timer? _fadingTimer;
  int _slideGeneration = 0;

  ({String char, String from, String to})? _slidingPiece;
  ({String char, String square})? _fadingCapture;

  @override
  void initState() {
    super.initState();
    _prevPosition = widget.position;
  }

  @override
  void didUpdateWidget(BoardWidget old) {
    super.didUpdateWidget(old);

    final newLastMove = widget.lastMove;
    if (newLastMove == null || newLastMove == old.lastMove) {
      _prevPosition = widget.position;
      return;
    }

    // 1. Detect capture — was the destination occupied before this move?
    final capturedChar = _prevPosition[newLastMove.to];
    if (capturedChar != null) {
      _fadingTimer?.cancel();
      setState(() {
        _fadingCapture = (char: capturedChar, square: newLastMove.to);
      });
      _fadingTimer = Timer(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _fadingCapture = null);
      });
    }

    // 2. Slide — only for bot moves.
    if (widget.animateLastMove) {
      final movingChar = _prevPosition[newLastMove.from];
      if (movingChar != null) {
        _slideGeneration++;
        setState(() {
          _slidingPiece = (
            char: movingChar,
            from: newLastMove.from,
            to: newLastMove.to,
          );
        });
      }
    }

    // 3. Snapshot — must happen AFTER steps 1 & 2.
    _prevPosition = widget.position;
  }

  void _onSlideComplete() {
    if (!mounted) return;
    setState(() => _slidingPiece = null);
  }

  @override
  void dispose() {
    _fadingTimer?.cancel();
    super.dispose();
  }

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
                flipped: widget.flipped,
                selectedSquare: widget.selectedSquare,
                legalMoves: widget.legalMoves,
                lastMove: widget.lastMove,
                hintFromSquare: widget.hintFromSquare,
                hintToSquare: widget.hintToSquare,
              ),
              _buildPieces(squareSize),
              if (_slidingPiece != null)
                AnimatedPiece(
                  key: ValueKey('slide_$_slideGeneration'),
                  pieceChar: _slidingPiece!.char,
                  pieceSet: widget.pieceSet,
                  fromOffset: _squareToOffset(
                      _slidingPiece!.from, squareSize, widget.flipped),
                  toOffset: _squareToOffset(
                      _slidingPiece!.to, squareSize, widget.flipped),
                  squareSize: squareSize,
                  onComplete: _onSlideComplete,
                ),
              if (_fadingCapture != null)
                Positioned(
                  left: _squareToOffset(
                          _fadingCapture!.square, squareSize, widget.flipped)
                      .dx,
                  top: _squareToOffset(
                          _fadingCapture!.square, squareSize, widget.flipped)
                      .dy,
                  width: squareSize,
                  height: squareSize,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_fadingCapture),
                      tween: Tween(begin: 1.0, end: 0.0),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      builder: (context, opacity, child) =>
                          Opacity(opacity: opacity, child: child),
                      child: PieceWidget(
                        pieceChar: _fadingCapture!.char,
                        pieceSet: widget.pieceSet,
                        size: squareSize,
                      ),
                    ),
                  ),
                ),
              CoordinateLabels(
                squareSize: squareSize,
                flipped: widget.flipped,
                boardTheme: widget.boardTheme,
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
        final square = _indexToSquare(index, widget.flipped);
        final isLight = _isLightSquare(square);
        return SquareWidget(
          square: square,
          color: isLight
              ? widget.boardTheme.lightSquare
              : widget.boardTheme.darkSquare,
          onTap: () => widget.onSquareTap(square),
        );
      },
    );
  }

  Widget _buildPieces(double squareSize) {
    return Stack(
      children: widget.position.entries
          .where((e) =>
              e.key != widget.hidePieceOnSquare &&
              e.key != _slidingPiece?.from &&
              e.key != _slidingPiece?.to &&
              e.key != _fadingCapture?.square)
          .map((entry) {
        final square = entry.key;
        final pieceChar = entry.value;
        final offset = _squareToOffset(square, squareSize, widget.flipped);
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: GestureDetector(
            onTap: () => widget.onSquareTap(square),
            child: PieceWidget(
              pieceChar: pieceChar,
              pieceSet: widget.pieceSet,
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

  static Offset _squareToOffset(
      String square, double squareSize, bool flipped) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    final col = flipped ? 7 - file : file;
    final row = flipped ? rank : 7 - rank;
    return Offset(col * squareSize, row * squareSize);
  }
}
