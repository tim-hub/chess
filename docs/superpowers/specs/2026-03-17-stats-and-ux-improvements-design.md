# Stats & UX Improvements — Design Spec

_Date: 2026-03-17_
_Status: Approved_

---

## Overview

Five coordinated improvements:

1. **Stats screen** — track puzzle credits and AI game win/loss records
2. **Persistent Settings button** — ⚙️ accessible from every screen
3. **Resign confirmation dialog** — prevent accidental resignations
4. **"Back to Home" in Settings** — discard game without counting a loss
5. **Stats as third home button** — surface the Stats screen from the Home screen

---

## 1. Stats Screen

### Route
`/stats` — added to `app_router.dart`

### Layout
Tabbed screen (`DefaultTabController`) with two tabs: **Puzzles** and **Games**.

#### Puzzles Tab
| Stat | Source |
|---|---|
| Credits balance | `ref.watch(creditsProvider)` (existing `CreditsService`) |
| Puzzles solved | `StatsState.puzzlesSolved` |
| Total hints used | `StatsState.totalHintsUsed` |
| Perfect solves | `StatsState.perfectSolves` (solved with 0 hints) |

#### Games Tab
Per-difficulty table with columns: Difficulty · W · L · Win %

- All 6 difficulty levels shown (Beginner → Master)
- Unplayed levels (wins == 0 && losses == 0) display `—` for all columns
- Win % color-coded: green ≥ 60%, amber 30–59%, red < 30%, grey for unplayed
- Summary row at bottom: total W / total L / overall Win %

---

## 2. "My Stats" Button on Home Screen

A tertiary outlined button added to `HomeScreen` below the existing Puzzles button:

```dart
OutlinedButton.icon(
  icon: const Icon(Icons.bar_chart_rounded),
  label: const Text('My Stats'),
  onPressed: () => context.push('/stats'),
)
```

- Same full-width `SizedBox(width: double.infinity)` wrapper as other home buttons
- Uses `context.push` (not `context.go`) so back arrow returns to Home
- Does **not** display a live credit count or badge — keeps the button static

---

## 3. Persistent Settings Button

The ⚙️ settings icon must appear in `actions` of every screen's AppBar. Use `context.push('/settings')` (push, not go) so the back arrow returns to the calling screen.

Screens to update:

| Screen | Current state |
|---|---|
| `HomeScreen` | ✓ already has settings icon |
| `DifficultySetupScreen` | add ⚙️ |
| `GameScreen` | add ⚙️ |
| `PuzzleListScreen` | add ⚙️ |
| `PuzzleScreen` | add ⚙️ (alongside existing credits chip) |
| `StatsScreen` | add ⚙️ (new screen) |

---

## 4. Resign Confirmation Dialog

**Trigger:** User taps the flag (🏳) icon in the player panel on `GameScreen`.

**Current flow:** `onResign` directly calls `gameNotifier.resign()`.

**New flow:** `onResign` shows a confirmation dialog first:

```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text('Resign game?'),
    content: const Text('This will count as a loss.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Resign'),
      ),
    ],
  ),
);
if (confirmed == true) {
  ref.read(gameNotifierProvider.notifier).resign();
}
```

The `resign()` method in `GameNotifier` records a loss internally (see §7).

**Implementation note:** `_PlayerInfoPanel.onResign` is currently typed as `VoidCallback?` (synchronous). The dialog requires `async/await`. Move the `showDialog` logic into a dedicated `_handleResign()` method on `_GameScreenState` and pass `onResign: _handleResign` to the panel. Update `_PlayerInfoPanel.onResign` type to `VoidCallback?` is fine — `_handleResign` is `async void` which matches `VoidCallback` in Dart.

---

## 5. "Back to Home" in Settings

`SettingsScreen` already extends `ConsumerWidget` and has access to `ref`.

Add a `Divider` and a `ListTile` at the **bottom** of the settings `ListView`:

```dart
// Use ref.watch (not ref.read) so the tile appears/disappears reactively
final gameState = ref.watch(gameNotifierProvider);
final showBackToHome = gameState != null && gameState.status == GameStatus.playing;

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
]
```

**Visibility rule:** Only shown when `status == GameStatus.playing`. A game that has already ended (checkmate, stalemate, resigned) is intentionally excluded — the player should use the game-over sheet's Home button in that case. The `ListTile` disappears reactively if the game ends while Settings is open (because `ref.watch` is used).

**Interaction with game-over sheet:** The game-over sheet is a modal on top of `GameScreen`. If the user somehow navigates to Settings while the sheet is showing, the game status will be terminal (not `playing`), so the tile will not appear. This is correct behavior.

**Provider lifetime:** `gameNotifierProvider` is a `StateNotifierProvider` with no `autoDispose`, so it remains alive while Settings is pushed on top of `GameScreen`. `ref.watch` in `SettingsScreen` will correctly receive updates if the game ends while Settings is open.

---

## 6. Stats Persistence — `StatsService`

### New file: `lib/features/stats/data/stats_service.dart`

`StatsService` is a `StateNotifier<StatsState>` backed by `SharedPreferences`. Follows the same pattern as `CreditsService`.

**Initialization:** `StatsService()` does not call `load()` in its constructor. `load()` must be called explicitly in `main()` before `runApp`, identical to how `CreditsService` works. If `SharedPreferences` throws during `load()`, catch the error, log it, and leave `state` at `StatsState.empty()` (all zeros). The app continues with a zeroed stats state rather than crashing.

### `StatsState` model

```dart
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

  // Not const — only a logical zero-value sentinel, not a singleton.
  static final empty = StatsState();

  StatsState copyWith({
    int? puzzlesSolved,
    int? totalHintsUsed,
    int? perfectSolves,
    Map<DifficultyLevel, int>? wins,
    Map<DifficultyLevel, int>? losses,
  }) => StatsState(
    puzzlesSolved: puzzlesSolved ?? this.puzzlesSolved,
    totalHintsUsed: totalHintsUsed ?? this.totalHintsUsed,
    perfectSolves: perfectSolves ?? this.perfectSolves,
    wins: wins ?? this.wins,
    losses: losses ?? this.losses,
  );
}
```

`StatsState` uses value semantics via `copyWith`. Riverpod triggers rebuilds because `state = state.copyWith(...)` always produces a new object reference. No `equatable` or `freezed` dependency is needed.

### SharedPreferences keys

`DifficultyLevel.name` (Dart's built-in enum `.name` property, which produces the lowercase identifier string) is the canonical serialization key. **Do not rename `DifficultyLevel` enum cases** — doing so would silently create new keys and lose saved data for existing users.

| Key | Type | Example |
|---|---|---|
| `stats.puzzles.solved` | int | `28` |
| `stats.puzzles.hints_used` | int | `5` |
| `stats.puzzles.perfect` | int | `23` |
| `stats.game.wins.<name>` | int | `stats.game.wins.medium` → `4` |
| `stats.game.losses.<name>` | int | `stats.game.losses.hard` → `2` |

### Methods

```dart
Future<void> load()
void recordPuzzleSolved({required int hintsUsed})
void recordGameWin(DifficultyLevel difficulty)
void recordGameLoss(DifficultyLevel difficulty)
```

**Persistence pattern:** The three `void` recording methods update `state` synchronously (via `copyWith`) and then fire an unawaited async write to `SharedPreferences` internally — identical to how `CreditsService.add` works. Call sites do **not** await these methods and need not be async. This is intentional: stats recording is fire-and-forget; a missed persist on an unexpected crash is acceptable.

---

## 7. When Stats Are Recorded

### Puzzle stats — call site in `PuzzleNotifier`

`recordPuzzleSolved` must be called **exactly once per puzzle**, at the moment `isComplete` transitions from `false` to `true`. The correct location is inside `_applyEngineResponse` when it sets `isComplete: true`, **and** inside `submitMove` when it sets `isComplete: true` directly (the branch where there is no engine response). In both cases, call:

```dart
_ref.read(statsProvider.notifier).recordPuzzleSolved(hintsUsed: state!.hintCount);
```

**Avoiding double-counting:** In `submitMove`, when `isComplete: true` is set and `_applyEngineResponse` is also called (line 72), do NOT call `recordPuzzleSolved` in both places. Call it only once — in `submitMove` immediately after setting `isComplete: true`, before the `_applyEngineResponse` call. `_applyEngineResponse` should never call `recordPuzzleSolved` directly; it only auto-plays the engine's final move.

**Hint count on reset:** `PuzzleSession.hintCount` resets to 0 when `resetPuzzle()` calls `loadPuzzle()`. This is intentional — if a player uses hints, resets the puzzle, and solves it cleanly on the second attempt, it records as a perfect solve. This simplifies tracking and is acceptable for a casual app.

### Game stats — call site in `GameNotifier`

Recording happens **inside `GameNotifier`**, not in the UI layer, immediately when `state` is updated to a terminal status. This avoids the `_gameOverShown` flag in `GameScreen` and keeps stats logic out of the view.

Add a private helper called after every state update that might be terminal:

```dart
void _recordResultIfTerminal(GameState previous, GameState next) {
  if (previous.status != GameStatus.playing) return;

  if (next.status == GameStatus.checkmate) {
    // After checkmate, the FEN active color is the LOSER's turn (the one who
    // would move next, but can't). So the winner is the opposite color.
    // e.g. FEN active == 'w' → white is to move → black just delivered checkmate → black won.
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

Call `_recordResultIfTerminal(current, updatedState)` in:
- `applyPlayerMove` — after computing `playerResult.status`
- `_triggerAiMove` — after computing `aiResult.status`
- `resign()` — pass `current` and the new resigned state

**`clearGame()`** does **not** call `_recordResultIfTerminal`. It unconditionally sets `state = null` with no stat side-effect.

---

## 8. Riverpod Provider

```dart
// lib/features/stats/data/stats_service.dart
final statsProvider = StateNotifierProvider<StatsService, StatsState>(
  (ref) => StatsService(), // always overridden in main()
);
```

In `main()`:

```dart
final statsService = StatsService();
await statsService.load();

// In ProviderScope overrides:
statsProvider.overrideWith((_) => statsService),
```

---

## 9. File Structure

```
lib/features/stats/
  data/
    stats_service.dart       # StatsService, StatsState, statsProvider
  presentation/
    stats_screen.dart        # TabBar screen: Puzzles tab + Games tab
```

---

## Out of Scope

- Streak tracking
- Charts or graphs (table sufficient)
- Resetting stats
- Per-session stats (lifetime totals only)
- Live credit count badge on the "My Stats" home button
