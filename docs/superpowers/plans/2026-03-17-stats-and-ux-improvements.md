# Stats & UX Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Stats screen (puzzle credits + AI win/loss per difficulty), persistent Settings button on all screens, resign confirmation dialog, and a "Back to Home" option in Settings that discards a game without recording a loss.

**Architecture:** New `StatsService` (StateNotifier + SharedPreferences) stores puzzle and game stats. Recording hooks are added inside `GameNotifier` and `PuzzleNotifier`. The Stats screen is a new tabbed route `/stats`. UX changes (resign dialog, back-to-home, settings icon) are surgical edits to existing screens.

**Tech Stack:** Flutter, Dart, Riverpod (StateNotifier), go_router, SharedPreferences, mocktail (tests), flutter_test

---

## Chunk 1: Foundation — StatsState, StatsService, Tests

### Task 1: Fix existing tests broken by undo refactor

The undo fix in `GameNotifier` changed `fenHistory` semantics: `startGame` now seeds `fenHistory: const []` (not `[startFen]`), and `_triggerAiMove` no longer appends to `fenHistory`. Three existing tests assert the old behaviour and must be updated before adding new code.

**Files:**
- Modify: `test/features/game/domain/game_notifier_test.dart`

- [ ] **Step 1: Update the `startGame seeds fenHistory` test**

In `game_notifier_test.dart`, find the test `'startGame seeds fenHistory with starting FEN'` and change its assertion:

```dart
// OLD:
expect(state.fenHistory, [GameState.kStartFen]);
// NEW:
expect(state.fenHistory, isEmpty);
```

- [ ] **Step 2: Update the `applyPlayerMove` fenHistory length assertion**

Find the test `'applyPlayerMove updates state and triggers AI move when not game over'`. The `fenHistory` assertions now reflect: startGame seeds `[]`, applyPlayerMove adds 1 entry (the pre-player-move FEN), triggerAiMove adds nothing. After one full round (e4 + e5), `fenHistory.length == 1`.

```dart
// OLD:
expect(state.fenHistory.length, 3); // startFen + preFen_e4 + preFen_e5
expect(state.fenHistory[0], GameState.kStartFen);
// NEW:
expect(state.fenHistory.length, 1);
expect(state.fenHistory[0], GameState.kStartFen); // pre-player-move FEN stored by applyPlayerMove
```

- [ ] **Step 3: Update the `undoLastMove restores board` fenHistory assertion**

Find the test `'restores board to pre-player-move FEN and pops 2 moves'`. After undo with 1 round played, fenHistory was `[startFen]`; undo pops it, leaving `[]`.

```dart
// OLD:
expect(state.fenHistory, [GameState.kStartFen]);
// NEW:
expect(state.fenHistory, isEmpty);
```

- [ ] **Step 4: Run existing game_notifier tests to verify they pass**

```bash
cd chess_app && flutter test test/features/game/domain/game_notifier_test.dart --reporter=compact
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add test/features/game/domain/game_notifier_test.dart
git commit -m "test: fix game_notifier tests for updated fenHistory semantics"
```

---

### Task 2: Create StatsState model

**Files:**
- Create: `chess_app/lib/features/stats/data/stats_service.dart`
- Create: `chess_app/test/features/stats/data/stats_service_test.dart`

- [ ] **Step 1: Create the directory structure**

```bash
mkdir -p chess_app/lib/features/stats/data
mkdir -p chess_app/lib/features/stats/presentation
mkdir -p chess_app/test/features/stats/data
```

- [ ] **Step 2: Write the failing model test**

Create `chess_app/test/features/stats/data/stats_service_test.dart`:

```dart
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StatsState', () {
    test('empty has all-zero fields', () {
      final s = StatsState.empty;
      expect(s.puzzlesSolved, 0);
      expect(s.totalHintsUsed, 0);
      expect(s.perfectSolves, 0);
      expect(s.wins, isEmpty);
      expect(s.losses, isEmpty);
    });

    test('copyWith only changes specified fields', () {
      final s = StatsState.empty.copyWith(puzzlesSolved: 5);
      expect(s.puzzlesSolved, 5);
      expect(s.totalHintsUsed, 0);
    });

    test('copyWith wins produces a new map', () {
      final original = StatsState.empty;
      final updated = original.copyWith(
        wins: {DifficultyLevel.easy: 3},
      );
      expect(updated.wins[DifficultyLevel.easy], 3);
      expect(original.wins, isEmpty); // original unchanged
    });
  });
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
cd chess_app && flutter test test/features/stats/data/stats_service_test.dart --reporter=compact
```

Expected: compilation error — `StatsState` not found.

- [ ] **Step 4: Create `stats_service.dart` with just the model**

Create `chess_app/lib/features/stats/data/stats_service.dart`:

```dart
import 'package:chess_app/features/game/domain/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class StatsState {
  final int puzzlesSolved;
  final int totalHintsUsed;
  final int perfectSolves;
  final Map<DifficultyLevel, int> wins;
  final Map<DifficultyLevel, int> losses;

  const StatsState({
    this.puzzlesSolved = 0,
    this.totalHintsUsed = 0,
    this.perfectSolves = 0,
    this.wins = const {},
    this.losses = const {},
  });

  // Not const — logical zero-value sentinel, not a singleton.
  static final empty = StatsState();

  StatsState copyWith({
    int? puzzlesSolved,
    int? totalHintsUsed,
    int? perfectSolves,
    Map<DifficultyLevel, int>? wins,
    Map<DifficultyLevel, int>? losses,
  }) =>
      StatsState(
        puzzlesSolved: puzzlesSolved ?? this.puzzlesSolved,
        totalHintsUsed: totalHintsUsed ?? this.totalHintsUsed,
        perfectSolves: perfectSolves ?? this.perfectSolves,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
      );
}

// ── Provider (overridden in main.dart) ───────────────────────────────────────

final statsProvider =
    StateNotifierProvider<StatsService, StatsState>((_) => StatsService());

// ── Service (stub — full impl in Task 3) ─────────────────────────────────────

class StatsService extends StateNotifier<StatsState> {
  StatsService() : super(StatsState.empty);

  Future<void> load() async {}
  void recordPuzzleSolved({required int hintsUsed}) {}
  void recordGameWin(DifficultyLevel difficulty) {}
  void recordGameLoss(DifficultyLevel difficulty) {}
}
```

- [ ] **Step 5: Run tests to verify model tests pass**

```bash
cd chess_app && flutter test test/features/stats/data/stats_service_test.dart --reporter=compact
```

Expected: all 3 model tests pass.

---

### Task 3: Implement StatsService persistence

- [ ] **Step 1: Write the failing service tests**

Append the following groups to `chess_app/test/features/stats/data/stats_service_test.dart`, inserting them **before the final `});` that closes `void main()`** (i.e. inside `main()`, after the existing `group('StatsState', ...)`block):

```dart
  group('StatsService.recordPuzzleSolved', () {
    test('increments puzzlesSolved', () {
      final svc = StatsService();
      svc.recordPuzzleSolved(hintsUsed: 1);
      expect(svc.state.puzzlesSolved, 1);
    });

    test('increments totalHintsUsed by hintsUsed', () {
      final svc = StatsService();
      svc.recordPuzzleSolved(hintsUsed: 2);
      expect(svc.state.totalHintsUsed, 2);
    });

    test('increments perfectSolves only when hintsUsed == 0', () {
      final svc = StatsService();
      svc.recordPuzzleSolved(hintsUsed: 0);
      expect(svc.state.perfectSolves, 1);

      svc.recordPuzzleSolved(hintsUsed: 1);
      expect(svc.state.perfectSolves, 1); // unchanged
    });
  });

  group('StatsService.recordGameWin / recordGameLoss', () {
    test('recordGameWin increments wins for that difficulty', () {
      final svc = StatsService();
      svc.recordGameWin(DifficultyLevel.medium);
      expect(svc.state.wins[DifficultyLevel.medium], 1);
      svc.recordGameWin(DifficultyLevel.medium);
      expect(svc.state.wins[DifficultyLevel.medium], 2);
    });

    test('recordGameLoss increments losses for that difficulty', () {
      final svc = StatsService();
      svc.recordGameLoss(DifficultyLevel.hard);
      expect(svc.state.losses[DifficultyLevel.hard], 1);
    });

    test('different difficulties are tracked independently', () {
      final svc = StatsService();
      svc.recordGameWin(DifficultyLevel.easy);
      svc.recordGameWin(DifficultyLevel.hard);
      expect(svc.state.wins[DifficultyLevel.easy], 1);
      expect(svc.state.wins[DifficultyLevel.hard], 1);
      expect(svc.state.wins[DifficultyLevel.medium], isNull);
    });
  });
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd chess_app && flutter test test/features/stats/data/stats_service_test.dart --reporter=compact
```

Expected: new tests fail with 0 (stub returns nothing).

- [ ] **Step 3: Implement `StatsService` fully**

Replace the stub `StatsService` class in `stats_service.dart` with:

```dart
class StatsService extends StateNotifier<StatsState> {
  static const _keySolved = 'stats.puzzles.solved';
  static const _keyHints = 'stats.puzzles.hints_used';
  static const _keyPerfect = 'stats.puzzles.perfect';
  static String _winsKey(DifficultyLevel d) => 'stats.game.wins.${d.name}';
  static String _lossesKey(DifficultyLevel d) => 'stats.game.losses.${d.name}';

  StatsService() : super(StatsState.empty);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wins = <DifficultyLevel, int>{};
      final losses = <DifficultyLevel, int>{};
      for (final d in DifficultyLevel.values) {
        final w = prefs.getInt(_winsKey(d));
        final l = prefs.getInt(_lossesKey(d));
        if (w != null) wins[d] = w;
        if (l != null) losses[d] = l;
      }
      state = StatsState(
        puzzlesSolved: prefs.getInt(_keySolved) ?? 0,
        totalHintsUsed: prefs.getInt(_keyHints) ?? 0,
        perfectSolves: prefs.getInt(_keyPerfect) ?? 0,
        wins: wins,
        losses: losses,
      );
    } catch (e) {
      debugPrint('StatsService.load failed: $e');
      state = StatsState.empty;
    }
  }

  void recordPuzzleSolved({required int hintsUsed}) {
    state = state.copyWith(
      puzzlesSolved: state.puzzlesSolved + 1,
      totalHintsUsed: state.totalHintsUsed + hintsUsed,
      perfectSolves: hintsUsed == 0 ? state.perfectSolves + 1 : state.perfectSolves,
    );
    _persist();
  }

  void recordGameWin(DifficultyLevel difficulty) {
    final updated = Map<DifficultyLevel, int>.from(state.wins);
    updated[difficulty] = (updated[difficulty] ?? 0) + 1;
    state = state.copyWith(wins: updated);
    _persist();
  }

  void recordGameLoss(DifficultyLevel difficulty) {
    final updated = Map<DifficultyLevel, int>.from(state.losses);
    updated[difficulty] = (updated[difficulty] ?? 0) + 1;
    state = state.copyWith(losses: updated);
    _persist();
  }

  void _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keySolved, state.puzzlesSolved);
      await prefs.setInt(_keyHints, state.totalHintsUsed);
      await prefs.setInt(_keyPerfect, state.perfectSolves);
      for (final d in DifficultyLevel.values) {
        final w = state.wins[d];
        final l = state.losses[d];
        if (w != null) await prefs.setInt(_winsKey(d), w);
        if (l != null) await prefs.setInt(_lossesKey(d), l);
      }
    } catch (e) {
      debugPrint('StatsService._persist failed: $e');
    }
  }
}
```

Also add `import 'package:flutter/foundation.dart';` at the top of `stats_service.dart`.

- [ ] **Step 4: Run all stats tests**

```bash
cd chess_app && flutter test test/features/stats/data/stats_service_test.dart --reporter=compact
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/stats/data/stats_service.dart test/features/stats/data/stats_service_test.dart
git commit -m "feat: add StatsState model and StatsService with SharedPreferences persistence"
```

---

### Task 4: Wire StatsService into main.dart

**Files:**
- Modify: `chess_app/lib/main.dart`

- [ ] **Step 1: Add import and initialization in `main()`**

In `chess_app/lib/main.dart`, add the import:

```dart
import 'package:chess_app/features/stats/data/stats_service.dart';
```

In `main()`, after `await creditsService.load();`, add:

```dart
final statsService = StatsService();
await statsService.load();
```

- [ ] **Step 2: Add provider override in `ProviderScope`**

In the `ProviderScope` overrides list, add:

```dart
statsProvider.overrideWith((_) => statsService),
```

- [ ] **Step 3: Verify app still compiles**

```bash
cd chess_app && flutter build macos --debug 2>&1 | tail -5
```

Expected: `Build complete` with no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: initialize StatsService in main and wire provider override"
```

---

## Chunk 2: Stats Recording Hooks

### Task 5: Record puzzle stats in PuzzleNotifier

**Files:**
- Modify: `chess_app/lib/features/puzzles/domain/puzzle_notifier.dart`
- Modify: `chess_app/test/features/puzzles/domain/puzzle_notifier_test.dart`

- [ ] **Step 1: Write the failing test**

In `puzzle_notifier_test.dart`, add a new mock and test group. First add to the imports and mocks section:

```dart
import 'package:chess_app/features/stats/data/stats_service.dart';

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
```

Add `statsProvider` override to the `setUp` container in the existing test:

```dart
final mockStats = MockStatsService();

container = ProviderContainer(
  overrides: [
    puzzleRepositoryProvider.overrideWithValue(puzzleRepo),
    gameRepositoryProvider.overrideWithValue(gameRepo),
    statsProvider.overrideWith((_) => mockStats),
  ],
);
```

Add a new test group at the end of `void main()`:

```dart
group('stats recording', () {
  late MockStatsService mockStats;

  setUp(() {
    mockStats = MockStatsService();
    // Re-create container with stats override
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
    // testPuzzle has 4 moves: [setup, player1, engine1, player2]
    // After player submits player1 (e7e5) and engine plays engine1 (d2d4),
    // player must submit player2 (d7d5) to complete.
    when(() => puzzleRepo.getPuzzleById('test01')).thenAnswer((_) async => testPuzzle);
    when(() => gameRepo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: 'start', legalMoves: []),
    );
    when(() => gameRepo.applyMove(any())).thenReturn(
      const GameMoveResult(fen: 'next', legalMoves: [], status: GameStatus.playing, sanMove: 'x'),
    );

    await container.read(puzzleNotifierProvider.notifier).loadPuzzle('test01');
    container.read(puzzleNotifierProvider.notifier).submitMove('e7e5'); // player1
    container.read(puzzleNotifierProvider.notifier).submitMove('d7d5'); // player2

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
```

- [ ] **Step 2: Run to verify tests fail**

```bash
cd chess_app && flutter test test/features/puzzles/domain/puzzle_notifier_test.dart --reporter=compact
```

Expected: new stats tests fail (recordPuzzleSolvedCalls == 0).

- [ ] **Step 3: Add stats recording to `PuzzleNotifier.submitMove`**

In `chess_app/lib/features/puzzles/domain/puzzle_notifier.dart`, add the import:

```dart
import 'package:chess_app/features/stats/data/stats_service.dart';
```

In `submitMove`, the local variable `isComplete` is computed at line 61–62 as:

```dart
final isComplete = nextIndex >= session.puzzle.moves.length || !_isPlayerTurn(nextIndex);
```

This is the authoritative completion gate. Record stats by keying off this computed `isComplete` variable — **not** a simplified condition — immediately before the `state = ...` assignment inside the `if (isComplete || ...)` branch. Do **not** call `recordPuzzleSolved` inside `_applyEngineResponse`.

```dart
if (isComplete || nextIndex >= session.puzzle.moves.length) {
  // Record stats exactly once, gated by the computed isComplete variable.
  if (isComplete) {
    _ref.read(statsProvider.notifier).recordPuzzleSolved(
      hintsUsed: session.hintCount,
    );
  }

  state = session.copyWith(
    currentFen: playerResult.fen,
    nextMoveIndex: nextIndex,
    isComplete: nextIndex >= session.puzzle.moves.length,
  );
  // ... rest unchanged
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd chess_app && flutter test test/features/puzzles/domain/puzzle_notifier_test.dart --reporter=compact
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/puzzles/domain/puzzle_notifier.dart test/features/puzzles/domain/puzzle_notifier_test.dart
git commit -m "feat: record puzzle stats in PuzzleNotifier on solve"
```

---

### Task 6: Record game stats in GameNotifier

**Files:**
- Modify: `chess_app/lib/features/game/domain/game_notifier.dart`
- Modify: `chess_app/test/features/game/domain/game_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

In `game_notifier_test.dart`, add imports and mock:

```dart
import 'package:chess_app/features/stats/data/stats_service.dart';

class MockStatsService extends StateNotifier<StatsState> implements StatsService {
  MockStatsService() : super(StatsState.empty);
  final List<String> calls = [];

  @override Future<void> load() async {}
  @override void recordPuzzleSolved({required int hintsUsed}) {}
  @override void recordGameWin(DifficultyLevel difficulty) => calls.add('win:${difficulty.name}');
  @override void recordGameLoss(DifficultyLevel difficulty) => calls.add('loss:${difficulty.name}');
}
```

Add `statsProvider` override to the existing `setUp` container:

```dart
late MockStatsService mockStats;

setUp(() {
  repo = MockGameRepository();
  engine = MockChessEngine();
  mockStats = MockStatsService();

  container = ProviderContainer(
    overrides: [
      gameRepositoryProvider.overrideWithValue(repo),
      chessEngineProvider.overrideWithValue(engine),
      statsProvider.overrideWith((_) => mockStats),
    ],
  );
});
```

Add a new test group at the end of `void main()`:

```dart
group('stats recording', () {
  void setupStart() {
    when(() => repo.reset()).thenReturn(null);
    when(() => repo.loadPosition(any())).thenReturn(
      const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
    );
    container.read(gameNotifierProvider.notifier).startGame(
      playerColor: Side.white,
      difficulty: DifficultyLevel.medium,
    );
  }

  test('records player win when player delivers checkmate', () async {
    setupStart();
    // FEN with 'b' to move = black is to move = white just delivered checkmate = white won
    when(() => repo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(
        fen: 'checkmate_fen b - - 0 1',
        legalMoves: [],
        status: GameStatus.checkmate,
        sanMove: 'e4#',
      ),
    );

    await container.read(gameNotifierProvider.notifier).applyPlayerMove('e2e4');

    expect(mockStats.calls, contains('win:medium'));
  });

  test('records player loss when AI delivers checkmate', () async {
    setupStart();
    when(() => repo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(
        fen: 'fen_after_e4 b - - 0 1',
        legalMoves: ['e7e5'],
        status: GameStatus.playing,
        sanMove: 'e4',
      ),
    );
    when(() => engine.getBestMove(any(), any())).thenAnswer((_) async => 'e7e5');
    // FEN with 'w' to move = white is to move = black just delivered checkmate = black won = player lost
    when(() => repo.applyMove('e7e5')).thenReturn(
      const GameMoveResult(
        fen: 'checkmate_fen w - - 0 1',
        legalMoves: [],
        status: GameStatus.checkmate,
        sanMove: 'e5#',
      ),
    );

    await container.read(gameNotifierProvider.notifier).applyPlayerMove('e2e4');

    expect(mockStats.calls, contains('loss:medium'));
  });

  test('records loss on resign', () {
    setupStart();
    container.read(gameNotifierProvider.notifier).resign();
    expect(mockStats.calls, contains('loss:medium'));
  });

  test('does not record on stalemate', () async {
    setupStart();
    when(() => repo.applyMove('e2e4')).thenReturn(
      const GameMoveResult(
        fen: 'stalemate_fen b - - 0 1',
        legalMoves: [],
        status: GameStatus.stalemate,
        sanMove: 'e4',
      ),
    );

    await container.read(gameNotifierProvider.notifier).applyPlayerMove('e2e4');

    expect(mockStats.calls, isEmpty);
  });

  test('clearGame does not record any result', () {
    setupStart();
    container.read(gameNotifierProvider.notifier).clearGame();
    expect(mockStats.calls, isEmpty);
  });
});
```

- [ ] **Step 2: Run to verify tests fail**

```bash
cd chess_app && flutter test test/features/game/domain/game_notifier_test.dart --reporter=compact
```

Expected: new stats tests fail.

- [ ] **Step 3: Add `_recordResultIfTerminal` and wire it in `GameNotifier`**

In `chess_app/lib/features/game/domain/game_notifier.dart`, add import:

```dart
import 'package:chess_app/features/stats/data/stats_service.dart';
```

Add the private helper after `clearGame()`:

```dart
void _recordResultIfTerminal(GameState previous, GameState next) {
  if (previous.status != GameStatus.playing) return;

  if (next.status == GameStatus.checkmate) {
    // FEN active color is the LOSER's turn (the move they never get to make).
    // Opposite color = the one who delivered checkmate = winner.
    final fenActive = next.fen.split(' ')[1];
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
```

In `applyPlayerMove`, replace the inline `state = current.copyWith(...)` assignment with a named variable so it can be passed to `_recordResultIfTerminal`. The AI trigger call (`_triggerAiMove`) must be preserved below it. Full replacement for the block after `final playerMove = ...`:

```dart
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
```

In `_triggerAiMove`, replace the entire `try` block body (currently assigns `state = state?.copyWith(...)` with spread `[...(state!.history), aiMove]`) with the following, capturing `prevState` before the update so it can be passed to `_recordResultIfTerminal`. Note that `[...(state!.history)]` in the original must also become `prevState.history` to avoid a stale-read after assignment:

```dart
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
```

In `resign()`:

```dart
void resign() {
  final current = state;
  if (current == null) return;
  final resigned = current.copyWith(status: GameStatus.resigned);
  state = resigned;
  _recordResultIfTerminal(current, resigned);
}
```

Note: `applyPlayerMove` and `_triggerAiMove` currently use `state = current.copyWith(...)` inline — refactor to capture the new state in a local variable before assigning to `state`, so it can be passed to `_recordResultIfTerminal`. See the code above for the pattern.

- [ ] **Step 4: Run all game_notifier tests**

```bash
cd chess_app && flutter test test/features/game/domain/game_notifier_test.dart --reporter=compact
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/game/domain/game_notifier.dart test/features/game/domain/game_notifier_test.dart
git commit -m "feat: record game win/loss stats in GameNotifier on terminal status"
```

---

## Chunk 3: Stats Screen & Navigation

### Task 7: Create the Stats screen

**Files:**
- Create: `chess_app/lib/features/stats/presentation/stats_screen.dart`
- Modify: `chess_app/lib/core/router/app_router.dart`

- [ ] **Step 1: Create `stats_screen.dart`**

Create `chess_app/lib/features/stats/presentation/stats_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final credits = ref.watch(creditsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('My Stats'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            tabs: [
              Tab(text: 'Puzzles'),
              Tab(text: 'Games'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PuzzlesTab(stats: stats, credits: credits),
            _GamesTab(stats: stats),
          ],
        ),
      ),
    );
  }
}

class _PuzzlesTab extends StatelessWidget {
  final StatsState stats;
  final int credits;

  const _PuzzlesTab({required this.stats, required this.credits});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
          label: 'Credits',
          value: '$credits',
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Solved', value: '${stats.puzzlesSolved}')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Perfect', value: '${stats.perfectSolves}')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Hints Used', value: '${stats.totalHintsUsed}')),
          ],
        ),
      ],
    );
  }
}

class _GamesTab extends StatelessWidget {
  final StatsState stats;

  const _GamesTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final levels = DifficultyLevel.values;
    int totalWins = 0;
    int totalLosses = 0;
    for (final d in levels) {
      totalWins += stats.wins[d] ?? 0;
      totalLosses += stats.losses[d] ?? 0;
    }
    final total = totalWins + totalLosses;
    final overallRate = total == 0 ? null : totalWins / total;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: const [
                    Expanded(child: Text('Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(width: 32, child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(width: 32, child: Text('L', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(width: 48, child: Text('Win %', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...levels.map((d) {
                final w = stats.wins[d] ?? 0;
                final l = stats.losses[d] ?? 0;
                final played = w + l;
                final rate = played == 0 ? null : w / played;
                return _DifficultyRow(level: d, wins: w, losses: l, rate: rate);
              }),
              const Divider(height: 1),
              _DifficultyRow(
                label: 'Overall',
                wins: totalWins,
                losses: totalLosses,
                rate: overallRate,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final DifficultyLevel? level;
  final String? label;
  final int wins;
  final int losses;
  final double? rate;
  final bool bold;

  const _DifficultyRow({
    this.level,
    this.label,
    required this.wins,
    required this.losses,
    required this.rate,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final played = wins + losses;
    final rateText = rate == null ? '—' : '${(rate! * 100).round()}%';
    final rateColor = rate == null
        ? AppColors.textSecondary
        : rate! >= 0.6
            ? AppColors.successGreen
            : rate! >= 0.3
                ? const Color(0xFFF59E0B)
                : AppColors.errorRed;
    final name = label ?? (level != null ? _capitalize(level!.name) : '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              played == 0 ? '—' : '$wins',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              played == 0 ? '—' : '$losses',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              rateText,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: rateColor),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  const _StatCard({required this.label, required this.value, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? AppColors.accent, size: 20),
            const SizedBox(height: 6),
          ],
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add `/stats` route to `app_router.dart`**

In `chess_app/lib/core/router/app_router.dart`, add the import:

```dart
import 'package:chess_app/features/stats/presentation/stats_screen.dart';
```

Add the route inside the `routes` list:

```dart
GoRoute(
  path: '/stats',
  builder: (context, state) => const StatsScreen(),
),
```

- [ ] **Step 3: Verify app compiles**

```bash
cd chess_app && flutter build macos --debug 2>&1 | tail -5
```

Expected: `Build complete`.

- [ ] **Step 4: Commit**

```bash
git add lib/features/stats/presentation/stats_screen.dart lib/core/router/app_router.dart
git commit -m "feat: add Stats screen with Puzzles/Games tabs and /stats route"
```

---

### Task 8: Add "My Stats" button to HomeScreen

**Files:**
- Modify: `chess_app/lib/features/home/presentation/home_screen.dart`

- [ ] **Step 1: Add the "My Stats" outlined button after the Puzzles button**

In `home_screen.dart`, after the closing `),` of the Puzzles `SizedBox`, add:

```dart
const SizedBox(height: 12),

// My Stats
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      side: const BorderSide(color: AppColors.divider),
    ),
    icon: const Icon(Icons.bar_chart_rounded, size: 18),
    label: const Text('My Stats', style: TextStyle(fontSize: 16)),
    onPressed: () => context.push('/stats'),
  ),
),
```

- [ ] **Step 2: Verify UI renders (hot reload or build)**

```bash
cd chess_app && flutter build macos --debug 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/home_screen.dart
git commit -m "feat: add My Stats button to HomeScreen"
```

---

## Chunk 4: UX Improvements

### Task 9: Persistent Settings button on all screens

**Files:**
- Modify: `chess_app/lib/features/game/presentation/game_screen.dart`
- Modify: `chess_app/lib/features/game/presentation/difficulty_setup_screen.dart`
- Modify: `chess_app/lib/features/puzzles/presentation/puzzle_list_screen.dart`
- Modify: `chess_app/lib/features/puzzles/presentation/puzzle_screen.dart`
- Modify: `chess_app/lib/features/stats/presentation/stats_screen.dart` (already has it — verify)

The settings icon must use `context.push('/settings')` on every screen so the back arrow returns to the calling screen. `HomeScreen` already does this correctly.

- [ ] **Step 1: Add settings icon to `GameScreen` AppBar**

In `game_screen.dart`, in the `AppBar` `actions`, the list currently has `const []`. Replace:

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.push('/settings'),
  ),
],
```

- [ ] **Step 2: Add settings icon to `DifficultySetupScreen` AppBar**

In `difficulty_setup_screen.dart`, in the `AppBar`, add:

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.push('/settings'),
  ),
],
```

- [ ] **Step 3: Add settings icon to `PuzzleListScreen` AppBar**

Open `chess_app/lib/features/puzzles/presentation/puzzle_list_screen.dart`. First add the go_router import if not already present:

```dart
import 'package:go_router/go_router.dart';
```

Find the `AppBar` and add or update its `actions`:

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.push('/settings'),
  ),
],
```

- [ ] **Step 4: Add settings icon to `PuzzleScreen` AppBar**

In `puzzle_screen.dart`, replace the existing `actions` list (which contains only the credits `Padding/Chip`) with the following, appending the settings `IconButton` after it:

```dart
actions: [
  // Credits badge (unchanged)
  Padding(
    padding: const EdgeInsets.only(right: 16),
    child: Chip(
      avatar: const Icon(Icons.star_rounded,
          size: 16, color: Color(0xFFF59E0B)),
      label: Text(
        '$credits',
        style: const TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13),
      ),
      backgroundColor: const Color(0xFFFEF3C7),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    ),
  ),
  IconButton(
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.push('/settings'),
  ),
],
```

- [ ] **Step 5: Verify `StatsScreen` settings icon is correct**

The `StatsScreen` created in Task 7 uses `context.push('/settings')` and has `import 'package:go_router/go_router.dart'`. Confirm both are present in the committed file.

- [ ] **Step 6: Build to verify no compile errors**

```bash
cd chess_app && flutter build macos --debug 2>&1 | tail -5
```

- [ ] **Step 7: Commit**

```bash
git add lib/features/game/presentation/game_screen.dart \
        lib/features/game/presentation/difficulty_setup_screen.dart \
        lib/features/puzzles/presentation/puzzle_list_screen.dart \
        lib/features/puzzles/presentation/puzzle_screen.dart \
        lib/features/stats/presentation/stats_screen.dart
git commit -m "feat: add persistent settings icon to all screen AppBars"
```

---

### Task 10: Resign confirmation dialog

**Files:**
- Modify: `chess_app/lib/features/game/presentation/game_screen.dart`

- [ ] **Step 1: Add `_handleResign` method to `_GameScreenState`**

In `game_screen.dart`, add this method to `_GameScreenState` (after `_onSquareTap`):

```dart
Future<void> _handleResign() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Resign game?'),
      content: const Text('This will count as a loss.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Resign'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    ref.read(gameNotifierProvider.notifier).resign();
  }
}
```

- [ ] **Step 2: Wire `_handleResign` as the `onResign` callback**

In `build()`, update the player `_PlayerInfoPanel` call. Change:

```dart
onResign: () => ref.read(gameNotifierProvider.notifier).resign(),
```

To:

```dart
onResign: _handleResign,
```

- [ ] **Step 3: Build to verify**

```bash
cd chess_app && flutter build macos --debug 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/game/presentation/game_screen.dart
git commit -m "feat: add resign confirmation dialog before calling resign()"
```

---

### Task 11: "Back to Home" in Settings

**Files:**
- Modify: `chess_app/lib/features/settings/presentation/settings_screen.dart`

- [ ] **Step 1: Add required imports to `settings_screen.dart`**

Add these imports:

```dart
import 'package:go_router/go_router.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/models.dart';
```

- [ ] **Step 2: Add the conditional "Back to Home" tile**

`SettingsScreen` is a `ConsumerWidget` with access to `ref`. In `build()`, before returning the `Scaffold`, add:

```dart
final gameState = ref.watch(gameNotifierProvider);
final showBackToHome = gameState != null && gameState.status == GameStatus.playing;
```

At the bottom of the `ListView` children list, add:

```dart
if (showBackToHome) ...[
  const Divider(),
  ListTile(
    leading: const Icon(Icons.home_outlined),
    title: const Text('Back to Home'),
    subtitle: const Text('Leaves the current game without recording a result'),
    onTap: () {
      ref.read(gameNotifierProvider.notifier).clearGame();
      context.go('/');
    },
  ),
],
```

- [ ] **Step 3: Build to verify**

```bash
cd chess_app && flutter build macos --debug 2>&1 | tail -5
```

- [ ] **Step 4: Run full test suite**

```bash
cd chess_app && flutter test --reporter=compact
```

Expected: all tests pass.

- [ ] **Step 5: Final commit**

```bash
git add lib/features/settings/presentation/settings_screen.dart
git commit -m "feat: add Back to Home option in Settings that discards game without recording result"
```

---

## Final Verification

- [ ] Run the full test suite one last time:

```bash
cd chess_app && flutter test --reporter=compact
```

Expected: all tests pass, no failures.

- [ ] Build for macOS and manually verify:
  1. Home screen shows "My Stats" button — tapping opens Stats screen
  2. Stats screen Puzzles tab shows credits, solved count, perfect count
  3. Stats screen Games tab shows per-difficulty table (all `—` initially)
  4. Solve a puzzle — credits increase, stats update
  5. Play a game to completion — win/loss recorded in Games tab
  6. Settings icon (⚙️) appears on every screen
  7. Tapping flag icon in game shows "Resign game?" dialog — Cancel does nothing, Resign ends game and records a loss
  8. Opening Settings mid-game shows "Back to Home" tile — tapping returns to `/` with no loss recorded
  9. Opening Settings when no game is active shows no "Back to Home" tile
