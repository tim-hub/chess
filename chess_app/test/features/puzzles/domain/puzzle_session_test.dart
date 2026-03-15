import 'package:chess_app/features/puzzles/domain/puzzle.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A simple 2-move puzzle:
  // moves[0] = 'e2e4' (setup move, auto-applied)
  // moves[1] = 'e7e5' (player must find this)
  // moves[2] = 'd2d4' (engine response)
  // moves[3] = 'd7d5' (player must find this)
  final testPuzzle = Puzzle(
    id: 'test01',
    fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    moves: ['e2e4', 'e7e5', 'd2d4', 'd7d5'],
    rating: 1500,
    themes: ['advantage'],
  );

  test('initial session starts at nextMoveIndex 1 (setup move pre-applied)', () {
    final session = PuzzleSession(
      puzzle: testPuzzle,
      currentFen: 'some_fen_after_e4',
      nextMoveIndex: 1,
    );
    expect(session.nextMoveIndex, 1);
    expect(session.expectedMove, 'e7e5');
    expect(session.isPlayerTurn, isTrue); // index 1 = player turn
    expect(session.isComplete, isFalse);
  });

  test('expectedMove returns null when puzzle is complete', () {
    final session = PuzzleSession(
      puzzle: testPuzzle,
      currentFen: 'final_fen',
      nextMoveIndex: 4, // past end of moves
    );
    expect(session.expectedMove, isNull);
  });

  test('isPlayerTurn alternates correctly', () {
    // Index 1 = player (odd), index 2 = engine (even), index 3 = player (odd)
    final session1 = PuzzleSession(puzzle: testPuzzle, currentFen: '', nextMoveIndex: 1);
    final session2 = PuzzleSession(puzzle: testPuzzle, currentFen: '', nextMoveIndex: 2);
    final session3 = PuzzleSession(puzzle: testPuzzle, currentFen: '', nextMoveIndex: 3);
    expect(session1.isPlayerTurn, isTrue);
    expect(session2.isPlayerTurn, isFalse);
    expect(session3.isPlayerTurn, isTrue);
  });

  test('copyWith preserves puzzle reference', () {
    final session = PuzzleSession(
      puzzle: testPuzzle,
      currentFen: 'fen1',
      nextMoveIndex: 1,
    );
    final updated = session.copyWith(currentFen: 'fen2', nextMoveIndex: 2);
    expect(updated.puzzle.id, 'test01');
    expect(updated.currentFen, 'fen2');
    expect(updated.nextMoveIndex, 2);
  });
}
