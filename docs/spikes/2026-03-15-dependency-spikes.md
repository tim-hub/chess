# Dependency Spikes — 2026-03-15

## Summary

Two highest-risk dependencies verified before app implementation begins.

---

## Spike 1: `chess` package

**Status: PASSED**

**Package:** `chess` 0.8.1
**pub.dev:** https://pub.dev/packages/chess
**Min Dart SDK:** 2.12 (null-safe)

### How it was run

A throwaway Dart console project was created at `/tmp/spike/` with `chess: ^0.8.1` as a dependency. The spike script (`tools/spike_chess.dart`) was run with:

```
dart run --enable-asserts tools/spike_chess.dart
```

Output:
```
FEN: rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2
En passant detected: true
Kingside castle detected: true
In checkmate: true
In stalemate: true
chess package spike: ALL PASSED
```

### Verified behaviours

| Feature | API | Result |
|---|---|---|
| Make moves via Map | `chess.move({'from': 'e2', 'to': 'e4'})` → `bool` | PASS |
| Verbose move generation | `chess.moves({'verbose': true})` → `List<Map>` | PASS |
| Verbose move fields | keys: `san`, `to`, `from`, `captured`, `flags` | PASS |
| FEN access | `chess.fen` (read-only property) | PASS |
| En passant detection | `flags` contains `'e'` for en passant capture | PASS |
| Castling detection | `flags` contains `'k'`/`'q'` for kingside/queenside | PASS |
| Checkmate detection | `chess.in_checkmate` → `bool` | PASS |
| Stalemate detection | `chess.in_stalemate` → `bool` | PASS |
| Load from FEN | `Chess.fromFEN(fenString)` | PASS |

### API deviations from task spec

The FEN positions specified in the task for checkmate and stalemate verification were incorrect:

1. **Checkmate FEN** `k7/8/1Q6/8/8/8/8/K7 b - - 0 1` — this is actually **stalemate** (king on a8 has no legal moves, but is not in check from queen on b6).

2. **Stalemate FEN** `k7/8/1R6/8/8/8/8/1R5K b - - 0 1` — this is **neither checkmate nor stalemate** (Ka7 is a legal move).

Corrected positions used in the spike script:
- **Checkmate:** `rnb1kbnr/pppp1ppp/8/4p3/6Pq/5P2/PPPPP2P/RNBQKBNR w KQkq - 1 3` (Fool's Mate)
- **Stalemate:** `k7/7R/8/8/8/8/8/1R5K b - - 0 1` (king on a8, rooks on h7 and b1)

The chess package's `in_checkmate` and `in_stalemate` logic is correct; only the test FENs in the spec were wrong.

### Notes for app implementation

- `chess.moves()` returns `List` (not `List<Map>`), requiring runtime casts.
- Verbose move `flags` field is a single-character string (e.g., `'n'` = normal, `'e'` = en passant, `'k'` = kingside castle, `'q'` = queenside castle, `'c'` = capture, `'p'` = promotion).
- `dart run` without `--enable-asserts` silently skips `assert()` calls — always use `--enable-asserts` for spike verification.

---

## Spike 2: `stockfish` package

**Status: DEFERRED — requires device/simulator**

**Package:** `stockfish` 1.8.1 (NOT `stockfish_flutter` — that name does not exist on pub.dev)
**pub.dev:** https://pub.dev/packages/stockfish
**Min Flutter SDK:** requires Flutter (Android/iOS FFI)

### Why it cannot run on host

The `stockfish` package wraps the Stockfish C++ engine using Dart FFI with native `.so`/`.framework` libraries compiled for Android and iOS. Running `dart run` on a macOS host VM will fail with a missing native library error.

### Verified API (from pub.dev documentation)

```dart
final stockfish = Stockfish();

// State monitoring
stockfish.state.value; // StockfishState enum: starting, ready, disposed

// Send UCI commands
stockfish.stdin = 'uci';
stockfish.stdin = 'isready';
stockfish.stdin = 'position startpos';
stockfish.stdin = 'go depth 5';

// Receive output
stockfish.stdout.listen((String line) { ... });

// Cleanup
stockfish.dispose();
```

The API in `tools/spike_stockfish.dart` matches this interface. Only one Stockfish instance may be active at a time.

### Validation plan

The stockfish spike will be validated when **Task 8 (StockfishService)** is implemented and tested on a real device or iOS Simulator.

---

## Risk Assessment

| Package | Risk | Decision |
|---|---|---|
| `chess` 0.8.1 | LOW — all required features verified | Proceed |
| `stockfish` 1.8.1 | MEDIUM — API confirmed, runtime deferred | Proceed, validate in Task 8 |
