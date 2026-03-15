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
When the player has a king selected and taps their own rook on h1/a1 (or h8/a8 for black), treat it as castling:
- Detect: selected square is king (`e1` or `e8`), tapped square is own rook (`h1`/`a1` or `h8`/`a8`)
- Map rook tap → king destination: h1→g1 (kingside), a1→c1 (queenside), h8→g8, a8→c8
- Only apply if that castling UCI is actually in `legalMoves` (so pinned castling is still blocked)

### Fix — Error logging (`game_notifier.dart`)
Replace `catch (_)` with `catch (e)` and add `debugPrint` so failures are visible during development.

---

## 2. Move History — Horizontal Chip Strip

### Current
`MoveHistoryPanel` is a 120px `ListView` at the bottom of the game screen. Takes too much vertical space, ugly.

### New Design
- **36px tall** horizontal scrollable row directly below the board
- Each move is a compact rounded chip: move number label (`1.`) + white chip + black chip
- Latest move chip: filled green background (`AppColors.accent`) with white text
- Older moves: light grey background (`#F0F0F0`), dark text
- Auto-scrolls right to show the latest chip on each new move
- "No moves yet" state: empty row (no placeholder text)

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
- `StatefulWidget` with `ScrollController`
- Renders a `SingleChildScrollView(scrollDirection: Axis.horizontal)` containing a `Row`
- Each move pair: `[number label, white chip, black chip?]`
- `didUpdateWidget` → auto-scroll to end when history grows

---

## 3. Simple Undo (Takeback)

### Behaviour
- Takes back the last **two** moves: the player's move and the AI's response
- If the player just moved but AI hasn't responded yet (AI thinking), undo is disabled
- If there are fewer than 2 moves in history, undo is disabled
- After undo, board returns to state before the player's last move; it is the player's turn again

### State change — `GameState`
Add `fenHistory` field:
```dart
final List<String> fenHistory;  // FEN snapshot before each move
```
`kStartFen` is added as `fenHistory[0]` when the game starts. Each `applyMove` prepends the pre-move FEN.

### `GameNotifier.undoLastMove()`
```dart
void undoLastMove() {
  final current = state;
  if (current == null || current.isAiThinking) return;
  if (current.history.length < 2) return;  // need at least player + AI move

  // Pop last 2 moves from history and fenHistory
  final newHistory = current.history.sublist(0, current.history.length - 2);
  final targetFen = current.fenHistory[current.fenHistory.length - 2];

  final result = _repo.loadPosition(targetFen);
  state = current.copyWith(
    fen: result.fen,
    legalMoves: result.legalMoves,
    history: newHistory,
    fenHistory: current.fenHistory.sublist(0, current.fenHistory.length - 2),
    status: GameStatus.playing,
    isAiThinking: false,
  );
}
```

### UI — `game_screen.dart`
Add `↩` `IconButton` to the app bar `actions`, positioned before the `PopupMenuButton`:
```dart
IconButton(
  icon: const Icon(Icons.undo),
  tooltip: 'Take back',
  onPressed: canUndo ? () => ref.read(gameNotifierProvider.notifier).undoLastMove() : null,
)
```
Where `canUndo = gameState.history.length >= 2 && !gameState.isAiThinking`.

---

## 4. Piece Slide Animation

### Approach
A dedicated moving-piece overlay rendered on top of the board. Only the actively-moving piece animates; all other pieces are static.

### New state in `BoardWidget` (or its parent)
Track the in-flight animation:
```dart
String? _animatingFrom;  // e.g. 'e2'
String? _animatingTo;    // e.g. 'e4'
```

### Mechanism
1. When `GameState.history` gains a new move, extract `lastMove.from` and `lastMove.to`
2. During the animation frame (~150ms), hide the piece at the destination square
3. Render an extra `TweenAnimationBuilder<Offset>` piece positioned from `from` offset → `to` offset
4. On animation complete, clear the animating state (piece at destination becomes visible again)

### Animation parameters
- Duration: `150ms`
- Curve: `Curves.easeOut`
- Only triggers on new moves (not on board flip or undo)

### Implementation notes
- `BoardWidget` gains `animatingMove` parameter (nullable `Move`)
- `_GameScreenState` tracks `Move? _animatingMove`, set on each new `lastMove`, cleared by animation callback
- The `_buildPieces` layer skips rendering the piece at `animatingTo` while animation is active

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
| `lib/features/game/domain/game_state.dart` | Add `fenHistory` field |
| `lib/features/game/domain/game_notifier.dart` | Add `undoLastMove()`, populate `fenHistory`, fix `catch` logging |
| `lib/features/game/presentation/game_screen.dart` | Undo button, castling fix, animation state, use `MoveHistoryStrip` |
| `lib/features/game/presentation/move_history_strip.dart` | New widget (replaces `move_history_panel.dart`) |
| `lib/features/game/presentation/board/board_widget.dart` | Add `animatingMove` param, skip dest piece during animation |
| `lib/features/game/presentation/board/animated_piece.dart` | New widget: `TweenAnimationBuilder` piece overlay |

`move_history_panel.dart` can be deleted once `MoveHistoryStrip` is in place.

---

## Out of Scope
- Forward navigation through move history (full game viewer)
- Stockfish on macOS (deferred until CocoaPods/iOS is set up)
- Sound effects
