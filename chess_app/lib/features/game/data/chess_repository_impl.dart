import 'package:chess/chess.dart' as ch;
import '../domain/game_repository.dart';
import '../domain/models.dart';

class ChessRepositoryImpl implements GameRepository {
  ch.Chess _chess = ch.Chess();

  @override
  GamePositionResult loadPosition(String fen) {
    _chess = ch.Chess.fromFEN(fen);
    return GamePositionResult(
      fen: _chess.fen,
      legalMoves: _legalMovesUci(),
    );
  }

  @override
  GameMoveResult applyMove(String uciMove) {
    final from = uciMove.substring(0, 2);
    final to = uciMove.substring(2, 4);
    final promotion = uciMove.length == 5 ? uciMove[4] : null;

    final success = _chess.move({
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });

    if (!success) {
      throw ArgumentError('Invalid move: $uciMove');
    }

    // Retrieve SAN from verbose history — last entry is the move just played.
    final historyVerbose = _chess.getHistory({'verbose': true});
    final lastMove = historyVerbose.last as Map;
    final sanMove = lastMove['san'] as String;

    return GameMoveResult(
      fen: _chess.fen,
      legalMoves: _legalMovesUci(),
      status: _status(),
      sanMove: sanMove,
    );
  }

  @override
  void reset() {
    _chess = ch.Chess();
  }

  List<String> _legalMovesUci() {
    final moves = _chess.moves({'verbose': true}) as List;
    return moves.map((m) {
      final move = m as Map;
      final from = move['from'] as String;
      final to = move['to'] as String;
      final flags = move['flags'] as String? ?? '';

      // make_pretty() omits a 'promotion' key — detect via flag 'p' and
      // parse the promoted piece from the SAN suffix (e.g. "a8=Q" → 'q').
      if (flags.contains('p')) {
        final san = move['san'] as String? ?? '';
        final eqIdx = san.indexOf('=');
        if (eqIdx != -1 && eqIdx + 1 < san.length) {
          return '$from$to${san[eqIdx + 1].toLowerCase()}';
        }
      }
      return '$from$to';
    }).toList();
  }

  GameStatus _status() {
    if (_chess.in_checkmate) return GameStatus.checkmate;
    if (_chess.in_stalemate) return GameStatus.stalemate;
    if (_chess.in_draw) return GameStatus.draw;
    return GameStatus.playing;
  }
}
