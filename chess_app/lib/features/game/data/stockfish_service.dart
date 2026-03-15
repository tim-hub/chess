import 'dart:async';
import 'package:stockfish/stockfish.dart';
import '../domain/chess_engine.dart';
import '../domain/models.dart';

class StockfishService implements ChessEngine {
  Stockfish? _stockfish;
  StreamSubscription<String>? _subscription;
  bool _initialized = false;

  /// Initialize the Stockfish engine. Must be called before [getBestMove].
  Future<void> initialize() async {
    // stockfishAsync() waits for the engine to reach StockfishState.ready
    // before returning, so it is safe to write to stdin immediately after.
    _stockfish = await stockfishAsync();

    final readyCompleter = Completer<void>();

    _subscription = _stockfish!.stdout.listen((line) {
      if (line == 'readyok' && !readyCompleter.isCompleted) {
        readyCompleter.complete();
      }
    });

    _stockfish!.stdin = 'uci';
    _stockfish!.stdin = 'isready';

    await readyCompleter.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Stockfish initialization timed out'),
    );

    _initialized = true;
  }

  @override
  Future<String> getBestMove(String fen, DifficultyLevel difficulty) async {
    if (!_initialized) throw StateError('StockfishService not initialized');

    final bestMoveCompleter = Completer<String>();

    // Use a dedicated listener for each move request to avoid stale completers.
    final sub = _stockfish!.stdout.listen((line) {
      if (line.startsWith('bestmove') && !bestMoveCompleter.isCompleted) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          bestMoveCompleter.complete(parts[1]);
        }
      }
    });

    _stockfish!.stdin = 'setoption name Skill Level value ${difficulty.skillLevel}';
    _stockfish!.stdin = 'position fen $fen';
    _stockfish!.stdin = 'go depth ${difficulty.searchDepth}';

    try {
      return await bestMoveCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Stockfish move timed out'),
      );
    } finally {
      await sub.cancel();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _stockfish?.dispose();
    _initialized = false;
  }
}
