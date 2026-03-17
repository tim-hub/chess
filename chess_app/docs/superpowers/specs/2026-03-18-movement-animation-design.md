# Movement Animation Design

**Date:** 2026-03-18
**Status:** Approved

## Goal

Add smooth piece animations to the chess board:
- Bot moves: piece slides from source to destination square (200ms)
- Any capture (bot or player): captured piece fades out simultaneously (180ms)
- Player moves: no slide animation (piece jumps instantly as today)

## Scope

Changes are confined to the board widget layer. No changes to game logic, state management, or routing.

## Affected Files

| File | Change |
|------|--------|
| `lib/features/game/presentation/board/board_widget.dart` | Convert to `StatefulWidget`, add overlay rendering |
| `lib/features/game/presentation/board/animated_piece.dart` | Adjust duration to 200ms (was 150ms) |
| `lib/features/game/presentation/game_screen.dart` | Pass `animateLastMove` prop to `BoardWidget` |
| `lib/features/puzzles/presentation/puzzle_screen.dart` | No change needed (puzzles have no bot moves) |

## Props Change

One new prop on `BoardWidget`:

```dart
final bool animateLastMove; // default false
```

Set to `true` by `game_screen.dart` only after a bot move completes.

## State

`BoardWidget` becomes a `StatefulWidget` with:

```dart
Map<String, String> _prevPosition = {};   // position snapshot before last update

// Active animations (null = idle)
({String char, String from, String to})? _slidingPiece;
({String char, String square})? _fadingCapture;
```

## `didUpdateWidget` Logic

Fires on every position update:

1. **Detect capture:** if `prevPosition[lastMove.to]` contained a piece → set `_fadingCapture`
2. **Detect slide:** if `animateLastMove == true` → set `_slidingPiece` using `prevPosition[lastMove.from]`
3. **Snapshot:** `_prevPosition = oldWidget.position`

## Rendering Stack

```
Stack [
  _buildSquares()         // unchanged
  HighlightLayer          // unchanged
  _buildPieces()          // skips sliding source + fading capture square
  _SlidingPieceOverlay    // AnimatedPiece, visible when _slidingPiece != null
  _FadingPieceOverlay     // AnimatedOpacity 1→0, visible when _fadingCapture != null
  CoordinateLabels        // unchanged
]
```

**Suppression rule:**
- While `_slidingPiece` is set, `_buildPieces` skips `_slidingPiece.from`
- While `_fadingCapture` is set, `_buildPieces` skips `_fadingCapture.square`

This prevents a piece from appearing in both the static layer and the animated overlay simultaneously.

## Animation Specs

| Animation | Widget | Duration | Curve | Trigger |
|-----------|--------|----------|-------|---------|
| Piece slide | `AnimatedPiece` (existing) | 200ms | `easeOut` | Bot move, `animateLastMove: true` |
| Capture fade-out | `AnimatedOpacity` | 180ms | `easeOut` | Any capture (`lastMove.to` had a piece) |

Slide and fade run in parallel when the bot captures.

## Cleanup

- `_slidingPiece` → null via `AnimatedPiece.onComplete` callback
- `_fadingCapture` → null via `Future.delayed(Duration(milliseconds: 180))`

## `game_screen.dart` Integration

The existing `BoardWidget` call gains one prop:

```dart
BoardWidget(
  ...
  animateLastMove: !gameState.isPlayerTurn && !gameState.isAiThinking,
)
```

This evaluates to `true` exactly in the state window after the bot's move lands and before the player's next move — the correct moment to trigger the slide.

## Non-Goals

- No drag-and-drop (tap-to-move is kept)
- No promotion piece animation
- No puzzle screen animation (no bot in puzzles)
- No sound changes
