import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/game_repository.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/puzzles/domain/puzzle.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_repository.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_session.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockPuzzleRepository extends Mock implements PuzzleRepository {}
class MockGameRepository extends Mock implements GameRepository {}

class MockStatsService extends StateNotifier<StatsState> implements StatsService {
  MockStatsService() : super(StatsState.empty);
  int recordPuzzleSolvedCalls = 0;
  int lastHintsUsed = -1;

  @override
  Future<void> load() async {}

  @override
  void recordPuzzleSolved({required int hintsUsed}) {
    recordPuzzleSolvedCalls++;
    lastHintsUsed = hintsUsed;
  }

  @override
  void recordGameWin(DifficultyLevel difficulty) {}

  @override
  void recordGameLoss(DifficultyLevel difficulty) {}
}

// A test puzzle with moves: [setup, player1, engine1, player2]
final testPuzzle = Puzzle(
  id: 'test01',
  fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  moves: ['e2e4', 'e7e5', 'd2d4', 'd7d5'],
  rating: 1500,
  themes: ['advantage'],
);

void main() {
  late MockPuzzleRepository puzzleRepo;
  late MockGameRepository gameRepo;
  late ProviderContainer container;

  setUp(() {
    puzzleRepo = MockPuzzleRepository();
    gameRepo = MockGameRepository();

    container = ProviderContainer(
      overrides: [
        puzzleRepositoryProvider.overrideWithValue(puzzleRepo),
        gameRepositoryProvider.overrideWithValue(gameRepo),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('loadPuzzle auto-applies setup move and sets nextMoveIndex to 1', () async {
    when(() => puzzleRepo.getPuzzleById('test01')).thenAnswer((_) async => testPuzzle);
    when(() => gameRepo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: 'start_fen', legalMoves: []),
    );
    when(() => gameRepo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(
        fen: 'after_setup_fen',
        legalMoves: ['e7e5'],
        status: GameStatus.playing,
        sanMove: 'e4',
      ),
    );

    await container.read(puzzleNotifierProvider.notifier).loadPuzzle('test01');

    final session = container.read(puzzleNotifierProvider)!;
    expect(session.puzzle.id, 'test01');
    expect(session.currentFen, 'after_setup_fen');
    expect(session.nextMoveIndex, 1);
    expect(session.expectedMove, 'e7e5');
    verify(() => gameRepo.applyMove('e2e4')).called(1);
  });

  test('submitMove correct move advances session and auto-applies engine response', () async {
    when(() => puzzleRepo.getPuzzleById('test01')).thenAnswer((_) async => testPuzzle);
    when(() => gameRepo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: 'start_fen', legalMoves: []),
    );
    when(() => gameRepo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(fen: 'after_e4', legalMoves: [], status: GameStatus.playing, sanMove: 'e4'),
    );
    when(() => gameRepo.applyMove('e7e5')).thenReturn(
      const GameMoveResult(fen: 'after_e5', legalMoves: [], status: GameStatus.playing, sanMove: 'e5'),
    );
    when(() => gameRepo.applyMove('d2d4')).thenReturn(
      const GameMoveResult(fen: 'after_d4', legalMoves: ['d7d5'], status: GameStatus.playing, sanMove: 'd4'),
    );

    await container.read(puzzleNotifierProvider.notifier).loadPuzzle('test01');
    final result = container.read(puzzleNotifierProvider.notifier).submitMove('e7e5');

    expect(result, isTrue);
    final session = container.read(puzzleNotifierProvider)!;
    expect(session.nextMoveIndex, 3); // after player(1) + engine(2) = index 3
    expect(session.currentFen, 'after_d4');
    expect(session.isFailed, isFalse);
  });

  test('submitMove wrong move marks session as failed', () async {
    when(() => puzzleRepo.getPuzzleById('test01')).thenAnswer((_) async => testPuzzle);
    when(() => gameRepo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: 'start_fen', legalMoves: []),
    );
    when(() => gameRepo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(fen: 'after_e4', legalMoves: [], status: GameStatus.playing, sanMove: 'e4'),
    );

    await container.read(puzzleNotifierProvider.notifier).loadPuzzle('test01');
    final result = container.read(puzzleNotifierProvider.notifier).submitMove('c7c5'); // wrong move

    expect(result, isFalse);
    expect(container.read(puzzleNotifierProvider)!.isFailed, isTrue);
  });

  test('useHint increments hintCount up to 2', () async {
    when(() => puzzleRepo.getPuzzleById('test01')).thenAnswer((_) async => testPuzzle);
    when(() => gameRepo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: 'start_fen', legalMoves: []),
    );
    when(() => gameRepo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(fen: 'after_e4', legalMoves: [], status: GameStatus.playing, sanMove: 'e4'),
    );

    await container.read(puzzleNotifierProvider.notifier).loadPuzzle('test01');
    expect(container.read(puzzleNotifierProvider)!.hintCount, 0);

    container.read(puzzleNotifierProvider.notifier).useHint();
    expect(container.read(puzzleNotifierProvider)!.hintCount, 1);

    container.read(puzzleNotifierProvider.notifier).useHint();
    expect(container.read(puzzleNotifierProvider)!.hintCount, 2);

    // Third call should not increment
    container.read(puzzleNotifierProvider.notifier).useHint();
    expect(container.read(puzzleNotifierProvider)!.hintCount, 2);
  });

  test('puzzle completes after all moves', () async {
    // A 1-move puzzle: [setup, player_move]
    final shortPuzzle = Puzzle(
      id: 'short01',
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: ['e2e4', 'e7e5'], // setup + 1 player move
      rating: 1200,
      themes: ['advantage'],
    );

    when(() => puzzleRepo.getPuzzleById('short01')).thenAnswer((_) async => shortPuzzle);
    when(() => gameRepo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: 'start_fen', legalMoves: []),
    );
    when(() => gameRepo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(fen: 'after_e4', legalMoves: [], status: GameStatus.playing, sanMove: 'e4'),
    );
    when(() => gameRepo.applyMove('e7e5')).thenReturn(
      const GameMoveResult(fen: 'final_fen', legalMoves: [], status: GameStatus.playing, sanMove: 'e5'),
    );

    await container.read(puzzleNotifierProvider.notifier).loadPuzzle('short01');
    container.read(puzzleNotifierProvider.notifier).submitMove('e7e5');

    expect(container.read(puzzleNotifierProvider)!.isComplete, isTrue);
  });

  group('stats recording', () {
    late MockStatsService mockStats;

    setUp(() {
      mockStats = MockStatsService();
      container.dispose();
      container = ProviderContainer(
        overrides: [
          puzzleRepositoryProvider.overrideWithValue(puzzleRepo),
          gameRepositoryProvider.overrideWithValue(gameRepo),
          statsProvider.overrideWith((_) => mockStats),
        ],
      );
    });

    test('recordPuzzleSolved called once when puzzle completes', () async {
      when(() => puzzleRepo.getPuzzleById('test01')).thenAnswer((_) async => testPuzzle);
      when(() => gameRepo.loadPosition(any())).thenReturn(
        const GamePositionResult(fen: 'start', legalMoves: []),
      );
      when(() => gameRepo.applyMove(any())).thenReturn(
        const GameMoveResult(fen: 'next', legalMoves: [], status: GameStatus.playing, sanMove: 'x'),
      );

      await container.read(puzzleNotifierProvider.notifier).loadPuzzle('test01');
      container.read(puzzleNotifierProvider.notifier).submitMove('e7e5');
      container.read(puzzleNotifierProvider.notifier).submitMove('d7d5');

      expect(mockStats.recordPuzzleSolvedCalls, 1);
    });

    test('recordPuzzleSolved passes correct hintCount', () async {
      when(() => puzzleRepo.getPuzzleById('test01')).thenAnswer((_) async => testPuzzle);
      when(() => gameRepo.loadPosition(any())).thenReturn(
        const GamePositionResult(fen: 'start', legalMoves: []),
      );
      when(() => gameRepo.applyMove(any())).thenReturn(
        const GameMoveResult(fen: 'next', legalMoves: [], status: GameStatus.playing, sanMove: 'x'),
      );

      await container.read(puzzleNotifierProvider.notifier).loadPuzzle('test01');
      container.read(puzzleNotifierProvider.notifier).useHint();
      container.read(puzzleNotifierProvider.notifier).submitMove('e7e5');
      container.read(puzzleNotifierProvider.notifier).submitMove('d7d5');

      expect(mockStats.lastHintsUsed, 1);
    });
  });
}
