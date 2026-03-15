import 'puzzle.dart';
import 'puzzle_filter.dart';

/// Abstract interface for puzzle database access.
abstract class PuzzleRepository {
  /// Returns puzzles matching [filter], paginated.
  Future<List<Puzzle>> getPuzzles(PuzzleFilter filter, {int limit = 20, int offset = 0});

  /// Returns the daily puzzle (stable for a given calendar day).
  Future<Puzzle?> getDailyPuzzle();

  /// Returns a specific puzzle by ID.
  Future<Puzzle?> getPuzzleById(String id);
}
