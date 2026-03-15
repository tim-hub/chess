import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/game/domain/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DifficultyLevel', () {
    test('beginner maps to skill 1, depth 3', () {
      expect(DifficultyLevel.beginner.skillLevel, 1);
      expect(DifficultyLevel.beginner.searchDepth, 3);
    });

    test('master maps to skill 20, depth 15', () {
      expect(DifficultyLevel.master.skillLevel, 20);
      expect(DifficultyLevel.master.searchDepth, 15);
    });

    test('fromName round-trips', () {
      for (final d in DifficultyLevel.values) {
        expect(DifficultyLevel.fromName(d.name), d);
      }
    });

    test('fromName falls back to medium for unknown', () {
      expect(DifficultyLevel.fromName('invalid'), DifficultyLevel.medium);
    });
  });

  group('Move', () {
    test('from and to are derived from uci', () {
      final move = Move(uci: 'e2e4', san: 'e4');
      expect(move.from, 'e2');
      expect(move.to, 'e4');
      expect(move.promotion, isNull);
    });

    test('promotion extracted from 5-char uci', () {
      final move = Move(uci: 'e7e8q', san: 'e8=Q');
      expect(move.promotion, 'q');
    });

    test('equality by uci string', () {
      final a = Move(uci: 'e2e4', san: 'e4');
      final b = Move(uci: 'e2e4', san: 'e4');
      final c = Move(uci: 'd2d4', san: 'd4');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('GameState.canUndo', () {
    const baseState = GameState(
      fen: GameState.kStartFen,
      history: [],
      legalMoves: [],
      playerColor: Side.white,
      difficulty: DifficultyLevel.easy,
      status: GameStatus.playing,
    );

    test('false when fenHistory is empty (restored session)', () {
      final s = baseState.copyWith(
        history: [const Move(uci: 'e2e4', san: 'e4'), const Move(uci: 'e7e5', san: 'e5')],
        fenHistory: [],
      );
      expect(s.canUndo, isFalse);
    });

    test('false when history has fewer than 2 moves', () {
      final s = baseState.copyWith(
        history: [const Move(uci: 'e2e4', san: 'e4')],
        fenHistory: [GameState.kStartFen, 'fen_after_e4'],
      );
      expect(s.canUndo, isFalse);
    });

    test('false when AI is thinking', () {
      final s = baseState.copyWith(
        history: [const Move(uci: 'e2e4', san: 'e4'), const Move(uci: 'e7e5', san: 'e5')],
        fenHistory: [GameState.kStartFen, 'fen1', 'fen2'],
        isAiThinking: true,
      );
      expect(s.canUndo, isFalse);
    });

    test('true when history>=2, fenHistory>=2, not thinking', () {
      final s = baseState.copyWith(
        history: [const Move(uci: 'e2e4', san: 'e4'), const Move(uci: 'e7e5', san: 'e5')],
        fenHistory: [GameState.kStartFen, 'fen_after_e4', 'fen_after_e5'],
      );
      expect(s.canUndo, isTrue);
    });
  });

  group('GameState', () {
    test('isPlayerTurn true when active color matches playerColor', () {
      // Standard starting position — white to move
      final state = GameState(
        fen: GameState.kStartFen,
        history: [],
        legalMoves: [],
        playerColor: Side.white,
        difficulty: DifficultyLevel.medium,
        status: GameStatus.playing,
      );
      expect(state.isPlayerTurn, isTrue);
    });

    test('isPlayerTurn false when it is AI turn', () {
      final state = GameState(
        fen: GameState.kStartFen,
        history: [],
        legalMoves: [],
        playerColor: Side.black, // player is black, but white to move
        difficulty: DifficultyLevel.medium,
        status: GameStatus.playing,
      );
      expect(state.isPlayerTurn, isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final state = GameState(
        fen: GameState.kStartFen,
        history: [],
        legalMoves: [],
        playerColor: Side.white,
        difficulty: DifficultyLevel.easy,
        status: GameStatus.playing,
      );
      final updated = state.copyWith(isAiThinking: true);
      expect(updated.isAiThinking, isTrue);
      expect(updated.difficulty, DifficultyLevel.easy);
      expect(updated.fen, GameState.kStartFen);
    });
  });
}
