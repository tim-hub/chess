import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatsState', () {
    test('empty has all-zero fields', () {
      final s = StatsState.empty;
      expect(s.puzzlesSolved, 0);
      expect(s.totalHintsUsed, 0);
      expect(s.perfectSolves, 0);
      expect(s.wins, isEmpty);
      expect(s.losses, isEmpty);
    });

    test('copyWith only changes specified fields', () {
      final s = StatsState.empty.copyWith(puzzlesSolved: 5);
      expect(s.puzzlesSolved, 5);
      expect(s.totalHintsUsed, 0);
    });

    test('copyWith wins produces a new map', () {
      final original = StatsState.empty;
      final updated = original.copyWith(
        wins: {DifficultyLevel.easy: 3},
      );
      expect(updated.wins[DifficultyLevel.easy], 3);
      expect(original.wins, isEmpty); // original unchanged
    });
  });

  group('StatsService.recordPuzzleSolved', () {
    test('increments puzzlesSolved', () {
      final svc = StatsService();
      svc.recordPuzzleSolved(hintsUsed: 1);
      expect(svc.state.puzzlesSolved, 1);
    });

    test('increments totalHintsUsed by hintsUsed', () {
      final svc = StatsService();
      svc.recordPuzzleSolved(hintsUsed: 2);
      expect(svc.state.totalHintsUsed, 2);
    });

    test('increments perfectSolves only when hintsUsed == 0', () {
      final svc = StatsService();
      svc.recordPuzzleSolved(hintsUsed: 0);
      expect(svc.state.perfectSolves, 1);

      svc.recordPuzzleSolved(hintsUsed: 1);
      expect(svc.state.perfectSolves, 1); // unchanged
    });
  });

  group('StatsService.recordGameWin / recordGameLoss', () {
    test('recordGameWin increments wins for that difficulty', () {
      final svc = StatsService();
      svc.recordGameWin(DifficultyLevel.medium);
      expect(svc.state.wins[DifficultyLevel.medium], 1);
      svc.recordGameWin(DifficultyLevel.medium);
      expect(svc.state.wins[DifficultyLevel.medium], 2);
    });

    test('recordGameLoss increments losses for that difficulty', () {
      final svc = StatsService();
      svc.recordGameLoss(DifficultyLevel.hard);
      expect(svc.state.losses[DifficultyLevel.hard], 1);
    });

    test('different difficulties are tracked independently', () {
      final svc = StatsService();
      svc.recordGameWin(DifficultyLevel.easy);
      svc.recordGameWin(DifficultyLevel.hard);
      expect(svc.state.wins[DifficultyLevel.easy], 1);
      expect(svc.state.wins[DifficultyLevel.hard], 1);
      expect(svc.state.wins[DifficultyLevel.medium], isNull);
    });
  });
}
