import 'package:chess_app/features/game/data/chess_repository_impl.dart';
import 'package:chess_app/features/game/domain/game_state.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChessRepositoryImpl repo;

  setUp(() {
    repo = ChessRepositoryImpl();
  });

  group('loadPosition', () {
    test('returns legal moves for starting position', () {
      final result = repo.loadPosition(GameState.kStartFen);
      expect(result.fen, GameState.kStartFen);
      expect(result.legalMoves, hasLength(20)); // 20 legal moves from start
      // Spot-check a few UCI moves
      expect(result.legalMoves, contains('e2e4'));
      expect(result.legalMoves, contains('d2d4'));
    });
  });

  group('applyMove', () {
    test('e2e4 returns correct FEN and SAN', () {
      repo.loadPosition(GameState.kStartFen);
      final result = repo.applyMove('e2e4');
      expect(result.sanMove, 'e4');
      expect(result.fen, contains('b KQkq e3')); // black to move, en passant on e3
      expect(result.status, GameStatus.playing);
    });

    test('returns legal moves after move', () {
      repo.loadPosition(GameState.kStartFen);
      final result = repo.applyMove('e2e4');
      expect(result.legalMoves, isNotEmpty);
      expect(result.legalMoves, contains('e7e5'));
    });

    test('detects checkmate', () {
      // Fool's mate
      repo.loadPosition(GameState.kStartFen);
      repo.applyMove('f2f3');
      repo.applyMove('e7e5');
      repo.applyMove('g2g4');
      final result = repo.applyMove('d8h4');
      expect(result.status, GameStatus.checkmate);
      expect(result.legalMoves, isEmpty);
    });

    test('castling move available from king starting square', () {
      // Position with clear path for white kingside castle
      repo.loadPosition(
        'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
      );
      final result = repo.loadPosition(
        'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
      );
      expect(result.legalMoves, contains('e1g1')); // kingside castle UCI
    });

    test('en passant move included in legal moves', () {
      // Position where en passant is available
      repo.loadPosition(
        'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3',
      );
      final result = repo.loadPosition(
        'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3',
      );
      expect(result.legalMoves, contains('e5f6')); // en passant capture
    });
  });

  group('reset', () {
    test('reset restores starting position', () {
      repo.loadPosition(GameState.kStartFen);
      repo.applyMove('e2e4');
      repo.reset();
      final result = repo.loadPosition(GameState.kStartFen);
      expect(result.legalMoves, hasLength(20));
    });
  });
}
