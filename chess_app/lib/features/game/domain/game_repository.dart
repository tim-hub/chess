import 'models.dart';

class GamePositionResult {
  final String fen;
  final List<String> legalMoves; // UCI strings

  const GamePositionResult({required this.fen, required this.legalMoves});
}

class GameMoveResult {
  final String fen;
  final List<String> legalMoves;
  final GameStatus status;
  final String sanMove;

  const GameMoveResult({
    required this.fen,
    required this.legalMoves,
    required this.status,
    required this.sanMove,
  });
}

/// Abstract interface for chess rule enforcement.
/// Implemented by ChessRepositoryImpl (data layer) using the chess package.
/// The chess.Chess instance NEVER leaves the data layer.
abstract class GameRepository {
  /// Load [fen] into the internal chess engine and return legal moves.
  GamePositionResult loadPosition(String fen);

  /// Apply [uciMove] (e.g. "e2e4", "e7e8q") to the current position.
  /// Returns updated FEN, legal moves, game status, and SAN notation.
  GameMoveResult applyMove(String uciMove);

  /// Reset to the standard starting position.
  void reset();
}
