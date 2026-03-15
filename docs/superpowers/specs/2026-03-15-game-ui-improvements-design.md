# Game UI Improvements — Design Spec
Date: 2026-03-15

## Overview

Four improvements to the chess game screen:
1. Fix move legality bug (castling UX + silent error swallowing)
2. Redesign move history as a horizontal chip strip
3. Add simple undo (take back last player move + AI response)
4. Add piece slide animation

---

## 1. Move Legality Bug Fix

### Problem
Players report that some legal moves are blocked. The primary cause is a castling UX mismatch: the UI requires clicking the king's landing square (g1/c1 for white), but players instinctively click the rook. Additionally, the `catch (_)` in `GameNotifier.applyPlayerMove` silently swallows engine errors, leaving the game frozen on the AI's turn with no feedback.

### Fix — Castling UX (`game_screen.dart`)

**Prerequisite verification:** The `chess` Dart package (v0.8.1) emits castling as king-to-destination UCI (`e1g1` kingside, `e1c1` queenside). This follows from `ChessRepositoryImpl._legalMovesUci()` reading the verbose move map's `from`/`to` fields — the `to` field for castling is the king's landing square, not the rook's square. Implementer must confirm with a debug `print` of `legalMoves` from a castling-eligible position before writing the mapping.

**Rook-tap mapping:** When the player has a king selected and taps their own rook, redirect to the equivalent king-destination UCI and check legality before applying:

| King selected | Rook tapped | King destination UCI |
|---|---|---|
| e1 | h1 | e1g1 |
| e1 | a1 | e1c1 |
| e8 | h8 | e8g8 |
| e8 | a8 | e8c8 |

Only redirect if the resulting UCI is present in `gameState.legalMoves`. If it is not (castling rights lost, king in check, etc.), fall through to the normal deselect behaviour.

### Fix — Error logging (`game_notifier.dart`)
Replace `catch (_)` with `catch (e)` and add `debugPrint('AI move failed: $e')` so failures surface during development.

---

## 2. Move History — Horizontal Chip Strip

### Current
`MoveHistoryPanel` is a 120px `ListView` at the bottom of the game screen. Takes too much vertical space.

### New Design
- **36px tall** horizontal scrollable row directly below the board
- Each move is a compact rounded chip: move number label (`1.`) + white chip + black chip
- Latest move chip: filled green background (`AppColors.accent`) with white text
- Older moves: light grey background (`#F0F0F0`), dark text
- Auto-scrolls right to show the latest chip on each new move
- When no moves have been played: render the empty 36px row with no content (the "No moves yet" placeholder is intentionally removed)

### Layout change in `game_screen.dart`
Replace:
```dart
SizedBox(height: 120, child: MoveHistoryPanel(history: gameState.history))
```
With:
```dart
MoveHistoryStrip(history: gameState.history)  // new widget, 36px
```

### New widget: `move_history_strip.dart`
- `StatefulWidget` with a `ScrollController`
- `SingleChildScrollView(scrollDirection: Axis.horizontal)` wrapping a `Row`
- Each move pair rendered as: `[number label, white chip, (black chip)?]`
- `didUpdateWidget` → `animateTo(maxScrollExtent)` when `history.length` increases

`move_history_panel.dart` is deleted after this widget lands.

---

## 3. Simple Undo (Takeback)

### Behaviour
- Takes back the last **two** moves: the player's move and the AI's response
- Disabled (button greyed out) when: `history.length < 2`, `isAiThinking == true`, or `fenHistory.length < 2`
- **Playing-as-black edge case:** When the player is Black, the AI plays first. If undo empties the history (`history.length == 0`), after restoring the starting FEN, call `_triggerAiMove()` so the AI plays again immediately.
- Undo is **not available** on sessions restored from persistence until the player makes at least one new move (see persistence note below)

### `fenHistory` invariant
`GameState` carries a `List<String> fenHistory` with this invariant:

```
fenHistory.length == history.length + 1
fenHistory[0]    == starting FEN (before any move)
fenHistory[i]    == FEN before history[i-1] was applied  (for i >= 1)
```

**Both the player move and the AI move each append exactly one FEN entry to `fenHistory`** — before their respective `_repo.applyMove` calls — so after one full round-trip (player + AI) both `history` and `fenHistory` each grow by two, preserving the invariant.

### State change — `GameState`
```dart
// New field — optional with default so existing construction sites compile:
final List<String> fenHistory;

const GameState({
  // ... existing required params ...
  this.fenHistory = const [],   // default allows restored sessions to omit it
});

// Updated copyWith (excerpt):
GameState copyWith({
  // ... existing fields ...
  List<String>? fenHistory,
}) => GameState(
  // ... existing fields ...
  fenHistory: fenHistory ?? this.fenHistory,
);
```

`startGame()` must be updated to include `fenHistory: [result.fen]` in the `GameState(...)` constructor call — this seeds the invariant. Without this seed, the first player move appends to an empty list, making `fenHistory.length == 1` when `history.length == 1`, which breaks `fenHistory.length == history.length + 1` permanently.

Updated `startGame` excerpt:
```dart
void startGame({required Side playerColor, required DifficultyLevel difficulty}) {
  _repo.reset();
  final result = _repo.loadPosition(GameState.kStartFen);
  state = GameState(
    fen: result.fen,
    history: const [],
    legalMoves: result.legalMoves,
    playerColor: playerColor,
    difficulty: difficulty,
    status: GameStatus.playing,
    fenHistory: [result.fen],  // ← seeds the invariant
  );
}
```

**Persistence limitation (explicit):** `GamePersistenceService` does not persist `fenHistory`. Restored sessions have `fenHistory = []`. Because `canUndo` checks `fenHistory.length >= 2`, the undo button will be correctly greyed out for any restored session. This is a known, intentional limitation — undo re-enables automatically once the player makes their first post-restore move pair. No change to `game_persistence_service.dart` is needed; the default `[]` value handles this gracefully.

### `GameNotifier._triggerAiMove()`
This helper is extracted from the AI leg of `applyPlayerMove` to allow reuse in `undoLastMove`:

```dart
Future<void> _triggerAiMove(String fen, DifficultyLevel difficulty) async {
  // Repo is already at `fen` — no loadPosition call needed here.
  state = state?.copyWith(isAiThinking: true);
  try {
    final aiUci = await _engine.getBestMove(fen, difficulty);
    // Capture pre-AI-move FEN for fenHistory before applying
    final preMoveState = state;
    final aiResult = _repo.applyMove(aiUci);
    final aiMove = Move(uci: aiUci, san: aiResult.sanMove);
    state = state?.copyWith(
      fen: aiResult.fen,
      history: [...(state!.history), aiMove],
      legalMoves: aiResult.legalMoves,
      status: aiResult.status,
      fenHistory: [...(state!.fenHistory), fen],  // append pre-AI-move FEN
      isAiThinking: false,
    );
  } catch (e) {
    debugPrint('AI move failed: $e');
    state = state?.copyWith(isAiThinking: false);
  }
}
```

`applyPlayerMove` is refactored to call `_triggerAiMove` for the AI leg, and also appends the pre-player-move FEN to `fenHistory` before applying the player's move:

```dart
Future<void> applyPlayerMove(String uciMove) async {
  final current = state;
  if (current == null || !current.isPlayerTurn) return;

  final preFen = current.fen;  // snapshot before player's move
  final playerResult = _repo.applyMove(uciMove);
  final playerMove = Move(uci: uciMove, san: playerResult.sanMove);

  state = current.copyWith(
    fen: playerResult.fen,
    history: [...current.history, playerMove],
    legalMoves: playerResult.legalMoves,
    status: playerResult.status,
    fenHistory: [...current.fenHistory, preFen],  // append pre-player-move FEN
    isAiThinking: playerResult.status == GameStatus.playing,
  );

  if (playerResult.status == GameStatus.playing) {
    await _triggerAiMove(playerResult.fen, current.difficulty);
  }
}
```

### `GameNotifier.undoLastMove()`
```dart
void undoLastMove() {
  final current = state;
  if (current == null || current.isAiThinking) return;
  if (current.history.length < 2) return;
  if (current.fenHistory.length < 2) return;  // disabled on restored sessions

  final newHistory = current.history.sublist(0, current.history.length - 2);
  final newFenHistory = current.fenHistory.sublist(0, current.fenHistory.length - 2);
  final targetFen = newFenHistory.last;  // FEN before the undone player move

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
```

### `canUndo` — `GameState` getter
Add a computed getter to `GameState` so all callers use the same logic:
```dart
bool get canUndo =>
    history.length >= 2 && !isAiThinking && fenHistory.length >= 2;
```

### UI — `game_screen.dart`
```dart
IconButton(
  icon: const Icon(Icons.undo),
  tooltip: 'Take back',
  onPressed: gameState.canUndo
      ? () => ref.read(gameNotifierProvider.notifier).undoLastMove()
      : null,
)
```

---

## 4. Piece Slide Animation

### Approach
A dedicated moving-piece overlay on top of the board. Only the actively-moving piece animates; all other pieces remain static. `BoardWidget` stays a `StatelessWidget` — animation state lives in `_GameScreenState`.

### Animation timing
The animation triggers **after the new state has been applied** (post-move FEN). At that point the piece already sits at `lastMove.to` in the static position map. Therefore `hidePieceOnSquare = lastMove.to` suppresses the static copy at the destination, while `AnimatedPiece` visually slides the piece from `lastMove.from` → `lastMove.to`.

### `AnimatedPiece` widget (`animated_piece.dart`)
```dart
class AnimatedPiece extends StatelessWidget {
  final String pieceChar;   // e.g. 'P' (white pawn)
  final String pieceSet;    // 'cburnett' or 'merida'
  final Offset fromOffset;  // pixel top-left of origin square
  final Offset toOffset;    // pixel top-left of destination square
  final double squareSize;
  final VoidCallback onComplete;

  // Renders a TweenAnimationBuilder<Offset> animating fromOffset → toOffset
  // Duration: 150ms, Curve: Curves.easeOut
  // Uses onEnd callback (not value equality) to fire onComplete()
}
```

### `BoardWidget` changes
Add one parameter:
```dart
final String? hidePieceOnSquare;
```
`_buildPieces` skips the entry whose key == `hidePieceOnSquare`.

### Animation lifecycle in `_GameScreenState`
```
new history.length detected in didUpdateWidget
  → setState: _animatingMove = gameState.history.last
  → BoardWidget receives hidePieceOnSquare = _animatingMove!.to
  → AnimatedPiece overlay slides from _animatingMove.from to _animatingMove.to
  → AnimatedPiece.onEnd fires
  → setState: _animatingMove = null  (hidePieceOnSquare = null)
  → piece at destination reappears in static board
```

Only triggers when history grows (new move added). Undo decreases history length — no animation on undo.

---

## Layout Summary (Portrait-First)

```
┌─────────────────────────┐
│ Chess          [↩] [⋮]  │  ← app bar (slim)
├─────────────────────────┤
│                         │
│      8×8 Board          │  ← Expanded (fills remaining height)
│                         │
├─────────────────────────┤
│ 1. e4 e5  2. Nf3 Nc6 … │  ← MoveHistoryStrip (36px, horizontal scroll)
└─────────────────────────┘
```

---

## Files Changed

| File | Change |
|------|--------|
| `lib/features/game/domain/game_state.dart` | Add `fenHistory` (optional, default `[]`), `canUndo` getter, updated `copyWith` |
| `lib/features/game/domain/game_notifier.dart` | Extract `_triggerAiMove()`, refactor `applyPlayerMove` to append to `fenHistory`, add `undoLastMove()`, fix `catch` logging |
| `lib/features/game/presentation/game_screen.dart` | Undo button using `gameState.canUndo`, castling fix, animation state, use `MoveHistoryStrip` |
| `lib/features/game/presentation/move_history_strip.dart` | **New** — replaces `move_history_panel.dart` |
| `lib/features/game/presentation/board/board_widget.dart` | Add `hidePieceOnSquare` param |
| `lib/features/game/presentation/board/animated_piece.dart` | **New** — `TweenAnimationBuilder` overlay, uses `onEnd` for completion callback |

`move_history_panel.dart` is deleted. `game_persistence_service.dart` requires no change.

---

## Out of Scope
- Forward navigation through move history
- Stockfish on macOS
- Sound effects
- Persisting `fenHistory` across app restarts
