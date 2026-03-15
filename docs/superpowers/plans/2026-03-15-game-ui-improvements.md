# Game UI Improvements Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix move legality (castling UX), redesign move history as a horizontal chip strip, add simple undo (takeback), and add piece slide animation.

**Architecture:** Domain-first — update `GameState` and `GameNotifier` for fenHistory/undo, then build new presentation widgets (`MoveHistoryStrip`, `AnimatedPiece`), then wire everything together in `GameScreen`.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `chess` Dart package v0.8.1, `TweenAnimationBuilder` for animation, `mocktail` for mocks in tests.

---

## Chunk 1: Domain Layer

### Task 1: Add `fenHistory` and `canUndo` to `GameState`

**Files:**
- Modify: `chess_app/lib/features/game/domain/game_state.dart`
- Modify: `chess_app/test/features/game/domain/models_test.dart`

**Context:** `GameState` is an immutable value class. We add an optional `fenHistory` field (default `[]`) and a computed `canUndo` getter. Making it optional means all existing construction sites (persistence restore, tests) continue to compile without changes.

- [ ] **Step 1.1: Write failing tests for `canUndo`**

Add to `chess_app/test/features/game/domain/models_test.dart` (inside `main()`):

```dart
group('GameState.canUndo', () {
  const baseState = GameState(
    fen: GameState.kStartFen,
    history: [],
    legalMoves: [],
    playerColor: Side.white,
    difficulty: DifficultyLevel.easy,
    status: GameStatus.playing,
  );

  test('false when fenHistory is empty (restored session)', () {
    final s = baseState.copyWith(
      history: [const Move(uci: 'e2e4', san: 'e4'), const Move(uci: 'e7e5', san: 'e5')],
      fenHistory: [],
    );
    expect(s.canUndo, isFalse);
  });

  test('false when history has fewer than 2 moves', () {
    final s = baseState.copyWith(
      history: [const Move(uci: 'e2e4', san: 'e4')],
      fenHistory: [GameState.kStartFen, 'fen_after_e4'],
    );
    expect(s.canUndo, isFalse);
  });

  test('false when AI is thinking', () {
    final s = baseState.copyWith(
      history: [const Move(uci: 'e2e4', san: 'e4'), const Move(uci: 'e7e5', san: 'e5')],
      fenHistory: [GameState.kStartFen, 'fen1', 'fen2'],
      isAiThinking: true,
    );
    expect(s.canUndo, isFalse);
  });

  test('true when history>=2, fenHistory>=2, not thinking', () {
    final s = baseState.copyWith(
      history: [const Move(uci: 'e2e4', san: 'e4'), const Move(uci: 'e7e5', san: 'e5')],
      fenHistory: [GameState.kStartFen, 'fen_after_e4', 'fen_after_e5'],
    );
    expect(s.canUndo, isTrue);
  });
});
```

- [ ] **Step 1.2: Run tests to verify they fail**

```bash
cd chess_app && flutter test test/features/game/domain/models_test.dart
```

Expected: compile error — `canUndo` getter doesn't exist yet; `copyWith` missing `fenHistory`.

- [ ] **Step 1.3: Implement `fenHistory` and `canUndo` in `GameState`**

Replace `chess_app/lib/features/game/domain/game_state.dart` with:

```dart
import 'models.dart';

class GameState {
  final String fen;
  final List<Move> history;
  final List<String> legalMoves;
  final Side playerColor;
  final DifficultyLevel difficulty;
  final GameStatus status;
  final bool isAiThinking;
  final List<String> fenHistory;

  static const kStartFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  const GameState({
    required this.fen,
    required this.history,
    required this.legalMoves,
    required this.playerColor,
    required this.difficulty,
    required this.status,
    this.isAiThinking = false,
    this.fenHistory = const [],
  });

  /// True when it is the human player's turn to move.
  bool get isPlayerTurn {
    final activeColor = fen.split(' ')[1];
    return (activeColor == 'w') == (playerColor == Side.white);
  }

  /// True when undo is available (not on restored sessions, not while AI thinks).
  bool get canUndo =>
      history.length >= 2 && !isAiThinking && fenHistory.length >= 2;

  GameState copyWith({
    String? fen,
    List<Move>? history,
    List<String>? legalMoves,
    Side? playerColor,
    DifficultyLevel? difficulty,
    GameStatus? status,
    bool? isAiThinking,
    List<String>? fenHistory,
  }) =>
      GameState(
        fen: fen ?? this.fen,
        history: history ?? this.history,
        legalMoves: legalMoves ?? this.legalMoves,
        playerColor: playerColor ?? this.playerColor,
        difficulty: difficulty ?? this.difficulty,
        status: status ?? this.status,
        isAiThinking: isAiThinking ?? this.isAiThinking,
        fenHistory: fenHistory ?? this.fenHistory,
      );
}
```

- [ ] **Step 1.4: Run tests to verify they pass**

```bash
cd chess_app && flutter test test/features/game/domain/models_test.dart
```

Expected: all tests in file pass.

- [ ] **Step 1.5: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all existing tests still pass (fenHistory defaults to `[]`, so nothing breaks).

- [ ] **Step 1.6: Commit**

```bash
cd chess_app && git add lib/features/game/domain/game_state.dart test/features/game/domain/models_test.dart
git commit -m "feat(game): add fenHistory and canUndo to GameState"
```

---

### Task 2: Refactor `GameNotifier` — extract `_triggerAiMove`, seed `fenHistory`

**Files:**
- Modify: `chess_app/lib/features/game/domain/game_notifier.dart`
- Modify: `chess_app/test/features/game/domain/game_notifier_test.dart`

**Context:** This refactors internals without changing external behaviour. The existing `applyPlayerMove` test must still pass. We extract `_triggerAiMove` from the AI leg of `applyPlayerMove`, update `applyPlayerMove` to append to `fenHistory`, and update `startGame` to seed `fenHistory`. We also update the existing test to verify `fenHistory` grows correctly.

- [ ] **Step 2.1: Update existing `applyPlayerMove` test to also assert `fenHistory`**

In `chess_app/test/features/game/domain/game_notifier_test.dart`, update the existing `'applyPlayerMove updates state and triggers AI move when not game over'` test — add assertions after the existing expects:

```dart
// fenHistory invariant: length == history.length + 1
expect(state.fenHistory.length, 3); // startFen + preFen_e4 + preFen_e5
expect(state.fenHistory[0], GameState.kStartFen);
```

Also add a test for `startGame` seeding:

```dart
test('startGame seeds fenHistory with starting FEN', () {
  when(() => repo.reset()).thenReturn(null);
  when(() => repo.loadPosition(any())).thenReturn(
    const GamePositionResult(fen: GameState.kStartFen, legalMoves: ['e2e4']),
  );

  container.read(gameNotifierProvider.notifier).startGame(
    playerColor: Side.white,
    difficulty: DifficultyLevel.easy,
  );

  final state = container.read(gameNotifierProvider)!;
  expect(state.fenHistory, [GameState.kStartFen]);
});
```

- [ ] **Step 2.2: Run tests to verify the new assertions fail (before implementation)**

```bash
cd chess_app && flutter test test/features/game/domain/game_notifier_test.dart
```

Expected: `applyPlayerMove` test fails on `fenHistory.length == 3`; `startGame seeds` test fails.

- [ ] **Step 2.3: Implement the refactored `GameNotifier`**

Replace `chess_app/lib/features/game/domain/game_notifier.dart` with:

```dart
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
      fenHistory: [result.fen], // seeds the fenHistory invariant
    );
  }

  Future<void> applyPlayerMove(String uciMove) async {
    final current = state;
    if (current == null || !current.isPlayerTurn) return;

    final preFen = current.fen;
    final playerResult = _repo.applyMove(uciMove);
    final playerMove = Move(uci: uciMove, san: playerResult.sanMove);

    state = current.copyWith(
      fen: playerResult.fen,
      history: [...current.history, playerMove],
      legalMoves: playerResult.legalMoves,
      status: playerResult.status,
      fenHistory: [...current.fenHistory, preFen],
      isAiThinking: playerResult.status == GameStatus.playing,
    );

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
      state = state?.copyWith(
        fen: aiResult.fen,
        history: [...(state!.history), aiMove],
        legalMoves: aiResult.legalMoves,
        status: aiResult.status,
        fenHistory: [...(state!.fenHistory), fen],
        isAiThinking: false,
      );
    } catch (e) {
      debugPrint('AI move failed: $e');
      state = state?.copyWith(isAiThinking: false);
    }
  }

  void undoLastMove() {
    final current = state;
    if (current == null || current.isAiThinking) return;
    if (current.history.length < 2) return;
    if (current.fenHistory.length < 2) return;

    final newHistory = current.history.sublist(0, current.history.length - 2);
    final newFenHistory =
        current.fenHistory.sublist(0, current.fenHistory.length - 2);
    final targetFen = newFenHistory.last;

    final result = _repo.loadPosition(targetFen);
    state = current.copyWith(
      fen: result.fen,
      legalMoves: result.legalMoves,
      history: newHistory,
      fenHistory: newFenHistory,
      status: GameStatus.playing,
      isAiThinking: false,
    );

    // Player is Black and board is now at start → AI must move first
    if (newHistory.isEmpty && current.playerColor == Side.black) {
      _triggerAiMove(result.fen, current.difficulty);
    }
  }

  void resign() {
    final current = state;
    if (current == null) return;
    state = current.copyWith(status: GameStatus.draw);
  }

  void clearGame() {
    state = null;
  }

  void restoreState(GameState gameState) {
    state = gameState;
  }
}
```

- [ ] **Step 2.4: Run tests**

```bash
cd chess_app && flutter test test/features/game/domain/game_notifier_test.dart
```

Expected: all tests pass.

- [ ] **Step 2.5: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all tests pass.

- [ ] **Step 2.6: Commit**

```bash
cd chess_app && git add lib/features/game/domain/game_notifier.dart test/features/game/domain/game_notifier_test.dart
git commit -m "feat(game): extract _triggerAiMove, populate fenHistory in GameNotifier"
```

---

### Task 3: Test `undoLastMove`

**Files:**
- Modify: `chess_app/test/features/game/domain/game_notifier_test.dart`

**Context:** `undoLastMove` is already implemented (Task 2). Now write the tests to lock in behaviour.

- [ ] **Step 3.1: Add undo tests to `game_notifier_test.dart`**

Add a new `group('undoLastMove', ...)` inside `main()`:

```dart
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
    expect(state.fenHistory, [GameState.kStartFen]);
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
```

- [ ] **Step 3.2: Run undo tests**

```bash
cd chess_app && flutter test test/features/game/domain/game_notifier_test.dart
```

Expected: all tests pass.

- [ ] **Step 3.3: Commit**

```bash
cd chess_app && git add test/features/game/domain/game_notifier_test.dart
git commit -m "test(game): add undoLastMove tests"
```

---

## Chunk 2: Presentation Layer

### Task 4: Create `MoveHistoryStrip` widget

**Files:**
- Create: `chess_app/lib/features/game/presentation/move_history_strip.dart`
- Create: `chess_app/test/features/game/presentation/move_history_strip_test.dart`

**Context:** Replaces the 120px `MoveHistoryPanel`. A 36px-tall horizontal scrollable row of move chips. Integrates into `GameScreen` in Task 7.

- [ ] **Step 4.1: Write failing widget test**

Create `chess_app/test/features/game/presentation/move_history_strip_test.dart`:

```dart
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/game/presentation/move_history_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders empty strip when no moves', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoveHistoryStrip(history: []))),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('1.'), findsNothing);
  });

  testWidgets('renders move chips for each move', (tester) async {
    const history = [
      Move(uci: 'e2e4', san: 'e4'),
      Move(uci: 'e7e5', san: 'e5'),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoveHistoryStrip(history: history))),
    );
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
  });

  testWidgets('latest move chip is visually distinct', (tester) async {
    const history = [
      Move(uci: 'e2e4', san: 'e4'),
      Move(uci: 'e7e5', san: 'e5'),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoveHistoryStrip(history: history))),
    );
    // Latest chip ('e5') should be wrapped in a Container with accent color
    final containers = tester.widgetList<Container>(find.byType(Container));
    final latestChip = containers.where((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.color != null &&
          decoration.color != const Color(0xFFF0F0F0);
    });
    expect(latestChip.isNotEmpty, isTrue);
  });
}
```

- [ ] **Step 4.2: Run test to verify it fails**

```bash
cd chess_app && flutter test test/features/game/presentation/move_history_strip_test.dart
```

Expected: compile error — `MoveHistoryStrip` not found.

- [ ] **Step 4.3: Create `MoveHistoryStrip`**

Create `chess_app/lib/features/game/presentation/move_history_strip.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/models.dart';

/// Compact 36px-tall horizontal scrollable chip strip showing the move history.
/// Latest move is highlighted in accent green; older moves are light grey.
class MoveHistoryStrip extends StatefulWidget {
  final List<Move> history;

  const MoveHistoryStrip({super.key, required this.history});

  @override
  State<MoveHistoryStrip> createState() => _MoveHistoryStripState();
}

class _MoveHistoryStripState extends State<MoveHistoryStrip> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveHistoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.length > oldWidget.history.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _buildChips(),
        ),
      ),
    );
  }

  List<Widget> _buildChips() {
    final chips = <Widget>[];
    for (var i = 0; i < widget.history.length; i += 2) {
      final moveNum = i ~/ 2 + 1;
      final whiteSan = widget.history[i].san;
      final blackSan = i + 1 < widget.history.length ? widget.history[i + 1].san : null;
      final isLatestWhite = i == widget.history.length - 1;
      final isLatestBlack = blackSan != null && i + 1 == widget.history.length - 1;

      chips.add(_NumberLabel('$moveNum.'));
      chips.add(_MoveChip(san: whiteSan, isLatest: isLatestWhite));
      if (blackSan != null) {
        chips.add(_MoveChip(san: blackSan, isLatest: isLatestBlack));
      }
    }
    return chips;
  }
}

class _NumberLabel extends StatelessWidget {
  final String text;
  const _NumberLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String san;
  final bool isLatest;
  const _MoveChip({required this.san, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isLatest ? AppColors.accent : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        san,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
          color: isLatest ? Colors.white : const Color(0xFF333333),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4.4: Run widget tests**

```bash
cd chess_app && flutter test test/features/game/presentation/move_history_strip_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 4.5: Commit**

```bash
cd chess_app && git add lib/features/game/presentation/move_history_strip.dart test/features/game/presentation/move_history_strip_test.dart
git commit -m "feat(game): add MoveHistoryStrip widget"
```

---

### Task 5: Update `BoardWidget` — add `hidePieceOnSquare`

**Files:**
- Modify: `chess_app/lib/features/game/presentation/board/board_widget.dart`
- Modify: `chess_app/test/features/game/presentation/board_widget_test.dart`

**Context:** `BoardWidget` needs to suppress rendering the piece at one specific square during animation (while the `AnimatedPiece` overlay is showing). The widget stays `StatelessWidget`.

- [ ] **Step 5.1: Write failing test**

Open `chess_app/test/features/game/presentation/board_widget_test.dart` and add:

```dart
testWidgets('hides piece on specified square', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BoardWidget(
          flipped: false,
          pieceSet: 'cburnett',
          boardTheme: BoardTheme.greenClean,
          position: const {'e2': 'P', 'e8': 'k'},
          legalMoves: const [],
          selectedSquare: null,
          lastMove: null,
          hidePieceOnSquare: 'e2',  // hide the white pawn on e2
          onSquareTap: (_) {},
        ),
      ),
    ),
  );
  // Only 1 piece should render (e8 king), not the hidden e2 pawn
  expect(find.byType(PieceWidget), findsOneWidget);
});
```

Note: you will need to import `PieceWidget` at the top of the test file:
```dart
import 'package:chess_app/features/game/presentation/board/piece_widget.dart';
```

- [ ] **Step 5.2: Run test to confirm it fails**

```bash
cd chess_app && flutter test test/features/game/presentation/board_widget_test.dart
```

Expected: compile error — `hidePieceOnSquare` param not found.

- [ ] **Step 5.3: Add `hidePieceOnSquare` to `BoardWidget`**

In `chess_app/lib/features/game/presentation/board/board_widget.dart`:

1. Add the field after `lastMove`:
```dart
final String? hidePieceOnSquare;
```

2. Add it to the constructor:
```dart
const BoardWidget({
  super.key,
  required this.flipped,
  required this.pieceSet,
  required this.boardTheme,
  required this.position,
  required this.legalMoves,
  required this.selectedSquare,
  required this.lastMove,
  required this.onSquareTap,
  this.hidePieceOnSquare,  // ← add this
});
```

3. In `_buildPieces`, add the skip condition:
```dart
Widget _buildPieces(double squareSize) {
  return Stack(
    children: position.entries
        .where((e) => e.key != hidePieceOnSquare)  // ← skip hidden square
        .map((entry) {
      // ... rest of existing code unchanged
    }).toList(),
  );
}
```

- [ ] **Step 5.4: Run tests**

```bash
cd chess_app && flutter test test/features/game/presentation/board_widget_test.dart
```

Expected: all tests pass.

- [ ] **Step 5.5: Commit**

```bash
cd chess_app && git add lib/features/game/presentation/board/board_widget.dart test/features/game/presentation/board_widget_test.dart
git commit -m "feat(board): add hidePieceOnSquare param to BoardWidget"
```

---

### Task 6: Create `AnimatedPiece` widget

**Files:**
- Create: `chess_app/lib/features/game/presentation/board/animated_piece.dart`

**Context:** Renders a single piece sliding from `fromOffset` to `toOffset` using `TweenAnimationBuilder`. Placed in a `Stack` overlay on top of `BoardWidget` by `GameScreen`. No test needed beyond a smoke test — the behaviour is inherently visual.

- [ ] **Step 6.1: Create `animated_piece.dart`**

Create `chess_app/lib/features/game/presentation/board/animated_piece.dart`:

```dart
import 'package:flutter/material.dart';
import 'piece_widget.dart';

/// Renders a chess piece animating from [fromOffset] to [toOffset].
/// Calls [onComplete] when the animation finishes (via TweenAnimationBuilder.onEnd).
/// Place this in a Stack on top of BoardWidget for the duration of the animation.
class AnimatedPiece extends StatelessWidget {
  final String pieceChar;
  final String pieceSet;
  final Offset fromOffset;
  final Offset toOffset;
  final double squareSize;
  final VoidCallback onComplete;

  const AnimatedPiece({
    super.key,
    required this.pieceChar,
    required this.pieceSet,
    required this.fromOffset,
    required this.toOffset,
    required this.squareSize,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: fromOffset, end: toOffset),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      onEnd: onComplete,
      builder: (context, offset, child) {
        return Positioned(
          left: offset.dx,
          top: offset.dy,
          width: squareSize,
          height: squareSize,
          child: child!,
        );
      },
      child: PieceWidget(
        pieceChar: pieceChar,
        pieceSet: pieceSet,
        size: squareSize,
      ),
    );
  }
}
```

- [ ] **Step 6.2: Verify it compiles**

```bash
cd chess_app && flutter analyze lib/features/game/presentation/board/animated_piece.dart
```

Expected: no errors.

- [ ] **Step 6.3: Commit**

```bash
cd chess_app && git add lib/features/game/presentation/board/animated_piece.dart
git commit -m "feat(board): add AnimatedPiece widget"
```

---

### Task 7: Wire everything in `GameScreen`

**Files:**
- Modify: `chess_app/lib/features/game/presentation/game_screen.dart`

**Context:** This task wires all the new pieces into the game screen:
1. Replace `MoveHistoryPanel` with `MoveHistoryStrip`
2. Add undo `IconButton` to app bar
3. Add castling UX fix in `_onSquareTap`
4. Add piece slide animation state (`_animatingMove`, `_hidePieceOn`)

**Prerequisite — verify castling UCI format before coding the mapping.** Before writing the castling fix, add a temporary `debugPrint` in `_onSquareTap` to confirm the package emits `e1g1`/`e1c1`:
```dart
// TEMP: remove before final commit
debugPrint('legalMoves: ${gameState.legalMoves}');
```
Start a game, verify castling UCI looks like `e1g1` (king to g1) not `e1h1` (king to rook). Then remove the print.

- [ ] **Step 7.1: Replace imports and `MoveHistoryPanel` with `MoveHistoryStrip`**

In `chess_app/lib/features/game/presentation/game_screen.dart`:

1. Replace the import:
```dart
// Remove:
import 'move_history_panel.dart';
// Add:
import 'move_history_strip.dart';
```

2. Replace the panel widget in `build()`:
```dart
// Remove:
SizedBox(
  height: 120,
  child: MoveHistoryPanel(history: gameState.history),
),
// Replace with:
MoveHistoryStrip(history: gameState.history),
```

- [ ] **Step 7.2: Add animation state fields and `didUpdateWidget`**

In `_GameScreenState`, add fields:
```dart
Move? _animatingMove;
String? _hidePieceOn;
int _lastHistoryLength = 0;
```

Add `didUpdateWidget` override (or update if it exists):
```dart
@override
void didUpdateWidget(GameScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  // Animation is triggered by watching gameState in build(), not here.
  // _lastHistoryLength is updated in build() after triggering animation.
}
```

In `build()`, before the `return Scaffold(...)`, add animation trigger logic:
```dart
// Trigger piece slide animation when a new move is added
final currentHistory = gameState.history;
if (currentHistory.length > _lastHistoryLength && currentHistory.isNotEmpty) {
  _lastHistoryLength = currentHistory.length;
  final lastMove = currentHistory.last;
  // Only animate if we have a valid from/to (not undo)
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      setState(() {
        _animatingMove = lastMove;
        _hidePieceOn = lastMove.to;
      });
    }
  });
}
```

- [ ] **Step 7.3: Update `BoardWidget` call to pass `hidePieceOnSquare` and wrap in `Stack` for animation overlay**

Find the `BoardWidget(...)` call in `build()` and wrap it:

```dart
Expanded(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final boardSize = constraints.maxWidth;
      final squareSize = boardSize / 8;

      return Stack(
        children: [
          BoardWidget(
            flipped: flipped,
            pieceSet: settings.pieceSet,
            boardTheme: settings.boardTheme,
            position: position,
            legalMoves: _legalMovesFromSelected,
            selectedSquare: _selectedSquare,
            lastMove: gameState.history.isNotEmpty ? gameState.history.last : null,
            hidePieceOnSquare: _hidePieceOn,
            onSquareTap: (sq) => _onSquareTap(sq, gameState),
          ),
          if (_animatingMove != null)
            AnimatedPiece(
              pieceChar: position[_animatingMove!.from] ??
                  _pieceCharForMove(_animatingMove!, position),
              pieceSet: settings.pieceSet,
              fromOffset: _squareToOffset(_animatingMove!.from, squareSize, flipped),
              toOffset: _squareToOffset(_animatingMove!.to, squareSize, flipped),
              squareSize: squareSize,
              onComplete: () {
                if (mounted) {
                  setState(() {
                    _animatingMove = null;
                    _hidePieceOn = null;
                  });
                }
              },
            ),
        ],
      );
    },
  ),
),
```

Add helper methods to `_GameScreenState`:

```dart
/// Returns the offset of a square's top-left corner in pixels.
static Offset _squareToOffset(String square, double squareSize, bool flipped) {
  final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square[1]) - 1;
  final col = flipped ? 7 - file : file;
  final row = flipped ? rank : 7 - rank;
  return Offset(col * squareSize, row * squareSize);
}

/// Finds the piece char for the moving piece. The static board already has the
/// piece at `to` (post-move FEN), so we look there. Falls back to '' if missing.
String _pieceCharForMove(Move move, Map<String, String> position) {
  return position[move.to] ?? '';
}
```

Add import at top of file:
```dart
import 'board/animated_piece.dart';
```

- [ ] **Step 7.4: Add undo button to app bar**

In `build()`, update the `AppBar` actions:

```dart
actions: [
  IconButton(
    icon: const Icon(Icons.undo),
    tooltip: 'Take back',
    onPressed: gameState.canUndo
        ? () => ref.read(gameNotifierProvider.notifier).undoLastMove()
        : null,
  ),
  PopupMenuButton<String>(
    onSelected: (value) {
      if (value == 'resign') {
        ref.read(gameNotifierProvider.notifier).resign();
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'resign', child: Text('Resign')),
    ],
  ),
],
```

- [ ] **Step 7.5: Add castling UX fix in `_onSquareTap`**

In `_onSquareTap`, in the `else` branch (second tap), add the castling remap logic BEFORE the `uciMove` is determined:

```dart
// Castling UX fix: if king is selected and player taps own rook,
// redirect to the king's landing square UCI.
const castlingMap = {
  'e1h1': 'e1g1', // white kingside
  'e1a1': 'e1c1', // white queenside
  'e8h8': 'e8g8', // black kingside
  'e8a8': 'e8c8', // black queenside
};
var uciBase = '$_selectedSquare$square';
final castlingRedirect = castlingMap[uciBase];
if (castlingRedirect != null && gameState.legalMoves.contains(castlingRedirect)) {
  uciBase = castlingRedirect;
}
```

Note: `uciBase` is now `var` instead of `final`. The rest of `_onSquareTap` uses `uciBase` unchanged.

- [ ] **Step 7.6: Run the app and smoke test**

```bash
cd chess_app && flutter run -d macos
```

Verify manually:
- Board fills the screen (no ugly 120px panel)
- Move chips appear at the bottom as moves are made
- Undo button is greyed out at game start, enabled after 2 moves
- Pieces slide when moves are made
- Castling: set up a position, verify clicking the rook triggers castling

- [ ] **Step 7.7: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all tests pass.

- [ ] **Step 7.8: Commit**

```bash
cd chess_app && git add lib/features/game/presentation/game_screen.dart
git commit -m "feat(game): wire undo, animation, MoveHistoryStrip, castling fix in GameScreen"
```

---

### Task 8: Cleanup and Final Verification

**Files:**
- Delete: `chess_app/lib/features/game/presentation/move_history_panel.dart`

- [ ] **Step 8.1: Delete the old panel**

```bash
cd chess_app && git rm lib/features/game/presentation/move_history_panel.dart
```

- [ ] **Step 8.2: Verify nothing imports the deleted file**

```bash
cd chess_app && grep -r "move_history_panel" lib/ test/
```

Expected: no output (nothing imports it).

- [ ] **Step 8.3: Run full test suite one final time**

```bash
cd chess_app && flutter test
```

Expected: all tests pass, no references to deleted file.

- [ ] **Step 8.4: Run flutter analyze**

```bash
cd chess_app && flutter analyze
```

Expected: no errors (info-level deprecation warnings are acceptable).

- [ ] **Step 8.5: Final commit**

```bash
cd chess_app && git add -A
git commit -m "chore(game): remove deprecated MoveHistoryPanel"
```
