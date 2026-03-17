# Puzzle Redesign — Spec

**Date:** 2026-03-17
**Status:** Approved

---

## Overview

Three problems are fixed together in one cohesive redesign:

1. **Hint bug** — hint highlight disappears on the next board tap (widget-local state is cleared by `_onSquareTap`)
2. **Puzzle selection UI** — current list has very wide, poorly-composed rows
3. **Overall playability** — chapter progression, stars, and a cleaner play experience

The redesign introduces a themed chapter system, a fixed & improved hint system, and a polished puzzle play screen.

---

## 1. Chapter System

### 1.1 Chapters

Nine themed chapters in this fixed order:

| # | Name | Icon | Puzzle count |
|---|------|------|-------------|
| 1 | Checkmate in 1 | ♟ | 25 |
| 2 | Forks | ⚔ | 20 |
| 3 | Pins & Skewers | 📌 | 20 |
| 4 | Discovered Attacks | 💥 | 18 |
| 5 | Sacrifices | 🎯 | 18 |
| 6 | Back Rank Mates | 🏰 | 15 |
| 7 | Endgames | ♛ | 20 |
| 8 | Checkmate in 2+ | ♟♟ | 20 |
| 9 | Advanced Tactics | ⚡ | 20 |

Puzzle counts are targets; actual counts depend on puzzle database content. Chapter assignment is derived at runtime by mapping a puzzle's existing `themes: List<String>` tags to a chapter (see §4.3 — no schema migration needed).

### 1.2 Star Thresholds

Each chapter awards 0–3 stars:

- **1★** — 50% of puzzles solved (unlocks next chapter)
- **2★** — 75% of puzzles solved
- **3★** — 100% of puzzles solved

Solving a puzzle = submitting the full correct move sequence at least once (hints allowed).

### 1.3 Unlock Rules

- Chapter 1 is always unlocked.
- Each subsequent chapter unlocks when the previous chapter earns at least 1★.
- Locked chapters are shown in the list, dimmed, with the unlock requirement displayed.

### 1.4 Data Model — `PuzzleChapter`

`PuzzleChapter` is a **view model** built by `ChapterNotifier`. It does not compute derived values itself; all counts and star ratings are pre-computed by the notifier before constructing the object.

```dart
class PuzzleChapter {
  final String id;             // e.g. 'checkmate_in_1'
  final String name;
  final String icon;           // emoji
  final List<String> puzzleIds;
  final int solvedCount;       // pre-computed from ChapterProgressRepository
  final bool isUnlocked;       // pre-computed: chapter index == 0 || prevChapter.starCount >= 1

  int get totalCount => puzzleIds.length;
  int get starCount {
    final pct = totalCount == 0 ? 0.0 : solvedCount / totalCount;
    if (pct >= 1.0) return 3;
    if (pct >= 0.75) return 2;
    if (pct >= 0.50) return 1;
    return 0;
  }
}
```

`ChapterNotifier` (a `StateNotifier<List<PuzzleChapter>>`) loads puzzle IDs and solved sets, constructs `PuzzleChapter` objects, and exposes the list to the UI. It calls `ChapterProgressRepository` during init and after each puzzle solve.

Chapter progress is persisted with `SharedPreferences` as a `Set<String>` of solved puzzle IDs per chapter.

---

## 2. Chapter List Screen

**Route:** `/puzzles` (replaces current puzzle list)

### Layout

- AppBar: "Puzzles" title + credit badge (★ N)
- Scrollable list of chapter cards, one per row
- Each card: left-colored border (green=complete, blue=in-progress, indigo=unlocked, grey=locked) + icon + name + progress bar + "X / Y solved" + star rating

### Card States

| State | Border color | Stars display | Sub-text |
|-------|-------------|---------------|----------|
| Complete (3★) | Green | ★★★ (gold) | "25 / 25 solved" |
| In progress | Blue | ★★☆ (partial gold) | "11 / 20 solved · 2★ at 15" |
| Unlocked, not started | Indigo | ☆☆☆ (grey) | "0 / 20 solved · unlocked" |
| Locked | Grey | — | "Earn 1★ in [prev chapter] to unlock" |

Tapping a locked card shows a snackbar explaining the unlock requirement. Tapping an unlocked card navigates directly to the puzzle play screen for that chapter's next unsolved puzzle (no intermediate chapter-detail screen).

---

## 3. Puzzle Play Screen

**Route:** `/puzzles/play/:puzzleId` (existing `/puzzles/:puzzleId`, renamed for clarity)

### 3.1 AppBar

- Leading: back arrow (returns to chapter list)
- Title: `"{chapter name} · #{puzzle_number_in_chapter}"` — e.g. "Forks · #8"
- Trailing: credit badge (★ N)

The puzzle number is the 1-based index within the chapter's puzzle list (not a global ID).

### 3.2 Board

No change to board widget itself. In `build()`, the screen reads `PuzzleSession.hintFromSquare` and `PuzzleSession.hintToSquare` (see §4.1) and passes them as highlight overlays to `BoardWidget`. Both getters return `null` when no hint is active, so no special-casing is needed in the board call.

### 3.3 Status Bar

Fixed-height row below the board:

- **Normal:** blue dot + "Your turn · {chapter theme verb}" — e.g. "Your turn · Find the fork"
- **Wrong move:** red inline bar — "✗ Not the right move — try again"

No modal bottom sheet for wrong moves.

### 3.4 Hint System (Fixed + Progressive)

**Root cause of bug:** `_onSquareTap` clears `_selectedSquare` and `_legalMovesFromSelected` on every tap. Hint sets these in widget-local state; the next board interaction wipes them.

**Fix:** `hintCount` (0 → 1 → 2) is stored in `PuzzleSession` and drives board highlights in `build()`. Widget-local `_selectedSquare` / `_legalMovesFromSelected` are used only for ordinary piece selection — **not** for hint state.

**Interaction precedence:** When `hintCount >= 1`, hint highlights are always shown. Ordinary piece-selection highlights (`_selectedSquare`) take visual priority when the player is actively selecting a piece (i.e., `_selectedSquare != null`). When the player taps a piece to select it, `_selectedSquare` is set and the piece-selection highlight is shown on top; the hint squares remain in `PuzzleSession` state and re-appear as soon as `_selectedSquare` is cleared (after a move attempt or tap-deselect).

Calling `useHint()` clears `_selectedSquare` and `_legalMovesFromSelected` in the widget to avoid the hint highlights being visually masked immediately after pressing the hint button.

**Hint levels:**

| hintCount | Board state | Button shown | Action |
|-----------|-------------|--------------|--------|
| 0 | No hint highlights | 💡 Hint | Press → hintCount = 1 |
| 1 | From-square highlighted in amber | 💡 Show full move | Press → hintCount = 2 |
| 2 | From + to-square highlighted | (disabled) | — |

**Credit model — deferred only:**

Hints do **not** deduct credits upfront. Instead, the solve reward is reduced:

```
earned = max(0, 10 − hintCount)
// hintCount=0 → +10  (no hint)
// hintCount=1 → +9   (from-square hint used)
// hintCount=2 → +8   (full hint used)
```

There is no upfront credit deduction when pressing the hint button. Credits are only awarded (possibly reduced) on puzzle completion. The old `creditsProvider.notifier.deduct()` call in `_useHint()` is removed.

Success criteria update: "Credits deducted correctly per hint level" should read "Solve reward reduced by 1 per hint level used."

### 3.5 Bottom Controls

The bottom controls area is a fixed-height row (72 px). It contains:

- **Hint button** (flexible width) — label and enabled state per §3.4
- **Reset button** — shown only when `isFailed`; resets puzzle to initial position and clears `hintCount` in the session

When the solved banner (§3.6) is visible, the bottom controls row is hidden (zero-height or replaced by the banner widget in the layout).

### 3.6 Solved Banner

When `session.isComplete`, replace the bottom controls area with an inline solved banner:

- Green gradient background, full width
- "✓ Solved!" + "+N ⭐ (X hint(s) used)"
- "Next →" button (advances immediately)
- Auto-advances after 2.5 seconds

The banner slot occupies the same position as the bottom controls row (the board area above it is unaffected). `showModalBottomSheet` is removed.

---

## 4. Domain Changes

### 4.1 `PuzzleSession`

`hintCount` already exists. Add two derived getters (computed from `expectedMove`):

```dart
String? get hintFromSquare =>
    hintCount >= 1 && expectedMove != null ? expectedMove!.substring(0, 2) : null;

String? get hintToSquare =>
    hintCount >= 2 && expectedMove != null ? expectedMove!.substring(2, 4) : null;
```

These are used in `PuzzleScreen.build()` to pass the appropriate squares to `BoardWidget` as highlight overlays.

### 4.2 `PuzzleNotifier`

- `useHint()` increments `hintCount` and emits new state (verify this — current code may only set a flag without emitting).
- Credit deduction is **removed** from `useHint()` and from the widget's `_useHint()` call site. Credits are awarded (reduced by `hintCount`) only in `_onPuzzleSolved()`.

**Chapter progress update after solve:**

`PuzzleNotifier` does not know which chapter a puzzle belongs to and must not depend on `ChapterNotifier`. Instead, `PuzzleScreen._onPuzzleSolved()` is responsible for updating chapter progress:

```dart
void _onPuzzleSolved() {
  final session = ref.read(puzzleNotifierProvider);
  if (session == null) return;

  ref.read(audioServiceProvider).playSuccess();

  final earned = (10 - session.hintCount).clamp(0, 10);
  ref.read(creditsProvider.notifier).add(earned);

  // Update chapter progress only if this is the first time solving
  final chapterId = widget.chapterId;  // passed to PuzzleScreen from navigation
  if (chapterId != null) {
    ref.read(chapterNotifierProvider.notifier)
       .markSolved(chapterId, session.puzzle.id);
  }

  _showSolvedBanner(earned);
}
```

`PuzzleScreen` receives `chapterId` as a constructor parameter (alongside `puzzleId`). When navigating from the chapter list, both are passed. `chapterId` may be null if a puzzle is opened outside the chapter flow (e.g., deep link by puzzle ID only) — in that case, chapter progress is not updated.

### 4.3 Chapter Assignment (no schema migration)

Chapters are defined in a static registry (`PuzzleChapterRegistry`) that maps Lichess theme tag strings to chapter IDs:

```dart
const Map<String, String> kTagToChapterId = {
  'mateIn1': 'checkmate_in_1',
  'fork': 'forks',
  'pin': 'pins_and_skewers',
  'skewer': 'pins_and_skewers',
  'discoveredAttack': 'discovered_attacks',
  'sacrifice': 'sacrifices',
  'backRankMate': 'back_rank_mates',
  'endgame': 'endgames',
  'mateIn2': 'checkmate_in_2_plus',
  'mateIn3': 'checkmate_in_2_plus',
  // advanced tactics: attraction, deflection, clearance, interference, zugzwang, quietMove
};
```

A puzzle belongs to the first chapter whose tags match any of its `themes` list. If no tag matches, the puzzle is unassigned and excluded from chapter counts. This mapping lives in a static file; no `Puzzle` model changes and no database migration are needed.

### 4.4 Chapter Progress Repository

New service: `ChapterProgressRepository`

```dart
class ChapterProgressRepository {
  Future<Set<String>> getSolvedIds(String chapterId);
  Future<void> markSolved(String chapterId, String puzzleId);
}
```

Backed by `SharedPreferences`. Key pattern: `chapter_solved_{chapterId}` → JSON-encoded list of puzzle IDs.

### 4.5 `ChapterNotifier`

New `StateNotifier<List<PuzzleChapter>>`:

```dart
class ChapterNotifier extends StateNotifier<List<PuzzleChapter>> {
  ChapterNotifier(this._progressRepo, this._puzzleRepo) : super([]);

  Future<void> load();           // builds PuzzleChapter list from registry + progress
  Future<void> markSolved(String chapterId, String puzzleId);  // updates progress + rebuilds state
}
```

`load()` is called once at app start or when navigating to `/puzzles`. `markSolved()` is called from `PuzzleScreen._onPuzzleSolved()` after a successful puzzle solve (see §4.2 — not from `PuzzleNotifier`).

---

## 5. Navigation

- `/puzzles` → `ChapterListScreen`
- `/puzzles/play/:puzzleId` → `PuzzleScreen` (existing route, updated path)

Tapping a chapter card navigates directly to the next unsolved puzzle in that chapter. No intermediate chapter-detail screen is built. If all puzzles in a chapter are already solved, navigate to the first puzzle in the chapter (replay mode).

**Replay mode rules:**
- The board and hint system work identically during replay.
- `ChapterProgressRepository.markSolved()` uses a `Set<String>`, so re-solving an already-solved puzzle is idempotent (no double-counting).
- Credits are **not** awarded again on replay. `_onPuzzleSolved()` checks whether the puzzle was already solved before awarding credits:

```dart
final alreadySolved = (await ref.read(chapterNotifierProvider.notifier)
    .isSolved(chapterId, session.puzzle.id));
if (!alreadySolved) {
  ref.read(creditsProvider.notifier).add(earned);
}
```

`ChapterNotifier.isSolved(chapterId, puzzleId)` returns true if the puzzle ID is already in the solved set. This prevents credit farming from replaying completed chapters.

The route change from `/puzzles/:puzzleId` to `/puzzles/play/:puzzleId` avoids conflicts with the `/puzzles` chapter list route and makes intent explicit.

---

## 6. Out of Scope

- Puzzle ratings or ELO adjustments
- Online puzzles or server sync
- Custom puzzle creation
- Adaptive difficulty
- Leaderboards
- Intermediate chapter-detail screen (chapter card → direct to next puzzle)

---

## 7. Success Criteria

- [ ] Hint highlights persist across board taps (bug fixed)
- [ ] Ordinary piece selection and hint highlights coexist without one erasing the other
- [ ] Chapter list shows all 9 chapters with correct progress and lock state
- [ ] Star ratings update correctly as puzzles are solved
- [ ] Next chapter unlocks after earning 1★
- [ ] Solve reward is reduced by 1 per hint level used (no upfront deduction)
- [ ] Solved banner is inline (not a modal); bottom controls hidden when banner is shown
- [ ] AppBar shows chapter name + puzzle number in chapter
