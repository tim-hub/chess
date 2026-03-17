import 'package:flutter/foundation.dart';
import 'package:chess/chess.dart' as ch;
import '../domain/chess_engine.dart';
import '../domain/models.dart';

/// Minimax engine with alpha-beta pruning that runs in an isolate.
/// Used on platforms where Stockfish is unavailable (macOS, desktop).
class MinimaxEngine implements ChessEngine {
  @override
  Future<String> getBestMove(String fen, DifficultyLevel difficulty) {
    final depth = _depth(difficulty);
    return compute(_bestMove, {'fen': fen, 'depth': depth});
  }

  @override
  void dispose() {}

  static int _depth(DifficultyLevel d) => switch (d) {
        DifficultyLevel.beginner => 1,
        DifficultyLevel.easy => 2,
        DifficultyLevel.medium => 3,
        DifficultyLevel.hard => 4,
        DifficultyLevel.expert => 4,
        DifficultyLevel.master => 4,
      };
}

// Top-level so compute() can serialize it into a separate isolate.
String _bestMove(Map<String, dynamic> args) {
  final fen = args['fen'] as String;
  final depth = args['depth'] as int;

  final chess = ch.Chess.fromFEN(fen);
  final maximizing = chess.turn == ch.Color.WHITE;

  final moves = _legalMoves(chess);
  if (moves.isEmpty) throw StateError('No legal moves in: $fen');

  String? best;
  var bestScore = maximizing ? -1000000 : 1000000;

  for (final m in moves) {
    chess.move(m);
    final score = _minimax(chess, depth - 1, -1000000, 1000000, !maximizing);
    chess.undo_move();

    if (maximizing ? score > bestScore : score < bestScore) {
      bestScore = score;
      best = _uci(m);
    }
  }

  return best ?? _uci(moves.first);
}

int _minimax(ch.Chess chess, int depth, int alpha, int beta, bool maximizing) {
  if (chess.in_checkmate) return maximizing ? -90000 : 90000;
  if (chess.in_draw || chess.in_stalemate) return 0;
  if (depth == 0) return _evaluate(chess);

  final moves = _legalMoves(chess);

  if (maximizing) {
    var score = -1000000;
    for (final m in moves) {
      chess.move(m);
      score = _max(score, _minimax(chess, depth - 1, alpha, beta, false));
      chess.undo_move();
      alpha = _max(alpha, score);
      if (beta <= alpha) break;
    }
    return score;
  } else {
    var score = 1000000;
    for (final m in moves) {
      chess.move(m);
      score = _min(score, _minimax(chess, depth - 1, alpha, beta, true));
      chess.undo_move();
      beta = _min(beta, score);
      if (beta <= alpha) break;
    }
    return score;
  }
}

int _max(int a, int b) => a > b ? a : b;
int _min(int a, int b) => a < b ? a : b;

/// Material + basic piece-square bonus evaluation (white positive, black negative).
int _evaluate(ch.Chess chess) {
  const values = {
    'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0,
  };

  // Pawn position bonus table (white perspective, rank 1 at index 0)
  const pawnBonus = [
     0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
     5,  5, 10, 25, 25, 10,  5,  5,
     0,  0,  0, 20, 20,  0,  0,  0,
     5, -5,-10,  0,  0,-10, -5,  5,
     5, 10, 10,-20,-20, 10, 10,  5,
     0,  0,  0,  0,  0,  0,  0,  0,
  ];

  const knightBonus = [
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
  ];

  var score = 0;
  final fen = chess.fen.split(' ')[0];
  var file = 0;
  var rank = 7; // rank 8 first in FEN

  for (final c in fen.split('')) {
    if (c == '/') {
      file = 0;
      rank--;
      continue;
    }
    final empty = int.tryParse(c);
    if (empty != null) {
      file += empty;
      continue;
    }

    final isWhite = c == c.toUpperCase();
    final type = c.toLowerCase();
    final base = values[type] ?? 0;

    // Position bonus (mirror table for black)
    final tableIndex = isWhite
        ? (7 - rank) * 8 + file
        : rank * 8 + file;

    int bonus = 0;
    if (type == 'p' && tableIndex < pawnBonus.length) {
      bonus = pawnBonus[tableIndex];
    } else if (type == 'n' && tableIndex < knightBonus.length) {
      bonus = knightBonus[tableIndex];
    }

    score += isWhite ? (base + bonus) : -(base + bonus);
    file++;
  }

  return score;
}

/// Returns moves sorted captures-first for better alpha-beta cutoffs.
List<Map> _legalMoves(ch.Chess chess) {
  final raw = (chess.moves({'verbose': true}) as List).cast<Map>();
  final captures = <Map>[];
  final others = <Map>[];
  for (final m in raw) {
    if (m['captured'] != null) captures.add(m);
    else others.add(m);
  }
  return [...captures, ...others];
}

String _uci(Map move) {
  final from = move['from'] as String;
  final to = move['to'] as String;
  final promo = move['promotion'] as String?;
  return promo != null ? '$from$to$promo' : '$from$to';
}
