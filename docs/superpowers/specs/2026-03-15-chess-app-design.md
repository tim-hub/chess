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
| Chess rules engine | `chess` pub.dev package — move validation, FEN/PGN, legal move generation |
| AI engine | Stockfish via `stockfish_flutter` Flutter package (FFI, runs on-device) |
| State management | Riverpod |
| Navigation | go_router |
| Local storage | `sqflite` for puzzle database, `shared_preferences` for settings & game state |
| Puzzle source | Lichess open puzzle database (~50k puzzles, bundled as SQLite) |
| Piece graphics | Lichess open-source SVG piece sets (CBurnett or Merida) |

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

**Game (`/game/play`)** — Interactive chess board, move history panel, captured pieces display, Resign and Draw offer buttons. Game-over bottom sheet on checkmate/stalemate/draw.

**Puzzles (`/puzzles`)** — Filter by theme (fork, pin, skewer, back-rank mate, etc.) and rating range. "Daily Puzzle" entry (deterministic by date seed). Progress counter (solved / total).

**Puzzle (`/puzzles/:id`)** — Chess board in puzzle position, "Find the best move" prompt, Hint button (2 hints: piece highlight → destination highlight), move feedback (success animation or shake on wrong), Next Puzzle button on completion.

**Settings (`/settings`)** — Board theme toggle, piece set toggle, sound on/off, legal move hints on/off.

---

## Key Components

### ChessEngine (abstract interface)

```dart
abstract class ChessEngine {
  Future<Move> getBestMove(String fen, DifficultyLevel difficulty);
  Stream<String> get analysisStream;
  void dispose();
}
```

`StockfishService` implements this interface, translating `DifficultyLevel` to UCI `setoption name Skill Level value N` and `go depth N` commands. The engine is initialized once at app start and kept alive for the session.

### GameState (Riverpod StateNotifier)

```dart
class GameState {
  final chess.Chess board;       // chess package — all rule enforcement
  final List<Move> history;
  final Side playerColor;
  final DifficultyLevel difficulty;
  final GameStatus status;       // playing | checkmate | stalemate | draw
}
```

### BoardWidget

```
BoardWidget
├── SquareWidget × 64        # tap-to-select / tap-to-move
├── PieceWidget              # SVG piece, animates on move (200ms slide)
├── HighlightLayer           # last move (yellow tint), legal move dots, check (red tint)
└── CoordinateLabels         # a–h, 1–8 (toggleable)
```

Legal moves are shown as dots on valid destination squares after selecting a piece. Only tappable squares are valid destinations — illegal moves are impossible at the UI layer.

### Puzzle Database Schema

```sql
CREATE TABLE puzzles (
  id          TEXT PRIMARY KEY,   -- Lichess puzzle ID
  fen         TEXT NOT NULL,       -- starting FEN position
  moves       TEXT NOT NULL,       -- full solution in UCI, space-separated
  rating      INTEGER,             -- Lichess rating (600–2800)
  themes      TEXT,                -- space-separated theme tags
  popularity  INTEGER
);

CREATE INDEX idx_rating  ON puzzles(rating);
CREATE INDEX idx_themes  ON puzzles(themes);
```

On first launch, `puzzles.db` is copied from Flutter assets to the app's documents directory (required by sqflite). A loading screen is shown during this one-time copy (~2s on average hardware).

### Puzzle Mechanic

Each puzzle has a fixed solution sequence from the Lichess database. The flow:

1. Position loads — user is told which side to move
2. User taps a piece, taps a destination
3. App checks if the move matches the next expected UCI move in the solution
   - **Correct** → opponent's response plays automatically (300ms delay for realism), user continues
   - **Wrong** → board shakes, "Not the best move — try again" toast
4. Continues until all moves in the solution are complete → success screen with rating and themes
5. **Hint 1** — highlights the piece that needs to move
   **Hint 2** — also highlights the destination square

Puzzle solution is exact-match only (no Stockfish cross-validation in v1).

---

## Data Persistence

| Data | Storage | When |
|---|---|---|
| Active game (FEN + history) | SharedPreferences | After every move |
| Puzzle progress (solved IDs) | SharedPreferences (Set<String>) | On puzzle completion |
| Settings | SharedPreferences | On change |

Game state is restored on next app launch. If no saved game exists, Home is shown.

---

## Error Handling

**Stockfish crash** — `StockfishService` wraps engine calls in try/catch. On failure, it disposes and reinitializes the engine, then retries the request once. If the retry fails, a snackbar shows "Engine unavailable — please try again."

**Stockfish timeout** — A 10-second timeout guards all `getBestMove` calls. On timeout, the same recovery flow as a crash.

**Puzzle DB copy failure** — If the one-time asset copy fails (e.g. disk full), Puzzles section is disabled and a message explains why. Game vs AI still works.

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
