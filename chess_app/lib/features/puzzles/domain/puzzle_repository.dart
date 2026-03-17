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

  /// Returns a random puzzle excluding the given ID.
  Future<Puzzle?> getNextPuzzle(String excludeId);

  /// Returns puzzle IDs whose themes column contains any of the given [themeTags].
  /// Uses space-padded LIKE matching against the themes column to correctly handle
  /// camelCase tag strings (e.g. 'discoveredAttack', 'backRankMate') which are not
  /// reliably tokenized by FTS5's default unicode61 tokenizer.
  /// Returns at most [limit] results ordered by rating.
  Future<List<String>> getPuzzleIdsByThemeTags(List<String> themeTags, {int limit = 50});
}
