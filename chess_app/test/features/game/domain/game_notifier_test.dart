import 'package:chess_app/features/game/domain/chess_engine.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/game_repository.dart';
import 'package:chess_app/features/game/domain/game_state.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGameRepository extends Mock implements GameRepository {}
class MockChessEngine extends Mock implements ChessEngine {}

void main() {
  setUpAll(() {
    registerFallbackValue(DifficultyLevel.easy);
  });

  late MockGameRepository repo;
  late MockChessEngine engine;
  late ProviderContainer container;

  setUp(() {
    repo = MockGameRepository();
    engine = MockChessEngine();

    container = ProviderContainer(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repo),
        chessEngineProvider.overrideWithValue(engine),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('startGame initializes state with correct player color and difficulty', () {
    when(() => repo.reset()).thenReturn(null);
    when(() => repo.loadPosition(any())).thenReturn(
      const GamePositionResult(
        fen: GameState.kStartFen,
        legalMoves: ['e2e4', 'd2d4'],
      ),
    );

    container.read(gameNotifierProvider.notifier).startGame(
      playerColor: Side.white,
      difficulty: DifficultyLevel.easy,
    );

    final state = container.read(gameNotifierProvider)!;
    expect(state.playerColor, Side.white);
    expect(state.difficulty, DifficultyLevel.easy);
    expect(state.status, GameStatus.playing);
    expect(state.isAiThinking, isFalse);
    expect(state.legalMoves, ['e2e4', 'd2d4']);
  });

  test('applyPlayerMove updates state and triggers AI move when not game over', () async {
    when(() => repo.reset()).thenReturn(null);
    when(() => repo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
    );
    when(() => repo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        legalMoves: ['e7e5', 'd7d5'],
        status: GameStatus.playing,
        sanMove: 'e4',
      ),
    );
    when(() => engine.getBestMove(any(), any()))
        .thenAnswer((_) async => 'e7e5');
    when(() => repo.applyMove('e7e5')).thenReturn(
      const GameMoveResult(
        fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        legalMoves: ['g1f3', 'f1c4'],
        status: GameStatus.playing,
        sanMove: 'e5',
      ),
    );

    container.read(gameNotifierProvider.notifier).startGame(
      playerColor: Side.white,
      difficulty: DifficultyLevel.easy,
    );

    await container.read(gameNotifierProvider.notifier).applyPlayerMove('e2e4');

    verify(() => engine.getBestMove(any(), DifficultyLevel.easy)).called(1);

    final state = container.read(gameNotifierProvider)!;
    expect(state.history.length, 2); // e4 and e5
    expect(state.history[0].san, 'e4');
    expect(state.history[1].san, 'e5');
    expect(state.isAiThinking, isFalse);

    // fenHistory invariant: one entry per player move
    expect(state.fenHistory.length, 1);
    expect(state.fenHistory[0], GameState.kStartFen); // pre-player-move FEN stored by applyPlayerMove
  });

  test('startGame initializes fenHistory as empty', () {
    when(() => repo.reset()).thenReturn(null);
    when(() => repo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
    );

    container.read(gameNotifierProvider.notifier).startGame(
      playerColor: Side.white,
      difficulty: DifficultyLevel.easy,
    );

    final state = container.read(gameNotifierProvider)!;
    expect(state.fenHistory, isEmpty);
  });

  test('applyPlayerMove does not trigger AI if game is over', () async {
    when(() => repo.reset()).thenReturn(null);
    when(() => repo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
    );
    when(() => repo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(
        fen: 'some_checkmate_fen',
        legalMoves: [],
        status: GameStatus.checkmate,
        sanMove: 'e4#',
      ),
    );

    container.read(gameNotifierProvider.notifier).startGame(
      playerColor: Side.white,
      difficulty: DifficultyLevel.easy,
    );
    await container.read(gameNotifierProvider.notifier).applyPlayerMove('e2e4');

    verifyNever(() => engine.getBestMove(any(), any()));
    expect(container.read(gameNotifierProvider)!.status, GameStatus.checkmate);
  });

  group('undoLastMove', () {
    // Helper: set up a game with 2 moves already played (e2e4, e7e5)
    Future<void> playTwoMoves() async {
      when(() => repo.reset()).thenReturn(null);
      when(() => repo.loadPosition(GameState.kStartFen)).thenReturn(
        const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
      );
      when(() => repo.applyMove('e2e4')).thenReturn(
        const GameMoveResult(
          fen: 'fen_after_e4',
          legalMoves: ['e7e5'],
          status: GameStatus.playing,
          sanMove: 'e4',
        ),
      );
      when(() => engine.getBestMove(any(), any())).thenAnswer((_) async => 'e7e5');
      when(() => repo.applyMove('e7e5')).thenReturn(
        const GameMoveResult(
          fen: 'fen_after_e5',
          legalMoves: ['g1f3'],
          status: GameStatus.playing,
          sanMove: 'e5',
        ),
      );

      container.read(gameNotifierProvider.notifier).startGame(
        playerColor: Side.white,
        difficulty: DifficultyLevel.easy,
      );
      await container.read(gameNotifierProvider.notifier).applyPlayerMove('e2e4');
    }

    test('does nothing when history has fewer than 2 moves', () async {
      when(() => repo.reset()).thenReturn(null);
      when(() => repo.loadPosition(any())).thenReturn(
        const GamePositionResult(fen: GameState.kStartFen, legalMoves: []),
      );
      container.read(gameNotifierProvider.notifier).startGame(
        playerColor: Side.white,
        difficulty: DifficultyLevel.easy,
      );

      // Clear interactions recorded during startGame so verifyNever is clean
      clearInteractions(repo);

      container.read(gameNotifierProvider.notifier).undoLastMove();

      verifyNever(() => repo.loadPosition(any()));
      expect(container.read(gameNotifierProvider)!.history, isEmpty);
    });

    test('does nothing when fenHistory is empty (restored session)', () {
      // Manually inject a restored state with empty fenHistory
      final restoredState = const GameState(
        fen: 'fen_after_e5',
        history: [Move(uci: 'e2e4', san: 'e4'), Move(uci: 'e7e5', san: 'e5')],
        legalMoves: [],
        playerColor: Side.white,
        difficulty: DifficultyLevel.easy,
        status: GameStatus.playing,
        fenHistory: [],
      );
      container.read(gameNotifierProvider.notifier).restoreState(restoredState);

      container.read(gameNotifierProvider.notifier).undoLastMove();

      verifyNever(() => repo.loadPosition(any()));
      expect(container.read(gameNotifierProvider)!.history.length, 2);
    });

    test('restores board to pre-player-move FEN and pops 2 moves', () async {
      await playTwoMoves();

      when(() => repo.loadPosition(GameState.kStartFen)).thenReturn(
        const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
      );

      container.read(gameNotifierProvider.notifier).undoLastMove();

      final state = container.read(gameNotifierProvider)!;
      expect(state.history, isEmpty);
      expect(state.fen, GameState.kStartFen);
      expect(state.fenHistory, isEmpty);
      expect(state.isAiThinking, isFalse);
      expect(state.status, GameStatus.playing);
      verify(() => repo.loadPosition(GameState.kStartFen)).called(greaterThan(0));
    });

    test('canUndo is false after undo empties history', () async {
      await playTwoMoves();
      when(() => repo.loadPosition(GameState.kStartFen)).thenReturn(
        const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
      );

      container.read(gameNotifierProvider.notifier).undoLastMove();

      expect(container.read(gameNotifierProvider)!.canUndo, isFalse);
    });
  });
}
