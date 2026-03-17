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
}
