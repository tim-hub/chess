import 'package:chess_app/features/stats/data/stats_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chess_engine.dart';
import 'game_repository.dart';
import 'game_state.dart';
import 'models.dart';

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
      fenHistory: const [], // populated per-round in applyPlayerMove
    );
  }

  Future<void> applyPlayerMove(String uciMove) async {
    final current = state;
    if (current == null || !current.isPlayerTurn) return;

    final preFen = current.fen;
    final playerResult = _repo.applyMove(uciMove);
    final playerMove = Move(uci: uciMove, san: playerResult.sanMove);

    final updatedState = current.copyWith(
      fen: playerResult.fen,
      history: [...current.history, playerMove],
      legalMoves: playerResult.legalMoves,
      status: playerResult.status,
      fenHistory: [...current.fenHistory, preFen],
      isAiThinking: playerResult.status == GameStatus.playing,
    );
    state = updatedState;
    _recordResultIfTerminal(current, updatedState);

    if (playerResult.status == GameStatus.playing) {
      await _triggerAiMove(playerResult.fen, current.difficulty);
    }
  }

  Future<void> _triggerAiMove(String fen, DifficultyLevel difficulty) async {
    state = state?.copyWith(isAiThinking: true);
    try {
      final aiUci = await _engine.getBestMove(fen, difficulty);
      final aiResult = _repo.applyMove(aiUci);
      final aiMove = Move(uci: aiUci, san: aiResult.sanMove);
      final prevState = state!;
      final newState = prevState.copyWith(
        fen: aiResult.fen,
        history: [...prevState.history, aiMove],
        legalMoves: aiResult.legalMoves,
        status: aiResult.status,
        isAiThinking: false,
      );
      state = newState;
      _recordResultIfTerminal(prevState, newState);
    } catch (e) {
      debugPrint('AI move failed: $e');
      state = state?.copyWith(isAiThinking: false);
    }
  }

  void undoLastMove() {
    final current = state;
    if (current == null || current.isAiThinking) return;
    if (current.history.length < 2) return;
    if (current.fenHistory.isEmpty) return;

    // fenHistory stores one pre-player-move FEN per round; pop the last entry.
    final targetFen = current.fenHistory.last;
    final newHistory = current.history.sublist(0, current.history.length - 2);
    final newFenHistory =
        current.fenHistory.sublist(0, current.fenHistory.length - 1);

    final result = _repo.loadPosition(targetFen);
    state = current.copyWith(
      fen: result.fen,
      legalMoves: result.legalMoves,
      history: newHistory,
      fenHistory: newFenHistory,
      status: GameStatus.playing,
      isAiThinking: false,
    );

    // Player is Black and history is now empty → AI must move first
    if (newHistory.isEmpty && current.playerColor == Side.black) {
      _triggerAiMove(result.fen, current.difficulty);
    }
  }

  void resign() {
    final current = state;
    if (current == null) return;
    final resigned = current.copyWith(status: GameStatus.resigned);
    state = resigned;
    _recordResultIfTerminal(current, resigned);
  }

  void clearGame() {
    state = null;
  }

  void _recordResultIfTerminal(GameState previous, GameState next) {
    if (previous.status != GameStatus.playing) return;

    if (next.status == GameStatus.checkmate) {
      // FEN active color is the LOSER's turn (the move they never get to make).
      // Opposite color = the one who delivered checkmate = winner.
      final fenParts = next.fen.split(' ');
      if (fenParts.length < 2) return;
      final fenActive = fenParts[1];
      final winnerColor = fenActive == 'w' ? Side.black : Side.white;
      if (winnerColor == next.playerColor) {
        _ref.read(statsProvider.notifier).recordGameWin(next.difficulty);
      } else {
        _ref.read(statsProvider.notifier).recordGameLoss(next.difficulty);
      }
    } else if (next.status == GameStatus.resigned) {
      _ref.read(statsProvider.notifier).recordGameLoss(next.difficulty);
    }
    // stalemate / draw → no stat recorded
  }

  /// Restore a previously saved game state (called from main.dart startup).
  void restoreState(GameState gameState) {
    state = gameState;
  }
}
