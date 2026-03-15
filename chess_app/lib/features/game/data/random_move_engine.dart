import 'dart:math';
import 'package:chess/chess.dart' as ch;
import '../domain/chess_engine.dart';
import '../domain/models.dart';

/// Fallback AI engine for platforms where Stockfish is unavailable (e.g. macOS desktop).
/// Picks a random legal move with a short delay to simulate thinking.
class RandomMoveEngine implements ChessEngine {
  final _random = Random();

  @override
  Future<String> getBestMove(String fen, DifficultyLevel difficulty) async {
    final chess = ch.Chess.fromFEN(fen);
    final moves = chess.moves({'verbose': true}) as List;
    if (moves.isEmpty) throw StateError('No legal moves in position: $fen');

    await Future.delayed(const Duration(milliseconds: 400));

    final move = moves[_random.nextInt(moves.length)] as Map;
    final from = move['from'] as String;
    final to = move['to'] as String;
    final promo = move['promotion'] as String?;
    return promo != null ? '$from$to$promo' : '$from$to';
  }

  @override
  void dispose() {}
}
