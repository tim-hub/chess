# Movement Animation Design

**Date:** 2026-03-18
**Status:** Approved

## Goal

Add smooth piece animations to the chess board:
- Bot moves: piece slides from source to destination square (200ms), including the bot's final checkmate move
- Any capture (bot or player): captured piece fades out simultaneously (180ms)
- Player moves: no slide animation (piece jumps instantly as today)

## Scope

Changes are confined to the board widget layer and the game screen. No changes to game logic, state management, or routing.

## Affected Files

| File | Change |
|------|--------|
| `lib/features/game/presentation/board/board_widget.dart` | Convert to `StatefulWidget`, add overlay rendering |
| `lib/features/game/presentation/board/animated_piece.dart` | Change duration from 150ms → 200ms (line 29) |
| `lib/features/game/presentation/game_screen.dart` | Add `_lastMoveWasBot` local state; pass `animateLastMove` prop |
| `lib/features/puzzles/presentation/puzzle_screen.dart` | No code change — `animateLastMove` defaults to `false` |

## Props Change

One new **optional** prop on `BoardWidget` (defaults to `false`, keeping all existing call sites valid):

```dart
final bool animateLastMove; // default false
// Constructor: this.animateLastMove = false
```

`puzzle_screen.dart` does not pass this prop and compiles unchanged.

## `game_screen.dart` — Tracking Bot Moves

A new local state bool `_lastMoveWasBot` is added to `_GameScreenState` (initialized `false`).

**Setting:** in the existing `ref.listen` block, detect the AI-thinking → done transition. The condition must NOT require `GameStatus.playing` so that the bot's checkmate move is also animated:

```dart
ref.listen<GameState?>(gameNotifierProvider, (prev, next) {
  if (prev == null || next == null) return;

  // Animate bot move (including checkmate)
  if (prev.isAiThinking && !next.isAiThinking) {
    setState(() => _lastMoveWasBot = true);
    // Reset after the next frame so the flag does not persist across rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _lastMoveWasBot = false);
    });
  }

  // ... existing audio logic unchanged ...
});
```

The `addPostFrameCallback` resets the flag after the single frame in which `BoardWidget.didUpdateWidget` fires and consumes it, preventing stale `true` values on subsequent rebuilds.

**Board call site:**

```dart
BoardWidget(
  ...
  animateLastMove: _lastMoveWasBot,
)
```

## `BoardWidget` State

`BoardWidget` becomes a `StatefulWidget` with:

```dart
Map<String, String> _prevPosition = {};
Timer? _fadingTimer;
int _slideGeneration = 0;           // guards against stale onComplete callbacks

// Active animations (null = idle)
({String char, String from, String to})? _slidingPiece;
({String char, String square})? _fadingCapture;
```

### `initState`

```dart
@override
void initState() {
  super.initState();
  _prevPosition = widget.position; // seed so first bot move has a valid snapshot
}
```

### `didUpdateWidget` Logic

Order matters — read from `_prevPosition` before overwriting it:

```dart
@override
void didUpdateWidget(BoardWidget old) {
  super.didUpdateWidget(old);

  final newLastMove = widget.lastMove;
  if (newLastMove == null || newLastMove == old.lastMove) {
    _prevPosition = widget.position;
    return;
  }

  // 1. Detect capture: was the destination square occupied before this move?
  //    Uses newLastMove.to and the snapshot from before this move.
  //    Note: en passant captured pawn is NOT on lastMove.to — see Known Limitations.
  final capturedChar = _prevPosition[newLastMove.to];
  if (capturedChar != null) {
    _fadingTimer?.cancel();
    setState(() {
      _fadingCapture = (char: capturedChar, square: newLastMove.to);
    });
    _fadingTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _fadingCapture = null);
    });
  }

  // 2. Detect slide: only for bot moves.
  if (widget.animateLastMove) {
    final movingChar = _prevPosition[newLastMove.from];
    if (movingChar != null) {
      _slideGeneration++;
      final myGeneration = _slideGeneration;
      setState(() {
        _slidingPiece = (char: movingChar, from: newLastMove.from, to: newLastMove.to);
      });
      // onComplete clears _slidingPiece only if no newer animation has started
      // (see _onSlideComplete in the build section)
    }
  }

  // 3. Snapshot — must happen AFTER steps 1 & 2.
  _prevPosition = widget.position;
}
```

### `dispose`

```dart
@override
void dispose() {
  _fadingTimer?.cancel();
  super.dispose();
}
```

## Rendering Stack

```
Stack [
  _buildSquares()         // unchanged
  HighlightLayer          // unchanged
  _buildPieces()          // suppression: see below
  _SlidingPieceOverlay    // AnimatedPiece, rendered when _slidingPiece != null
  _FadingPieceOverlay     // AnimatedOpacity 1→0, rendered when _fadingCapture != null
  CoordinateLabels        // unchanged
]
```

**Suppression rule in `_buildPieces`:** three squares are hidden during animations:

```dart
.where((e) =>
  e.key != hidePieceOnSquare &&
  e.key != _slidingPiece?.from &&   // static source hidden; overlay owns it
  e.key != _slidingPiece?.to &&     // static dest hidden; prevents duplicate during slide
  e.key != _fadingCapture?.square   // fading overlay owns this square
)
```

**Why suppress `_slidingPiece.to`:** `widget.position` already has the piece at the destination the moment `didUpdateWidget` fires. Without suppression the piece appears there statically while the overlay slides in, producing a visible duplicate.

## `_SlidingPieceOverlay` and Stale-Callback Guard

```dart
void _onSlideComplete(int generation) {
  if (!mounted) return;
  if (generation != _slideGeneration) return; // newer animation already started
  setState(() => _slidingPiece = null);
}
```

`AnimatedPiece.onComplete` is wired to `() => _onSlideComplete(myGeneration)` where `myGeneration` is captured at the time `_slidingPiece` is set. If a second bot move arrives before the first animation finishes, `_slideGeneration` is incremented and the first `onComplete` becomes a no-op.

## Animation Specs

| Animation | Widget | Duration | Curve | Trigger |
|-----------|--------|----------|-------|---------|
| Piece slide | `AnimatedPiece` (update to 200ms) | 200ms | `easeOut` | Bot move, `animateLastMove: true` |
| Capture fade-out | `AnimatedOpacity` 1→0 | 180ms | `easeOut` | Any capture (`prevPosition[lastMove.to] != null`) |

Slide and fade run in parallel when the bot captures. For player captures, only the fade runs.

## Known Limitations (accepted for this iteration)

- **En passant:** the captured pawn sits on a different square than `lastMove.to`, so no fade plays for en passant captures. Rare edge case; accepted.
- **Castling:** only the king is animated (slide). The rook jumps instantly to its new square. Rook animation requires detecting a secondary move and is deferred.
- **Promotion:** no animation on the promoted piece appearing. Non-goal.
