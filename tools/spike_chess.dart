import 'package:chess/chess.dart';

void main() {
  final chess = Chess();

  // Verify: make moves via map API
  assert(chess.move({'from': 'e2', 'to': 'e4'}) == true);
  assert(chess.move({'from': 'e7', 'to': 'e5'}) == true);

  // Verify: verbose moves contain from/to/san
  final moves = chess.moves({'verbose': true}) as List;
  final first = moves.first as Map;
  assert(first.containsKey('from'));
  assert(first.containsKey('to'));
  assert(first.containsKey('san'));

  // Verify: FEN string accessible
  print('FEN: ${chess.fen}');

  // Verify: en passant - set up position manually
  final epChess = Chess.fromFEN(
    'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3',
  );
  final epMoves = epChess.moves({'square': 'e5', 'verbose': true}) as List;
  if (epMoves.isEmpty) {
    throw AssertionError('No en passant moves found');
  }
  final hasEP = (epMoves).any((m) => (m as Map)['flags'].toString().contains('e'));
  print('En passant detected: $hasEP');
  assert(hasEP, 'chess package missed en passant!');

  // Verify: castling
  final castleChess = Chess.fromFEN(
    'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
  );
  final castleMoves = castleChess.moves({'square': 'e1', 'verbose': true}) as List;
  if (castleMoves.isEmpty) {
    throw AssertionError('No castling moves found');
  }
  final hasCastle = (castleMoves).any((m) => (m as Map)['flags'].toString().contains('k'));
  print('Kingside castle detected: $hasCastle');
  assert(hasCastle, 'chess package missed castling!');

  // Verify: checkmate detection (Fool's Mate - white is in checkmate)
  // NOTE: The FEN positions in the original task spec were incorrect.
  // 'k7/8/1Q6/8/8/8/8/K7 b - - 0 1' is actually stalemate, not checkmate.
  // 'k7/8/1R6/8/8/8/8/1R5K b - - 0 1' has Ka7 available, so is not stalemate.
  // Corrected positions verified against chess package 0.8.1.
  final mateChess = Chess.fromFEN(
    'rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3',
  );
  print('In checkmate: ${mateChess.in_checkmate}');
  assert(mateChess.in_checkmate);

  // Verify: stalemate detection (king on a8, rooks on h7 and b1, white king on h1)
  final staleChess = Chess.fromFEN('k7/7R/8/8/8/8/8/1R5K b - - 0 1');
  print('In stalemate: ${staleChess.in_stalemate}');
  assert(staleChess.in_stalemate);

  print('chess package spike: ALL PASSED');
}
