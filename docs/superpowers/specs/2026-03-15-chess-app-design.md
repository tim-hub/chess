# Chess App — Design Spec
**Date:** 2026-03-15
**Status:** Approved

---

## Overview

A cross-platform chess app for iOS and Android built with Flutter. Paid, one-time purchase with no ads, no in-app purchases, no subscriptions, and no network connection required. All AI and puzzle content runs fully offline on-device.

**v1 scope:** Play vs AI + Puzzle Challenges
**v1.2 scope:** Pass-and-play multiplayer (same device)

---

## Target Audience

Both casual players and serious/club-level players. The app scales from complete beginners (easy AI, hints enabled) to experienced players (strong AI, no hints, rated puzzles).

---

## Platform & Tech Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (single codebase, iOS + Android) |
| Minimum OS | iOS 16, Android API 23 (Android 6.0) |
| Chess rules engine | `chess` pub.dev package — move validation, FEN/PGN, legal move generation |
| AI engine | Stockfish via `stockfish_flutter` Flutter package (FFI, runs on-device) |
| State management | Riverpod |
| Navigation | go_router |
| Local storage | `sqflite` for puzzle database, `shared_preferences` for settings & game state |
| Puzzle source | Lichess open puzzle database (~50k puzzles, bundled as SQLite) |
| Piece graphics | Lichess open-source SVG piece sets (CBurnett or Merida) |
| Sound assets | Deferred to v1.1. Sound toggle is rendered in Settings UI in v1 and its value persisted to SharedPreferences, but no sounds play in v1. |

**Pre-implementation spikes required (before coding begins):**
1. Verify `stockfish_flutter` supports iOS arm64 + Android arm64/x86_64 with full-strength Stockfish 16 binary. Alternative: build Stockfish from source as a Flutter plugin using Dart FFI.
2. Verify the `chess` pub.dev package handles all edge cases correctly (en passant, castling, threefold repetition, 50-move rule). If the package is abandoned or unreliable, evaluate `dartchess` or `squares` as alternatives before committing to `chess`.

---

## Visual Style

**Green & Clean** — the chess.com palette:
- Light squares: `#eeeed2`
- Dark squares: `#769656`
- App background: light neutral (`#f5f5f0`)
- Accent: `#769656` (green)

Clean, minimal UI. Instantly recognizable to casual players.

---

## Architecture

Clean Architecture with feature modules. Three layers per feature:

- **presentation** — Flutter widgets, Riverpod providers, screens
- **domain** — pure Dart classes, no Flutter dependencies (fully unit-testable)
- **data** — external integrations (Stockfish FFI, SQLite)

```
lib/
├── core/
│   ├── theme/            # colors, text styles, board palette
│   ├── router/           # go_router route definitions
│   └── widgets/          # shared widgets (AppBar, buttons)
├── features/
│   ├── game/
│   │   ├── data/         # StockfishService, GameRepository
│   │   ├── domain/       # GameState, Move, DifficultyLevel, ChessEngine (abstract)
│   │   └── presentation/ # GameScreen, BoardWidget, PieceWidget, SquareWidget
│   └── puzzles/
│       ├── data/         # PuzzleDatabase, PuzzleRepository
│       ├── domain/       # Puzzle, PuzzleSession, PuzzleTheme
│       └── presentation/ # PuzzleScreen, PuzzleListScreen
└── main.dart

assets/
└── puzzles.db            # Lichess puzzle SQLite (~50k puzzles, ~15MB)
```

---

## Screen Navigation

```
Home  /
├── Difficulty Setup  /game/setup
│   └── Game  /game/play
├── Puzzles  /puzzles
│   └── Puzzle  /puzzles/:id
└── Settings  /settings
```

### Screen Descriptions

**Home (`/`)** — Logo, "Play vs AI" CTA, "Puzzles" CTA, Settings icon.

**Difficulty Setup (`/game/setup`)** — Choose difficulty level (Beginner / Easy / Medium / Hard / Expert / Master) and color (White / Black / Random). Difficulty maps to Stockfish Skill Level (0–20) and search depth.

| Difficulty | Skill Level | Depth |
|---|---|---|
| Beginner | 1 | 3 |
| Easy | 4 | 5 |
| Medium | 8 | 8 |
| Hard | 12 | 10 |
| Expert | 16 | 13 |
| Master | 20 | 15 |

**Game (`/game/play`)** — Interactive chess board, move history panel, captured pieces display, Resign and Draw offer buttons. Game-over bottom sheet on checkmate/stalemate/draw. **Draw offers:** The AI always declines draw offers in v1 (simple rule — no evaluation-based logic). **Pawn promotion:** When a pawn reaches the last rank, a modal bottom sheet appears with four piece options (Queen, Rook, Bishop, Knight). The move is not submitted until the user selects a piece. Auto-queen is not used. **Animation:** All moves (player and AI) animate with a 200ms slide. AI moves have an additional 300ms delay before the animation starts (realism).

- **Move history panel:** Displayed as a scrollable horizontal row of move pairs in SAN notation (e.g. "1. e4 e5  2. Nf3 Nc6"). The current move is highlighted in green. The panel auto-scrolls to keep the latest move visible.
- **Captured pieces:** Two rows — one above the board (opponent's captures) and one below (player's captures). Pieces displayed as small SVG icons sorted by value (Q, R, B, N, P). Point advantage shown as "+N" if one side leads.

**Puzzles (`/puzzles`)** — "Daily Puzzle" card pinned at top. Below it: a horizontal scrollable chip row for theme selection (one chip per theme; "All" chip selected by default to show no theme filter). The theme list is **hardcoded** — it is the known fixed Lichess puzzle theme set: `["All", "fork", "pin", "skewer", "discoveredAttack", "backRankMate", "mateIn1", "mateIn2", "mateIn3", "endgame", "middlegame", "opening", "sacrifice", "hangingPiece", "promotion", "quietMove", "defensiveMove", "attraction", "clearance", "xRayAttack"]`. A two-handle range slider for rating (600–2800, snaps to bands of 200; default: full range). Results list below, paginated 50 at a time with infinite scroll using `LIMIT 50 OFFSET N` (offset resets to 0 when filters change). Results sorted by popularity descending. Progress counter shows "N solved" and updates immediately when filters change (debounced 300ms to avoid redundant queries during slider drag). The count comes from a separate `SELECT COUNT(*)` query with the same filter predicate.

**Puzzle (`/puzzles/:id`)** — Chess board in puzzle position, "Find the best move" prompt, Hint button (2 hints: piece highlight → destination highlight), move feedback (success animation or shake on wrong), Next Puzzle button on completion.

**Settings (`/settings`)** — Board theme (2 options), piece set (2 options), sound on/off (non-functional in v1 — toggle is present and persisted but no sounds play), legal move hints on/off, coordinate labels on/off.

- **Board themes:** "Green & Clean" (light `#eeeed2` / dark `#769656`, default) and "Classic Wood" (light `#F0D9B5` / dark `#B58863`)
- **Piece sets:** "CBurnett" (default, modern flat design) and "Merida" (classic traditional design) — both from Lichess open-source SVGs, both bundled as assets

---

## Key Components

### ChessEngine (abstract interface)

```dart
abstract class ChessEngine {
  Future<Move> getBestMove(String fen, DifficultyLevel difficulty);
  void dispose();
}
```

`StockfishService` implements this interface, translating `DifficultyLevel` to UCI `setoption name Skill Level value N` and `go depth N` commands. The engine is initialized once at app start and kept alive for the session.

### Domain Value Types

```dart
// domain/ — pure Dart, no external package imports

enum DifficultyLevel { beginner, easy, medium, hard, expert, master }
// Maps to: Beginner=Skill1/depth3, Easy=Skill4/depth5, Medium=Skill8/depth8,
//          Hard=Skill12/depth10, Expert=Skill16/depth13, Master=Skill20/depth15

enum Side { white, black }

enum GameStatus { playing, checkmate, stalemate, draw }
// GameStatus.stalemate: shown as "Stalemate — Draw!" in the game-over sheet.
// GameStatus.draw: covers 50-move rule, threefold repetition, and insufficient
//   material — shown as "Draw by [rule]" in the game-over sheet.
// GameStatus.checkmate: shown as "Checkmate — [White/Black] wins!"
// The user-initiated "Draw offer" button is separate: the AI always declines it
// in v1, so it never sets GameStatus. It is purely a UI affordance.

class Move {
  final String uci;   // e.g. "e2e4", "e7e8q" (promotion = 5 chars)
  final String san;   // e.g. "e4", "Nf3", "O-O", "e8=Q"
  // from/to are convenience getters, not stored fields — derived from uci:
  String get from => uci.substring(0, 2);
  String get to   => uci.substring(2, 4);
  // Move is immutable. Equality is by uci string.
  // Created only after a move is applied (in GameMoveResult), never for hypothetical moves.
}
```

### GameState (Riverpod StateNotifier)

The domain layer is pure Dart — no dependency on the `chess` package. The `chess.Chess` instance lives in `GameRepository` (data layer) and is never exposed to the domain or presentation layers directly.

```dart
// domain/ — pure Dart, no external package imports
class GameState {
  final String fen;                  // current position as FEN string
  final List<Move> history;          // ordered list of moves played (with SAN)
  final List<String> legalMoves;     // legal moves as UCI strings (e.g. "e2e4")
                                     // UCI is sufficient for board square highlighting;
                                     // SAN is not needed for legal-but-unplayed moves
  final Side playerColor;
  final DifficultyLevel difficulty;
  final GameStatus status;           // playing | checkmate | stalemate | draw
  final bool isAiThinking;           // true while waiting for Stockfish response;
                                     // board is non-interactive when true
}
// Note: `history` uses Move (with SAN), `legalMoves` uses raw UCI strings.
// SAN generation requires full board context and is only possible after a move is applied,
// which is why legalMoves stays as UCI and Move objects are created only in GameMoveResult.
// On game restore, SAN strings are re-derived by GameRepository during move replay
// (the chess package generates SAN as each move is applied from the starting position).

// data/ — chess.Chess lives here only
abstract class GameRepository {
  // Load a position from FEN; returns legal moves in UCI for that position
  GamePositionResult loadPosition(String fen);

  // Apply a UCI move; returns updated FEN, legal moves, GameStatus, and SAN
  GameMoveResult applyMove(String uciMove);
}

class GamePositionResult {
  final String fen;
  final List<String> legalMoves; // UCI strings
}

class GameMoveResult {
  final String fen;
  final List<String> legalMoves;
  final GameStatus status;       // computed here via chess package
  final String sanMove;          // for move history display
}
```

`GameStatus` (checkmate, stalemate, draw, playing) is computed inside the `GameRepository` implementation using the `chess` package. This knowledge never leaks into domain or presentation layers.

### BoardWidget

```
BoardWidget
├── SquareWidget × 64        # tap-to-select / tap-to-move
├── PieceWidget              # SVG piece, animates on move (200ms slide)
├── HighlightLayer           # last move (yellow tint), legal move dots, check (red tint)
└── CoordinateLabels         # a–h, 1–8 (toggleable)
```

Legal moves are shown as dots on valid destination squares after selecting a piece. Only tappable squares are valid destinations — illegal moves are impossible at the UI layer.

**Promotion detection:** When the user taps a destination square, `BoardWidget` checks if any `legalMoves` UCI string matches `from + to` with a 5th character (e.g. `e7e8q`). If yes, the promotion piece selector modal is shown before the move is submitted. The UCI move submitted to `GameRepository` includes the chosen piece character.

**AI thinking state:** While `isAiThinking` is true, the board shows a subtle pulsing opacity on the AI's side and rejects all tap input. No spinner overlay — the animation is sufficient feedback on mobile.

### Puzzle Database Schema

```sql
CREATE TABLE puzzles (
  id          TEXT PRIMARY KEY,   -- Lichess puzzle ID
  fen         TEXT NOT NULL,       -- starting FEN position
  moves       TEXT NOT NULL,       -- full solution in UCI, space-separated
  rating      INTEGER,             -- Lichess rating (600–2800)
  themes      TEXT,                -- space-separated theme tags
  popularity  INTEGER,
  solved      INTEGER DEFAULT 0    -- 1 if user has solved this puzzle
);

CREATE INDEX idx_rating     ON puzzles(rating);
CREATE INDEX idx_popularity ON puzzles(popularity DESC);
CREATE INDEX idx_solved     ON puzzles(solved);

-- FTS5 virtual table for efficient theme filtering
-- themes column is tokenized by whitespace (each theme = one token)
CREATE VIRTUAL TABLE puzzles_fts USING fts5(
  id UNINDEXED,
  themes,
  content=puzzles,
  content_rowid=rowid
);
-- Query example: SELECT p.* FROM puzzles p
--   JOIN puzzles_fts f ON p.rowid = f.rowid
--   WHERE puzzles_fts MATCH 'fork'
--   AND p.rating BETWEEN 800 AND 1200
--   ORDER BY p.popularity DESC LIMIT 50;
```

On first launch, `puzzles.db` is copied from Flutter assets to the app's documents directory (required by sqflite). A loading screen is shown during this one-time copy (~2s on average hardware).

**Daily Puzzle:** Selected deterministically using `(year * 10000 + month * 100 + day) % puzzle_count`. `puzzle_count` is obtained via `SELECT COUNT(*) FROM puzzles` on first app launch, cached in SharedPreferences as `puzzle.count`. If the DB is unavailable (copy failure), the Daily Puzzle card is hidden. Integer arithmetic only — stable across all platforms and Dart versions. Evaluated in UTC; updates at UTC midnight. A solved daily puzzle counts toward the total solved count and is visually distinguished with a "Daily" badge on the Puzzles screen.

**FTS5 pre-population:** The bundled `puzzles.db` asset has the FTS5 virtual table (`puzzles_fts`) pre-populated at build time. The app does not rebuild FTS indexes on-device. The `puzzles.db` file is built via a one-time offline script that imports the Lichess CSV, inserts into `puzzles`, and runs `INSERT INTO puzzles_fts(puzzles_fts) VALUES('rebuild')` before the DB is committed to the assets folder.

### Puzzle Mechanic

**Lichess `moves` format:** The first move in the stored UCI sequence is the opponent's "setup move" — it is auto-played immediately when the puzzle loads to reach the interactive starting position. All subsequent moves alternate: user move → opponent response → user move → … The `fen` field is the position *before* the setup move.

Example: `moves: "e2e4 d7d5 e4e5"` → auto-play `e2e4` on load, user must find `d7d5`, then `e4e5` plays automatically. Puzzle complete.

**Pawn promotion in puzzles:** Promotion moves are encoded in UCI as the fifth character (e.g. `e7e8q` = promote to queen). If the solution move is a promotion, the app does not show the promotion modal — it applies the encoded piece directly and animates the promotion.

**Flow:**

1. Puzzle loads → setup move (moves[0]) auto-plays with 400ms delay
2. User is prompted: "White to move" / "Black to move"
3. User taps piece → taps destination
4. App compares move to moves[N] (the next expected user move)
   - **Correct** → opponent's response (moves[N+1]) plays automatically after 300ms; continue
   - **Wrong** → board shakes, "Not the best move — try again" toast
5. All user moves solved → **inline success state**: board freezes, green banner shows "Puzzle solved!" with the puzzle rating and theme tags. "Next Puzzle" (loads the next puzzle in the current filtered list order — the puzzle screen reads the `puzzleFilterProvider` Riverpod provider to re-query the DB for the next puzzle after the current one by popularity rank within the current filter; if accessed via Daily Puzzle, "Next Puzzle" loads a random puzzle with no filter applied) and "Back to Puzzles" buttons appear as an overlay on `/puzzles/:id`.
   **Wrong move retry:** The shake animation plays and the "Not the best move" toast appears, but the board resets to allow the user to try again. The move is not committed. Users can retry as many times as needed.
6. **Hint 1** — highlights the piece that needs to move. Hint button is shown before puzzle completion; disabled after both hints are used. Hint usage is not persisted.
   **Hint 2** — also highlights the destination square. Button is disabled (greyed out) after Hint 2 is used.

Puzzle solution is exact-match only (no Stockfish cross-validation in v1).

---

## Data Persistence

| Data | Storage | Key(s) | When |
|---|---|---|---|
| Active game | SharedPreferences | `game.fen`, `game.history`, `game.playerColor`, `game.difficulty`, `game.status` | After every move |
| Puzzle solved state | SQLite `puzzles.solved` column | — | On puzzle completion |
| Puzzle count (for daily formula) | SharedPreferences | `puzzle.count` | On first launch after DB copy |
| Settings | SharedPreferences | `settings.boardTheme`, `settings.pieceSet`, `settings.sound`, `settings.legalHints`, `settings.coordinates` | On change |

**Saved game fields (SharedPreferences keys):**
- `game.fen` — current FEN string
- `game.history` — JSON array of UCI move strings (e.g. `["e2e4","e7e5"]`)
- `game.playerColor` — `"white"` or `"black"`
- `game.difficulty` — enum name string (e.g. `"medium"`)
- `game.status` — enum name string (e.g. `"playing"`)

On restore, `GameRepository` reconstructs the `chess.Chess` state by replaying the stored UCI history moves from the standard chess starting position (`rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1`). Custom starting positions are not supported in v1.

**Game restore behavior:** On app launch, if `game.status == "playing"` is found in SharedPreferences, the app navigates directly to `/game/play` with the restored state (bypassing Home and Difficulty Setup). If no saved game exists, or the saved game status is not `"playing"`, Home is shown.

**Starting a new game:** If a game is in progress and the user navigates to Difficulty Setup and confirms, the existing saved game is silently overwritten — no confirmation prompt in v1.

**Corrupt game state on restore:** If any `game.*` SharedPreferences key fails to parse (invalid JSON, unknown enum value, etc.), all `game.*` keys are cleared and the app shows Home. The failure is silent to the user — they simply start fresh.

**Puzzle solved storage:** Solved state is stored as a boolean column directly in the SQLite `puzzles` table (`solved INTEGER DEFAULT 0`). This avoids `SharedPreferences` holding a potentially large set and keeps all puzzle data in one place. Maximum storage overhead: 50k rows × ~1 byte = negligible.

---

## Error Handling

**Stockfish initialization failure at cold start** — If Stockfish fails to initialize on app start (FFI load failure), the "Play vs AI" button on Home is replaced with a disabled state showing "Engine unavailable." The Puzzles section still works. No crash — the failure is caught and surfaced as UI state.

**Stockfish crash during game** — `StockfishService` wraps engine calls in try/catch. On failure, it disposes and reinitializes the engine, then retries the request once. If the retry fails, a snackbar shows "Engine unavailable — please try again."

**Stockfish timeout** — A 10-second timeout guards all `getBestMove` calls. On timeout, the same recovery flow as a crash.

**Stockfish during puzzle mode** — The engine is kept initialized but idle. No `go` commands are issued while the user is on puzzle screens. This avoids unnecessary battery and memory use while keeping initialization cost zero when the user returns to play vs AI.

**Puzzle DB copy failure** — If the one-time asset copy fails (e.g. disk full), Puzzles section is disabled with an inline message explaining why. Game vs AI still works. The copy has a 30-second timeout; if it exceeds this (hung I/O), the copy is cancelled, the partial file is deleted, and the same "Puzzles unavailable" state is shown. The app retries the copy on next launch.

**Puzzle DB missing or corrupt** — If `puzzles.db` is absent from the assets bundle (build misconfiguration) or the SQLite file is corrupt (fails to open), the app catches the exception on first query, logs the error, and disables the Puzzles section with a "Puzzles unavailable" message. This is treated identically to a copy failure from the user's perspective.

**Illegal moves** — Impossible at the UI layer. The `chess` package computes legal moves; the board only renders tappable destinations for valid moves.

---

## Out of Scope (v1)

- Pass-and-play multiplayer (v1.2)
- Game analysis / post-game Stockfish review
- Opening explorer
- Online play
- User accounts
- Cloud sync
- Ads, IAP, subscriptions, tracking
