import 'puzzle.dart';

/// Tracks the state of an active puzzle attempt.
///
/// The Lichess puzzle convention: moves[0] is the opponent's setup move
/// (auto-applied when the puzzle loads). The player then finds moves[1],
/// the engine responds with moves[2], and so on.
class PuzzleSession {
  final Puzzle puzzle;
  final String currentFen;    // FEN after all moves up to nextMoveIndex have been applied
  final int nextMoveIndex;    // Index into puzzle.moves of the next expected move
  final bool isComplete;
  final bool isFailed;
  final int hintCount;        // 0 = no hint, 1 = from-square hint, 2 = full move hint

  const PuzzleSession({
    required this.puzzle,
    required this.currentFen,
    required this.nextMoveIndex,
    this.isComplete = false,
    this.isFailed = false,
    this.hintCount = 0,
  });

  /// The next move the player must find (or null if puzzle is complete).
  String? get expectedMove =>
      nextMoveIndex < puzzle.moves.length ? puzzle.moves[nextMoveIndex] : null;

  /// Whether it is currently the player's turn (odd indices after setup move).
  /// moves[0] = setup (auto), moves[1] = player, moves[2] = engine, moves[3] = player...
  bool get isPlayerTurn => nextMoveIndex % 2 == 1;

  PuzzleSession copyWith({
    String? currentFen,
    int? nextMoveIndex,
    bool? isComplete,
    bool? isFailed,
    int? hintCount,
  }) => PuzzleSession(
    puzzle: puzzle,
    currentFen: currentFen ?? this.currentFen,
    nextMoveIndex: nextMoveIndex ?? this.nextMoveIndex,
    isComplete: isComplete ?? this.isComplete,
    isFailed: isFailed ?? this.isFailed,
    hintCount: hintCount ?? this.hintCount,
  );
}
