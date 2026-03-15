import 'models.dart';

/// Abstract interface for the chess AI engine.
/// Implemented by StockfishService in the data layer.
/// Returns only the UCI string — SAN is computed by GameRepository.applyMove().
abstract class ChessEngine {
  /// Returns the best move in UCI format (e.g. "e2e4") for the given FEN
  /// and difficulty. Throws [TimeoutException] if no response within 10s.
  Future<String> getBestMove(String fen, DifficultyLevel difficulty);

  /// Release engine resources. Call on app dispose.
  void dispose();
}
