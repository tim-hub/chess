import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chess_engine.dart';
import 'game_repository.dart';
import 'game_state.dart';
import 'models.dart';

// These providers are overridden in main.dart with real implementations.
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  throw UnimplementedError('gameRepositoryProvider not overridden');
});

final chessEngineProvider = Provider<ChessEngine>((ref) {
  throw UnimplementedError('chessEngineProvider not overridden');
});

final gameNotifierProvider =
    StateNotifierProvider<GameNotifier, GameState?>(GameNotifier.new);

class GameNotifier extends StateNotifier<GameState?> {
  final Ref _ref;

  GameNotifier(this._ref) : super(null);

  GameRepository get _repo => _ref.read(gameRepositoryProvider);
  ChessEngine get _engine => _ref.read(chessEngineProvider);

  void startGame({
    required Side playerColor,
    required DifficultyLevel difficulty,
  }) {
    _repo.reset();
    final result = _repo.loadPosition(GameState.kStartFen);
    state = GameState(
      fen: result.fen,
      history: const [],
      legalMoves: result.legalMoves,
      playerColor: playerColor,
      difficulty: difficulty,
      status: GameStatus.playing,
    );
  }

  Future<void> applyPlayerMove(String uciMove) async {
    final current = state;
    if (current == null || !current.isPlayerTurn) return;

    // Apply player's move
    final playerResult = _repo.applyMove(uciMove);
    final playerMove = Move(uci: uciMove, san: playerResult.sanMove);

    state = current.copyWith(
      fen: playerResult.fen,
      history: [...current.history, playerMove],
      legalMoves: playerResult.legalMoves,
      status: playerResult.status,
      isAiThinking: playerResult.status == GameStatus.playing,
    );

    if (playerResult.status != GameStatus.playing) return;

    // Trigger AI move
    try {
      final aiUci = await _engine.getBestMove(
        playerResult.fen,
        current.difficulty,
      );
      final aiResult = _repo.applyMove(aiUci);
      final aiMove = Move(uci: aiUci, san: aiResult.sanMove);

      state = state?.copyWith(
        fen: aiResult.fen,
        history: [...(state!.history), aiMove],
        legalMoves: aiResult.legalMoves,
        status: aiResult.status,
        isAiThinking: false,
      );
    } catch (_) {
      state = state?.copyWith(isAiThinking: false);
    }
  }

  void resign() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(status: GameStatus.draw); // player resigned
  }

  void clearGame() {
    state = null;
  }

  /// Restore a previously saved game state (called from main.dart startup).
  void restoreState(GameState gameState) {
    state = gameState;
  }
}
