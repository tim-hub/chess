import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/features/game/domain/game_repository.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';
import 'puzzle_repository.dart';
import 'puzzle_session.dart';

final puzzleRepositoryProvider = Provider<PuzzleRepository>((ref) {
  throw UnimplementedError('puzzleRepositoryProvider not overridden');
});

final puzzleNotifierProvider =
    StateNotifierProvider<PuzzleNotifier, PuzzleSession?>(PuzzleNotifier.new);

class PuzzleNotifier extends StateNotifier<PuzzleSession?> {
  final Ref _ref;

  PuzzleNotifier(this._ref) : super(null);

  PuzzleRepository get _repo => _ref.read(puzzleRepositoryProvider);
  GameRepository get _gameRepo => _ref.read(gameRepositoryProvider);

  /// Load a puzzle by ID and auto-apply the setup move (moves[0]).
  Future<void> loadPuzzle(String id) async {
    final puzzle = await _repo.getPuzzleById(id);
    if (puzzle == null || puzzle.moves.isEmpty) return;

    // Set up the board at the puzzle's starting FEN
    _gameRepo.loadPosition(puzzle.fen);

    // Auto-apply setup move (moves[0] = opponent's move that creates the puzzle position)
    final setupResult = _gameRepo.applyMove(puzzle.moves[0]);

    state = PuzzleSession(
      puzzle: puzzle,
      currentFen: setupResult.fen,
      nextMoveIndex: 1, // Player must find moves[1]
    );
  }

  /// Load the daily puzzle.
  Future<void> loadDailyPuzzle() async {
    final puzzle = await _repo.getDailyPuzzle();
    if (puzzle == null) return;
    await loadPuzzle(puzzle.id);
  }

  /// Submit a player move. Returns true if correct, false if wrong.
  bool submitMove(String uciMove) {
    final session = state;
    if (session == null || !session.isPlayerTurn) return false;

    final expected = session.expectedMove;
    if (expected == null) return false;

    if (uciMove == expected) {
      // Correct move — apply it
      final playerResult = _gameRepo.applyMove(uciMove);
      final nextIndex = session.nextMoveIndex + 1;

      // Check if puzzle is complete (no more player moves)
      final isComplete = nextIndex >= session.puzzle.moves.length ||
          !_isPlayerTurn(nextIndex);

      if (isComplete || nextIndex >= session.puzzle.moves.length) {
        if (nextIndex >= session.puzzle.moves.length) {
          _ref.read(statsProvider.notifier).recordPuzzleSolved(
            hintsUsed: session.hintCount,
          );
        }
        state = session.copyWith(
          currentFen: playerResult.fen,
          nextMoveIndex: nextIndex,
          isComplete: nextIndex >= session.puzzle.moves.length,
        );

        // If engine has a response, auto-apply it
        if (nextIndex < session.puzzle.moves.length) {
          _applyEngineResponse(session, playerResult.fen, nextIndex);
        }
        return true;
      }

      // Apply engine response
      _applyEngineResponse(session, playerResult.fen, nextIndex);
      return true;
    } else {
      // Wrong move — mark as failed
      state = session.copyWith(isFailed: true);
      return false;
    }
  }

  void _applyEngineResponse(PuzzleSession session, String fenAfterPlayer, int engineMoveIndex) {
    if (engineMoveIndex >= session.puzzle.moves.length) {
      // Puzzle complete
      state = state?.copyWith(isComplete: true);
      return;
    }

    final engineMove = session.puzzle.moves[engineMoveIndex];
    final engineResult = _gameRepo.applyMove(engineMove);
    final nextPlayerIndex = engineMoveIndex + 1;

    state = state?.copyWith(
      currentFen: engineResult.fen,
      nextMoveIndex: nextPlayerIndex,
      isComplete: nextPlayerIndex >= session.puzzle.moves.length,
    );
  }

  bool _isPlayerTurn(int index) => index % 2 == 1;

  /// Reveal a hint. Up to 2 hints: from-square (hintCount=1), full move (hintCount=2).
  void useHint() {
    final session = state;
    if (session == null || session.hintCount >= 2) return;
    state = session.copyWith(hintCount: session.hintCount + 1);
  }

  /// Reset the current puzzle to its initial state.
  void resetPuzzle() {
    final session = state;
    if (session == null) return;
    loadPuzzle(session.puzzle.id);
  }

  /// Load a random puzzle different from the current one.
  Future<void> loadNextPuzzle() async {
    final current = state;
    final excludeId = current?.puzzle.id ?? '';
    final next = await _repo.getNextPuzzle(excludeId);
    if (next != null) await loadPuzzle(next.id);
  }
}
