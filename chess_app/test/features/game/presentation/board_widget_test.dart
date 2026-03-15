import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/game/presentation/board/board_widget.dart';
import 'package:chess_app/features/game/presentation/board/square_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BoardWidget renders 64 squares', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardWidget(
            flipped: false,
            pieceSet: 'cburnett',
            boardTheme: BoardTheme.greenClean,
            position: const {},
            legalMoves: const [],
            selectedSquare: null,
            lastMove: null,
            onSquareTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(SquareWidget), findsNWidgets(64));
  });
}
