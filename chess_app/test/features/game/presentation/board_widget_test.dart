import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/game/presentation/board/board_widget.dart';
import 'package:chess_app/features/game/presentation/board/piece_widget.dart';
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

  testWidgets('hides piece on specified square', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoardWidget(
            flipped: false,
            pieceSet: 'cburnett',
            boardTheme: BoardTheme.greenClean,
            position: const {'e2': 'P', 'e8': 'k'},
            legalMoves: const [],
            selectedSquare: null,
            lastMove: null,
            hidePieceOnSquare: 'e2',  // hide the white pawn on e2
            onSquareTap: (_) {},
          ),
        ),
      ),
    );
    // Only 1 piece should render (e8 king), not the hidden e2 pawn
    expect(find.byType(PieceWidget), findsOneWidget);
  });
}
