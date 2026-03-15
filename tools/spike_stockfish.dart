import 'dart:async';
import 'package:stockfish/stockfish.dart';

Future<void> main() async {
  final stockfish = Stockfish();
  final completer = Completer<String>();

  stockfish.stdout.listen((line) {
    print('Stockfish: $line');
    if (line.startsWith('bestmove')) {
      completer.complete(line);
    }
  });

  // Wait for engine ready
  await Future.delayed(const Duration(seconds: 1));
  stockfish.stdin = 'uci';
  await Future.delayed(const Duration(milliseconds: 500));
  stockfish.stdin = 'isready';
  await Future.delayed(const Duration(milliseconds: 500));

  // Request a move from starting position, depth 5
  stockfish.stdin = 'setoption name Skill Level value 10';
  stockfish.stdin = 'position startpos';
  stockfish.stdin = 'go depth 5';

  final result = await completer.future.timeout(const Duration(seconds: 15));
  print('Got bestmove line: $result');
  final move = result.split(' ')[1];
  assert(move.length == 4 || move.length == 5, 'UCI move format wrong: $move');

  stockfish.dispose();
  print('stockfish spike: PASSED');
}

// NOTE: This spike CANNOT be run on the host Dart VM.
// The `stockfish` package (pub.dev v1.8.1) uses native FFI (C++ Stockfish engine)
// compiled for Android and iOS targets only. Running `dart run` on macOS will fail
// with a missing native library error.
//
// Package used: stockfish ^1.8.1 (NOT stockfish_flutter — that package does not exist
// on pub.dev; the correct package name is `stockfish`).
//
// Validation plan: This spike will be exercised when Task 8 (StockfishService) is
// implemented and tested on a real device or simulator.
