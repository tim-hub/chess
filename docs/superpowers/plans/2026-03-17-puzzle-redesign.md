# Puzzle Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the raw puzzle list with a themed chapter system, fix the hint highlight bug, and redesign the puzzle play screen with an inline solved banner.

**Architecture:** A static `PuzzleChapterRegistry` maps Lichess theme tags to chapters; `ChapterNotifier` (Riverpod `StateNotifier`) builds `PuzzleChapter` view models from the registry + `ChapterProgressRepository` (SharedPreferences). `PuzzleScreen` is redesigned to drive hint highlights from `PuzzleSession` state rather than ephemeral widget-local state.

**Tech Stack:** Flutter 3.x · Riverpod 2.x (`StateNotifier`) · go_router · SharedPreferences · sqflite (existing)

**Spec:** `docs/superpowers/specs/2026-03-17-puzzle-redesign.md`

---

## File Map

**New files:**
- `chess_app/lib/features/puzzles/domain/puzzle_chapter.dart` — `PuzzleChapter` view model
- `chess_app/lib/features/puzzles/domain/puzzle_chapter_registry.dart` — `ChapterDefinition`, `kChapterDefinitions`, `kTagToChapterId`
- `chess_app/lib/features/puzzles/domain/chapter_notifier.dart` — `ChapterNotifier` + `chapterNotifierProvider` + `chapterProgressRepositoryProvider`
- `chess_app/lib/features/puzzles/data/chapter_progress_repository.dart` — `ChapterProgressRepository`
- `chess_app/lib/features/puzzles/presentation/chapter_list_screen.dart` — `ChapterListScreen`

**New test files:**
- `chess_app/test/features/puzzles/domain/puzzle_chapter_test.dart`
- `chess_app/test/features/puzzles/domain/chapter_notifier_test.dart`
- `chess_app/test/features/puzzles/data/chapter_progress_repository_test.dart`

**Modified files:**
- `chess_app/lib/features/puzzles/domain/puzzle_session.dart` — add `hintFromSquare`/`hintToSquare` getters
- `chess_app/lib/features/puzzles/domain/puzzle_repository.dart` — add `getPuzzleIdsByThemeTags`
- `chess_app/lib/features/puzzles/data/puzzle_repository_impl.dart` — implement `getPuzzleIdsByThemeTags`
- `chess_app/lib/features/game/presentation/board/highlight_layer.dart` — add `hintFromSquare`/`hintToSquare` params
- `chess_app/lib/features/game/presentation/board/board_widget.dart` — pass hint params through to `HighlightLayer`
- `chess_app/lib/features/puzzles/presentation/puzzle_screen.dart` — full redesign (hint fix, AppBar, inline banner, credit model)
- `chess_app/lib/core/router/app_router.dart` — replace routes
- `chess_app/lib/features/puzzles/presentation/daily_puzzle_card.dart` — update navigation URL

**Modified test files:**
- `chess_app/test/features/puzzles/domain/puzzle_session_test.dart` — add hint getter tests

**Deleted files (remove at end of plan):**
- `chess_app/lib/features/puzzles/presentation/puzzle_list_screen.dart`
- `chess_app/lib/features/puzzles/presentation/puzzle_list_tile.dart`
- `chess_app/lib/features/puzzles/presentation/puzzle_filter_bar.dart`

---

## Chunk 1: Domain & Data Layer

### Task 1: PuzzleSession hint getters + PuzzleRepository extension

**Files:**
- Modify: `chess_app/lib/features/puzzles/domain/puzzle_session.dart`
- Modify: `chess_app/lib/features/puzzles/domain/puzzle_repository.dart`
- Modify: `chess_app/lib/features/puzzles/data/puzzle_repository_impl.dart`
- Modify: `chess_app/test/features/puzzles/domain/puzzle_session_test.dart`

- [ ] **Step 1: Add hint getter tests to `puzzle_session_test.dart`**

Add these tests inside `main()` after the existing tests:

```dart
test('hintFromSquare is null when hintCount is 0', () {
  final session = PuzzleSession(
    puzzle: testPuzzle,
    currentFen: 'some_fen',
    nextMoveIndex: 1,
    hintCount: 0,
  );
  expect(session.hintFromSquare, isNull);
  expect(session.hintToSquare, isNull);
});

test('hintFromSquare returns first 2 chars of expectedMove when hintCount >= 1', () {
  final session = PuzzleSession(
    puzzle: testPuzzle,
    currentFen: 'some_fen',
    nextMoveIndex: 1,
    hintCount: 1,
  );
  // testPuzzle moves[1] = 'e7e5'
  expect(session.hintFromSquare, 'e7');
  expect(session.hintToSquare, isNull); // only hintCount=2 reveals to-square
});

test('hintToSquare returns chars 2-4 of expectedMove when hintCount >= 2', () {
  final session = PuzzleSession(
    puzzle: testPuzzle,
    currentFen: 'some_fen',
    nextMoveIndex: 1,
    hintCount: 2,
  );
  expect(session.hintFromSquare, 'e7');
  expect(session.hintToSquare, 'e5');
});

test('hintFromSquare is null when expectedMove is null (puzzle complete)', () {
  final session = PuzzleSession(
    puzzle: testPuzzle,
    currentFen: 'some_fen',
    nextMoveIndex: 4, // past end
    hintCount: 2,
  );
  expect(session.hintFromSquare, isNull);
  expect(session.hintToSquare, isNull);
});
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd chess_app && flutter test test/features/puzzles/domain/puzzle_session_test.dart -v 2>&1 | tail -20
```
Expected: FAIL on the 4 new hint getter tests (no such getters yet).

- [ ] **Step 3: Add hint getters to `puzzle_session.dart`**

After the `isPlayerTurn` getter, add:

```dart
/// Square the hint is pointing from (e.g. 'e7'), or null if no hint active.
String? get hintFromSquare =>
    hintCount >= 1 && expectedMove != null ? expectedMove!.substring(0, 2) : null;

/// Square the hint is pointing to (e.g. 'e5'), or null if full hint not yet revealed.
String? get hintToSquare =>
    hintCount >= 2 && expectedMove != null ? expectedMove!.substring(2, 4) : null;
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd chess_app && flutter test test/features/puzzles/domain/puzzle_session_test.dart -v 2>&1 | tail -20
```
Expected: All 8 tests PASS.

- [ ] **Step 5: Add `getPuzzleIdsByThemeTags` to `puzzle_repository.dart`**

Add this method to the `PuzzleRepository` abstract class:

```dart
/// Returns puzzle IDs whose themes column contains any of the given [themeTags].
/// Uses space-padded LIKE matching against the themes column to correctly handle
/// camelCase tag strings (e.g. 'discoveredAttack', 'backRankMate') which are not
/// reliably tokenized by FTS5's default unicode61 tokenizer.
/// Returns at most [limit] results ordered by rating.
Future<List<String>> getPuzzleIdsByThemeTags(List<String> themeTags, {int limit = 50});
```

- [ ] **Step 6: Implement `getPuzzleIdsByThemeTags` in `puzzle_repository_impl.dart`**

Add this method inside `PuzzleRepositoryImpl`. We use `(' ' || themes || ' ') LIKE '% tag %'` to match whole-word tags regardless of their position (start, middle, or end of the themes string). This avoids FTS5 tokenization issues with camelCase tag names.

```dart
@override
Future<List<String>> getPuzzleIdsByThemeTags(
  List<String> themeTags, {
  int limit = 50,
}) async {
  if (themeTags.isEmpty) return [];
  final db = await _db;
  // Pad themes with spaces so every tag can be matched as ' tag ' regardless
  // of position. Avoids FTS5 tokenizer issues with camelCase tag names.
  final whereClauses = themeTags
      .map((_) => "(' ' || themes || ' ') LIKE ?")
      .join(' OR ');
  final args = <dynamic>[
    ...themeTags.map((tag) => '% $tag %'),
    limit,
  ];
  final rows = await db.rawQuery(
    'SELECT DISTINCT id FROM puzzles WHERE $whereClauses ORDER BY rating LIMIT ?',
    args,
  );
  return rows.map((r) => r['id'] as String).toList();
}
```

- [ ] **Step 7: Run full puzzle test suite to confirm nothing broke**

```bash
cd chess_app && flutter test test/features/puzzles/ -v 2>&1 | tail -30
```
Expected: All existing tests PASS. Note: `getPuzzleIdsByThemeTags` is tested against a real SQLite database indirectly via `puzzle_repository_impl_test.dart` if that file includes theme queries; otherwise the logic is exercised when the app runs with the real database.

- [ ] **Step 8: Commit**

```bash
cd chess_app && git add lib/features/puzzles/domain/puzzle_session.dart \
  lib/features/puzzles/domain/puzzle_repository.dart \
  lib/features/puzzles/data/puzzle_repository_impl.dart \
  test/features/puzzles/domain/puzzle_session_test.dart && \
git commit -m "feat(puzzles): add PuzzleSession hint getters and getPuzzleIdsByThemeTags"
```

---

### Task 2: ChapterProgressRepository

**Files:**
- Create: `chess_app/lib/features/puzzles/data/chapter_progress_repository.dart`
- Create: `chess_app/test/features/puzzles/data/chapter_progress_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `chess_app/test/features/puzzles/data/chapter_progress_repository_test.dart`:

```dart
import 'package:chess_app/features/puzzles/data/chapter_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getSolvedIds returns empty set for unknown chapter', () async {
    final repo = ChapterProgressRepository();
    final ids = await repo.getSolvedIds('forks');
    expect(ids, isEmpty);
  });

  test('markSolved persists puzzle ID and getSolvedIds returns it', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    final ids = await repo.getSolvedIds('forks');
    expect(ids, contains('puzzle001'));
  });

  test('markSolved is idempotent — duplicate marks do not inflate the set', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    await repo.markSolved('forks', 'puzzle001');
    final ids = await repo.getSolvedIds('forks');
    expect(ids.length, 1);
  });

  test('markSolved for different chapters are independent', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    await repo.markSolved('pins_and_skewers', 'puzzle002');
    expect(await repo.getSolvedIds('forks'), contains('puzzle001'));
    expect(await repo.getSolvedIds('forks'), isNot(contains('puzzle002')));
    expect(await repo.getSolvedIds('pins_and_skewers'), contains('puzzle002'));
  });

  test('multiple puzzles accumulate in same chapter', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    await repo.markSolved('forks', 'puzzle002');
    final ids = await repo.getSolvedIds('forks');
    expect(ids, containsAll(['puzzle001', 'puzzle002']));
    expect(ids.length, 2);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd chess_app && flutter test test/features/puzzles/data/chapter_progress_repository_test.dart -v 2>&1 | tail -20
```
Expected: FAIL (class not found).

- [ ] **Step 3: Create `chapter_progress_repository.dart`**

Create `chess_app/lib/features/puzzles/data/chapter_progress_repository.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class ChapterProgressRepository {
  static const String _prefix = 'chapter_solved_';

  Future<Set<String>> getSolvedIds(String chapterId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_prefix$chapterId') ?? [];
    return list.toSet();
  }

  Future<void> markSolved(String chapterId, String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$chapterId';
    final existing = prefs.getStringList(key) ?? [];
    if (!existing.contains(puzzleId)) {
      await prefs.setStringList(key, [...existing, puzzleId]);
    }
  }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd chess_app && flutter test test/features/puzzles/data/chapter_progress_repository_test.dart -v 2>&1 | tail -20
```
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
cd chess_app && git add lib/features/puzzles/data/chapter_progress_repository.dart \
  test/features/puzzles/data/chapter_progress_repository_test.dart && \
git commit -m "feat(puzzles): add ChapterProgressRepository with SharedPreferences persistence"
```

---

### Task 3: PuzzleChapterRegistry + PuzzleChapter model

**Files:**
- Create: `chess_app/lib/features/puzzles/domain/puzzle_chapter_registry.dart`
- Create: `chess_app/lib/features/puzzles/domain/puzzle_chapter.dart`
- Create: `chess_app/test/features/puzzles/domain/puzzle_chapter_test.dart`

- [ ] **Step 1: Write failing tests**

Create `chess_app/test/features/puzzles/domain/puzzle_chapter_test.dart`:

```dart
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PuzzleChapter.starCount', () {
    PuzzleChapter chapter({required int solved, required int total}) {
      return PuzzleChapter(
        id: 'test',
        name: 'Test',
        icon: '♟',
        puzzleIds: List.generate(total, (i) => 'p$i'),
        solvedCount: solved,
        isUnlocked: true,
      );
    }

    test('0 stars when solved < 50%', () {
      expect(chapter(solved: 4, total: 10).starCount, 0);
    });

    test('1 star when solved >= 50% and < 75%', () {
      expect(chapter(solved: 5, total: 10).starCount, 1);
      expect(chapter(solved: 7, total: 10).starCount, 1); // 70%, below 75%
    });

    test('2 stars when solved >= 75% and < 100%', () {
      expect(chapter(solved: 8, total: 10).starCount, 2); // 80%
      expect(chapter(solved: 9, total: 10).starCount, 2); // 90%
    });

    test('3 stars when all solved', () {
      expect(chapter(solved: 10, total: 10).starCount, 3);
    });

    test('0 stars when totalCount is 0', () {
      expect(chapter(solved: 0, total: 0).starCount, 0);
    });
  });

  group('PuzzleChapterRegistry', () {
    test('kChapterDefinitions has 9 chapters in correct order', () {
      expect(kChapterDefinitions.length, 9);
      expect(kChapterDefinitions.first.id, 'checkmate_in_1');
      expect(kChapterDefinitions.last.id, 'advanced_tactics');
    });

    test('kTagToChapterId maps fork to forks chapter', () {
      expect(kTagToChapterId['fork'], 'forks');
    });

    test('kTagToChapterId maps pin and skewer to same chapter', () {
      expect(kTagToChapterId['pin'], 'pins_and_skewers');
      expect(kTagToChapterId['skewer'], 'pins_and_skewers');
    });

    test('kTagToChapterId maps mateIn1 to checkmate_in_1', () {
      expect(kTagToChapterId['mateIn1'], 'checkmate_in_1');
    });

    test('every chapter definition has non-empty themeTags', () {
      for (final def in kChapterDefinitions) {
        expect(def.themeTags, isNotEmpty, reason: '${def.id} has no theme tags');
      }
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd chess_app && flutter test test/features/puzzles/domain/puzzle_chapter_test.dart -v 2>&1 | tail -20
```
Expected: FAIL (types not found).

- [ ] **Step 3: Create `puzzle_chapter.dart`**

Create `chess_app/lib/features/puzzles/domain/puzzle_chapter.dart`:

```dart
/// View model for a puzzle chapter. All counts are pre-computed by ChapterNotifier.
class PuzzleChapter {
  final String id;
  final String name;
  final String icon;           // emoji display character
  final List<String> puzzleIds;
  final int solvedCount;       // pre-computed by ChapterNotifier
  final bool isUnlocked;       // pre-computed: index==0 || prevChapter.starCount >= 1

  const PuzzleChapter({
    required this.id,
    required this.name,
    required this.icon,
    required this.puzzleIds,
    required this.solvedCount,
    required this.isUnlocked,
  });

  int get totalCount => puzzleIds.length;

  int get starCount {
    if (totalCount == 0) return 0;
    final pct = solvedCount / totalCount;
    if (pct >= 1.0) return 3;
    if (pct >= 0.75) return 2;
    if (pct >= 0.50) return 1;
    return 0;
  }
}
```

- [ ] **Step 4: Create `puzzle_chapter_registry.dart`**

Create `chess_app/lib/features/puzzles/domain/puzzle_chapter_registry.dart`:

```dart
/// Static definition of a single puzzle chapter (id, display data, theme tags).
class ChapterDefinition {
  final String id;
  final String name;
  final String icon;
  final List<String> themeTags; // Lichess tag strings that belong to this chapter
  final String statusVerb;     // Short verb shown in the puzzle play status bar, e.g. 'Find the fork'

  const ChapterDefinition({
    required this.id,
    required this.name,
    required this.icon,
    required this.themeTags,
    required this.statusVerb,
  });
}

/// The 9 themed chapters in display order.
const List<ChapterDefinition> kChapterDefinitions = [
  ChapterDefinition(
    id: 'checkmate_in_1',
    name: 'Checkmate in 1',
    icon: '♟',
    themeTags: ['mateIn1'],
    statusVerb: 'Deliver checkmate',
  ),
  ChapterDefinition(
    id: 'forks',
    name: 'Forks',
    icon: '⚔',
    themeTags: ['fork'],
    statusVerb: 'Find the fork',
  ),
  ChapterDefinition(
    id: 'pins_and_skewers',
    name: 'Pins & Skewers',
    icon: '📌',
    themeTags: ['pin', 'skewer'],
    statusVerb: 'Find the pin or skewer',
  ),
  ChapterDefinition(
    id: 'discovered_attacks',
    name: 'Discovered Attacks',
    icon: '💥',
    themeTags: ['discoveredAttack'],
    statusVerb: 'Find the discovered attack',
  ),
  ChapterDefinition(
    id: 'sacrifices',
    name: 'Sacrifices',
    icon: '🎯',
    themeTags: ['sacrifice'],
    statusVerb: 'Find the sacrifice',
  ),
  ChapterDefinition(
    id: 'back_rank_mates',
    name: 'Back Rank Mates',
    icon: '🏰',
    themeTags: ['backRankMate'],
    statusVerb: 'Find the back rank mate',
  ),
  ChapterDefinition(
    id: 'endgames',
    name: 'Endgames',
    icon: '♛',
    themeTags: ['endgame'],
    statusVerb: 'Find the best move',
  ),
  ChapterDefinition(
    id: 'checkmate_in_2_plus',
    name: 'Checkmate in 2+',
    icon: '♟♟',
    themeTags: ['mateIn2', 'mateIn3'],
    statusVerb: 'Find the mating sequence',
  ),
  ChapterDefinition(
    id: 'advanced_tactics',
    name: 'Advanced Tactics',
    icon: '⚡',
    themeTags: ['attraction', 'deflection', 'clearance', 'interference', 'zugzwang', 'quietMove'],
    statusVerb: 'Find the winning tactic',
  ),
];

/// Maps a Lichess theme tag to the chapter ID it belongs to.
/// A puzzle is assigned to the chapter whose tag appears first in this map.
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
  'attraction': 'advanced_tactics',
  'deflection': 'advanced_tactics',
  'clearance': 'advanced_tactics',
  'interference': 'advanced_tactics',
  'zugzwang': 'advanced_tactics',
  'quietMove': 'advanced_tactics',
};
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
cd chess_app && flutter test test/features/puzzles/domain/puzzle_chapter_test.dart -v 2>&1 | tail -20
```
Expected: All 9 tests PASS.

- [ ] **Step 6: Commit**

```bash
cd chess_app && git add lib/features/puzzles/domain/puzzle_chapter.dart \
  lib/features/puzzles/domain/puzzle_chapter_registry.dart \
  test/features/puzzles/domain/puzzle_chapter_test.dart && \
git commit -m "feat(puzzles): add PuzzleChapter model and PuzzleChapterRegistry"
```

---

### Task 4: ChapterNotifier

**Files:**
- Create: `chess_app/lib/features/puzzles/domain/chapter_notifier.dart`
- Create: `chess_app/test/features/puzzles/domain/chapter_notifier_test.dart`

- [ ] **Step 1: Write failing tests**

Create `chess_app/test/features/puzzles/domain/chapter_notifier_test.dart`:

```dart
import 'package:chess_app/features/puzzles/data/chapter_progress_repository.dart';
import 'package:chess_app/features/puzzles/domain/chapter_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockPuzzleRepository extends Mock implements PuzzleRepository {}

void main() {
  late MockPuzzleRepository puzzleRepo;
  late ChapterProgressRepository progressRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    puzzleRepo = MockPuzzleRepository();
    progressRepo = ChapterProgressRepository();

    // Default: all theme tags return an empty list unless overridden
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(any(), limit: any(named: 'limit')))
        .thenAnswer((_) async => []);
  });

  test('load() builds 9 chapters', () async {
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.state.length, 9);
  });

  test('chapter 1 is always unlocked', () async {
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.state.first.isUnlocked, isTrue);
  });

  test('chapter 2 is locked when chapter 1 has 0 stars', () async {
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['mateIn1'], limit: any(named: 'limit')))
        .thenAnswer((_) async => ['p1', 'p2', 'p3', 'p4', 'p5']);
    // 0 solved → 0 stars → chapter 2 locked
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.state[1].isUnlocked, isFalse);
  });

  test('chapter 2 unlocks when chapter 1 earns 1 star (50% solved)', () async {
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['mateIn1'], limit: any(named: 'limit')))
        .thenAnswer((_) async => ['p1', 'p2', 'p3', 'p4']);
    // Pre-seed 2/4 solved = 50% = 1 star
    SharedPreferences.setMockInitialValues({
      'chapter_solved_checkmate_in_1': ['p1', 'p2'],
    });
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.state.first.starCount, 1);
    expect(notifier.state[1].isUnlocked, isTrue);
  });

  test('markSolved updates solvedCount reactively', () async {
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['mateIn1'], limit: any(named: 'limit')))
        .thenAnswer((_) async => ['p1', 'p2', 'p3', 'p4']);
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.state.first.solvedCount, 0);
    await notifier.markSolved('checkmate_in_1', 'p1');
    expect(notifier.state.first.solvedCount, 1);
  });

  test('isSolved returns false before marking, true after', () async {
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.isSolved('forks', 'puzzle01'), isFalse);
    await notifier.markSolved('forks', 'puzzle01');
    expect(notifier.isSolved('forks', 'puzzle01'), isTrue);
  });

  test('nextPuzzleId returns first unsolved puzzle', () async {
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['fork'], limit: any(named: 'limit')))
        .thenAnswer((_) async => ['p1', 'p2', 'p3']);
    SharedPreferences.setMockInitialValues({
      'chapter_solved_forks': ['p1'],
    });
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.nextPuzzleId('forks'), 'p2');
  });

  test('nextPuzzleId returns first puzzle when all solved (replay mode)', () async {
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['fork'], limit: any(named: 'limit')))
        .thenAnswer((_) async => ['p1', 'p2']);
    SharedPreferences.setMockInitialValues({
      'chapter_solved_forks': ['p1', 'p2'],
    });
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.nextPuzzleId('forks'), 'p1');
  });

  test('nextPuzzleId returns null for empty chapter', () async {
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    // All chapters are empty by default in this test (mock returns [])
    expect(notifier.nextPuzzleId('checkmate_in_1'), isNull);
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd chess_app && flutter test test/features/puzzles/domain/chapter_notifier_test.dart -v 2>&1 | tail -20
```
Expected: FAIL (class not found).

- [ ] **Step 3: Create `chapter_notifier.dart`**

Create `chess_app/lib/features/puzzles/domain/chapter_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/features/puzzles/data/chapter_progress_repository.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter_registry.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_repository.dart';

final chapterProgressRepositoryProvider = Provider<ChapterProgressRepository>(
  (_) => ChapterProgressRepository(),
);

final chapterNotifierProvider =
    StateNotifierProvider<ChapterNotifier, List<PuzzleChapter>>(
  (ref) => ChapterNotifier(
    ref.read(puzzleRepositoryProvider),
    ref.read(chapterProgressRepositoryProvider),
  ),
);

class ChapterNotifier extends StateNotifier<List<PuzzleChapter>> {
  final PuzzleRepository _puzzleRepo;
  final ChapterProgressRepository _progressRepo;

  // In-memory solved sets for synchronous isSolved() lookups.
  final Map<String, Set<String>> _solvedIds = {};

  ChapterNotifier(this._puzzleRepo, this._progressRepo) : super([]);

  /// Loads all 9 chapters from the registry and persisted progress.
  /// Call once on app start or when navigating to the chapter list.
  Future<void> load() async {
    final chapters = <PuzzleChapter>[];
    int prevStarCount = 0;

    for (int i = 0; i < kChapterDefinitions.length; i++) {
      final def = kChapterDefinitions[i];
      final puzzleIds = await _puzzleRepo.getPuzzleIdsByThemeTags(
        def.themeTags,
        limit: 50,
      );
      final solvedSet = await _progressRepo.getSolvedIds(def.id);
      _solvedIds[def.id] = solvedSet;

      final solvedCount = solvedSet.intersection(puzzleIds.toSet()).length;
      final isUnlocked = i == 0 || prevStarCount >= 1;

      final chapter = PuzzleChapter(
        id: def.id,
        name: def.name,
        icon: def.icon,
        puzzleIds: puzzleIds,
        solvedCount: solvedCount,
        isUnlocked: isUnlocked,
      );
      chapters.add(chapter);
      prevStarCount = chapter.starCount;
    }

    state = chapters;
  }

  /// Marks a puzzle as solved in the given chapter and rebuilds state.
  Future<void> markSolved(String chapterId, String puzzleId) async {
    await _progressRepo.markSolved(chapterId, puzzleId);
    _solvedIds[chapterId] = {...(_solvedIds[chapterId] ?? {}), puzzleId};
    _rebuildState();
  }

  /// Returns true if the puzzle has already been solved in this chapter.
  bool isSolved(String chapterId, String puzzleId) {
    return _solvedIds[chapterId]?.contains(puzzleId) ?? false;
  }

  /// Returns the next unsolved puzzle ID in the chapter, or the first puzzle
  /// if all are solved (replay mode). Returns null if the chapter is empty.
  String? nextPuzzleId(String chapterId) {
    PuzzleChapter? chapter;
    for (final c in state) {
      if (c.id == chapterId) { chapter = c; break; }
    }
    if (chapter == null || chapter.puzzleIds.isEmpty) return null;
    final solved = _solvedIds[chapterId] ?? {};
    for (final id in chapter.puzzleIds) {
      if (!solved.contains(id)) return id;
    }
    return chapter.puzzleIds.first; // all solved — replay from first
  }

  void _rebuildState() {
    int prevStarCount = 0;
    state = state.asMap().entries.map((entry) {
      final i = entry.key;
      final ch = entry.value;
      final solvedSet = _solvedIds[ch.id] ?? {};
      final solvedCount = solvedSet.intersection(ch.puzzleIds.toSet()).length;
      final isUnlocked = i == 0 || prevStarCount >= 1;
      final updated = PuzzleChapter(
        id: ch.id,
        name: ch.name,
        icon: ch.icon,
        puzzleIds: ch.puzzleIds,
        solvedCount: solvedCount,
        isUnlocked: isUnlocked,
      );
      prevStarCount = updated.starCount;
      return updated;
    }).toList();
  }
}
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
cd chess_app && flutter test test/features/puzzles/domain/chapter_notifier_test.dart -v 2>&1 | tail -30
```
Expected: All 8 tests PASS.

- [ ] **Step 5: Run full test suite to confirm no regressions**

```bash
cd chess_app && flutter test 2>&1 | tail -10
```
Expected: All tests PASS (or same count as before this chunk).

- [ ] **Step 6: Commit**

```bash
cd chess_app && git add lib/features/puzzles/domain/chapter_notifier.dart \
  test/features/puzzles/domain/chapter_notifier_test.dart && \
git commit -m "feat(puzzles): add ChapterNotifier with load, markSolved, isSolved, nextPuzzleId"
```

---

## Chunk 2: Presentation Layer

### Task 5: BoardWidget hint highlight support

**Files:**
- Modify: `chess_app/lib/features/game/presentation/board/highlight_layer.dart`
- Modify: `chess_app/lib/features/game/presentation/board/board_widget.dart`

Note: `AppColors.hintPiece` and `AppColors.hintDestination` already exist in `app_colors.dart` (Color(0x99FFD700)). No changes to AppColors needed.

- [ ] **Step 1: Add `hintFromSquare` and `hintToSquare` to `highlight_layer.dart`**

Two separate edits:

**Edit A** — add the two new field declarations directly after the existing `final Move? lastMove;` field (before the constructor). The current `highlight_layer.dart` has these fields at lines 8-10:
```dart
  final String? selectedSquare;
  final List<String> legalMoves; // UCI strings
  final Move? lastMove;
```

Add after `final Move? lastMove;`:
```dart
  /// If set, renders the hint from-square with [AppColors.hintPiece] color.
  final String? hintFromSquare;
  /// If set, renders the hint to-square with [AppColors.hintDestination] color.
  final String? hintToSquare;
```

**Edit B** — replace the constructor signature only (no field declarations inside it):
```dart
  const HighlightLayer({
    super.key,
    required this.squareSize,
    required this.flipped,
    required this.selectedSquare,
    required this.legalMoves,
    required this.lastMove,
    this.hintFromSquare,
    this.hintToSquare,
  });
```

Then update `build()` to render hint highlights **before** selection highlights so piece-selection takes visual priority:

Replace the `build()` method body's Stack children with:
```dart
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Last move highlight
        if (lastMove != null) ...[
          _highlight(lastMove!.from, AppColors.lastMoveHighlight),
          _highlight(lastMove!.to, AppColors.lastMoveHighlight),
        ],
        // Hint highlights (drawn before selection so piece-selection takes priority)
        if (hintFromSquare != null)
          _highlight(hintFromSquare!, AppColors.hintPiece),
        if (hintToSquare != null)
          _highlight(hintToSquare!, AppColors.hintDestination),
        // Selected square (drawn on top of hint highlights)
        if (selectedSquare != null)
          _highlight(selectedSquare!, AppColors.selectedSquare),
        // Legal move dots
        ...legalMoves.map((uci) => _dot(uci.substring(2, 4))),
      ],
    );
  }
```

- [ ] **Step 2: Add `hintFromSquare` / `hintToSquare` to `board_widget.dart`**

In `board_widget.dart`, add optional fields to `BoardWidget`:

After `final String? hidePieceOnSquare;`, add:
```dart
  final String? hintFromSquare;
  final String? hintToSquare;
```

Update the constructor to include them:
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
    this.hidePieceOnSquare,
    this.hintFromSquare,
    this.hintToSquare,
  });
```

Update the `HighlightLayer` instantiation in `build()` to pass them through:
```dart
              HighlightLayer(
                squareSize: squareSize,
                flipped: flipped,
                selectedSquare: selectedSquare,
                legalMoves: legalMoves,
                lastMove: lastMove,
                hintFromSquare: hintFromSquare,
                hintToSquare: hintToSquare,
              ),
```

- [ ] **Step 3: Run game feature tests and full test suite**

```bash
cd chess_app && flutter test test/features/game/ -v 2>&1 | tail -20
cd chess_app && flutter test 2>&1 | tail -10
```
Expected: All tests PASS (new params are optional with null defaults, so existing tests are unaffected).

- [ ] **Step 4: Commit**

```bash
cd chess_app && git add lib/features/game/presentation/board/highlight_layer.dart \
  lib/features/game/presentation/board/board_widget.dart && \
git commit -m "feat(board): add optional hintFromSquare/hintToSquare params to BoardWidget and HighlightLayer"
```

---

### Task 6: ChapterListScreen + routing

**Files:**
- Create: `chess_app/lib/features/puzzles/presentation/chapter_list_screen.dart`
- Modify: `chess_app/lib/core/router/app_router.dart`
- Modify: `chess_app/lib/features/puzzles/presentation/daily_puzzle_card.dart`

- [ ] **Step 1: Create `chapter_list_screen.dart`**

Create `chess_app/lib/features/puzzles/presentation/chapter_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/puzzles/domain/chapter_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';

class ChapterListScreen extends ConsumerStatefulWidget {
  const ChapterListScreen({super.key});

  @override
  ConsumerState<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends ConsumerState<ChapterListScreen> {
  @override
  void initState() {
    super.initState();
    // Load chapters once when the screen is first created.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chapterNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(chapterNotifierProvider);
    final credits = ref.watch(creditsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Puzzles'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
              label: Text(
                '$credits',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              backgroundColor: const Color(0xFFFEF3C7),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: chapters.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: chapters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final prevChapterName =
                    index > 0 ? chapters[index - 1].name : null;
                return _ChapterCard(
                  chapter: chapter,
                  prevChapterName: prevChapterName,
                  onTap: () => _onChapterTap(chapter, index),
                );
              },
            ),
    );
  }

  void _onChapterTap(PuzzleChapter chapter, int index) {
    if (!chapter.isUnlocked) {
      final chapters = ref.read(chapterNotifierProvider);
      final prevName = index > 0 ? chapters[index - 1].name : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prevName != null
                ? 'Earn 1★ in $prevName to unlock'
                : 'Complete previous chapter to unlock',
          ),
        ),
      );
      return;
    }

    final notifier = ref.read(chapterNotifierProvider.notifier);
    final puzzleId = notifier.nextPuzzleId(chapter.id);
    if (puzzleId == null) return;

    context.push(
      '/puzzles/play/$puzzleId',
      extra: {'chapterId': chapter.id},
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final PuzzleChapter chapter;
  final String? prevChapterName;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.chapter,
    required this.prevChapterName,
    required this.onTap,
  });

  Color get _borderColor {
    if (!chapter.isUnlocked) return const Color(0xFF334155);
    if (chapter.starCount == 3) return AppColors.successGreen;
    if (chapter.solvedCount > 0) return const Color(0xFF3B82F6);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = !chapter.isUnlocked;

    return Opacity(
      opacity: isLocked ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: _borderColor, width: 4)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(chapter.icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chapter.name,
                            style: TextStyle(
                              color: isLocked
                                  ? const Color(0xFF64748B)
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isLocked) _StarRow(starCount: chapter.starCount),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!isLocked) ...[
                      LinearProgressIndicator(
                        value: chapter.totalCount == 0
                            ? 0
                            : chapter.solvedCount / chapter.totalCount,
                        backgroundColor: const Color(0xFF0F172A),
                        color: _borderColor,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitleText(),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ] else ...[
                      Text(
                        prevChapterName != null
                            ? 'Earn 1★ in $prevChapterName to unlock'
                            : 'Locked',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleText() {
    if (chapter.totalCount == 0) return '0 / 0 solved';
    if (chapter.starCount == 3) {
      return '${chapter.solvedCount} / ${chapter.totalCount} solved';
    }
    final nextStar = chapter.starCount + 1;
    final threshold = nextStar == 1 ? 0.50 : nextStar == 2 ? 0.75 : 1.0;
    final needed = (threshold * chapter.totalCount).ceil();
    if (chapter.solvedCount > 0) {
      return '${chapter.solvedCount} / ${chapter.totalCount} solved · ${nextStar}★ at $needed';
    }
    return '0 / ${chapter.totalCount} solved · unlocked';
  }
}

class _StarRow extends StatelessWidget {
  final int starCount;

  const _StarRow({required this.starCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: i < starCount
              ? const Color(0xFFFBBF24)
              : const Color(0xFF334155),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update `app_router.dart`**

Replace the full content of `chess_app/lib/core/router/app_router.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/features/home/presentation/home_screen.dart';
import 'package:chess_app/features/game/presentation/difficulty_setup_screen.dart';
import 'package:chess_app/features/game/presentation/game_screen.dart';
import 'package:chess_app/features/puzzles/presentation/chapter_list_screen.dart';
import 'package:chess_app/features/puzzles/presentation/puzzle_screen.dart';
import 'package:chess_app/features/settings/presentation/settings_screen.dart';
import 'package:chess_app/features/stats/presentation/stats_screen.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/game/setup',
        builder: (context, state) => const DifficultySetupScreen(),
      ),
      GoRoute(
        path: '/game/play',
        redirect: (context, state) {
          final gameState = ref.read(gameNotifierProvider);
          if (gameState == null) return '/game/setup';
          return null;
        },
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: '/puzzles',
        builder: (context, state) => const ChapterListScreen(),
      ),
      GoRoute(
        path: '/puzzles/play/:id',
        builder: (context, state) {
          final puzzleId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          final chapterId = extra?['chapterId'] as String?;
          return PuzzleScreen(puzzleId: puzzleId, chapterId: chapterId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const StatsScreen(),
      ),
    ],
  );
});
```

- [ ] **Step 3: Update `daily_puzzle_card.dart` navigation URL**

In `chess_app/lib/features/puzzles/presentation/daily_puzzle_card.dart`, change:
```dart
onTap: () => context.push('/puzzles/${puzzle!.id}'),
```
to:
```dart
onTap: () => context.push('/puzzles/play/${puzzle!.id}'),
```

- [ ] **Step 4: Build the app to confirm no compile errors**

```bash
cd chess_app && flutter build apk --debug 2>&1 | tail -20
```
Expected: Build succeeds.

- [ ] **Step 5: Run full test suite**

```bash
cd chess_app && flutter test 2>&1 | tail -10
```
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
cd chess_app && git add lib/features/puzzles/presentation/chapter_list_screen.dart \
  lib/core/router/app_router.dart \
  lib/features/puzzles/presentation/daily_puzzle_card.dart && \
git commit -m "feat(puzzles): add ChapterListScreen and update routing to /puzzles/play/:id"
```

---

### Task 7: PuzzleScreen redesign

**Files:**
- Modify: `chess_app/lib/features/puzzles/presentation/puzzle_screen.dart`

This is the largest change. It touches:
1. Add `chapterId` constructor param
2. Remove `_hintUsed` local state (replaced by `session.hintCount`)
3. Update `_useHint()` — remove credit deduction, clear widget-local state
4. Redesign `_onPuzzleSolved()` — deferred credits, chapter progress, replay guard
5. Replace `_showSolvedBanner()` / `_SolvedSheet` modal with inline `_SolvedBanner` widget
6. Update `build()` — AppBar title, inline board hint squares, two-level hint button, status bar
7. Remove `_loadNext()` reliance on `loadNextPuzzle()`; in chapter mode navigate to chapter's next puzzle

- [ ] **Step 1: Replace `puzzle_screen.dart` with the redesigned version**

Overwrite `chess_app/lib/features/puzzles/presentation/puzzle_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/presentation/board/board_widget.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/puzzles/domain/chapter_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter_registry.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_session.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final String puzzleId;

  /// When navigating from ChapterListScreen, this is the chapter the puzzle
  /// belongs to. Null when opened outside chapter context (e.g. daily puzzle).
  final String? chapterId;

  const PuzzleScreen({
    super.key,
    required this.puzzleId,
    this.chapterId,
  });

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  String? _selectedSquare;
  List<String> _legalMovesFromSelected = [];
  bool _solvedShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(puzzleNotifierProvider.notifier).loadPuzzle(widget.puzzleId);
    });
  }

  Map<String, String> _parseFen(String fen) {
    final position = <String, String>{};
    final board = fen.split(' ')[0];
    final ranks = board.split('/');
    for (var rankIdx = 0; rankIdx < 8; rankIdx++) {
      final rank = ranks[rankIdx];
      var fileIdx = 0;
      for (final char in rank.split('')) {
        if (int.tryParse(char) != null) {
          fileIdx += int.parse(char);
        } else {
          final square =
              '${String.fromCharCode('a'.codeUnitAt(0) + fileIdx)}${8 - rankIdx}';
          position[square] = char;
          fileIdx++;
        }
      }
    }
    return position;
  }

  void _onSquareTap(String square) {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null || !session.isPlayerTurn || session.isComplete) return;

    final gameRepo = ref.read(gameRepositoryProvider);
    final position = _parseFen(session.currentFen);

    if (_selectedSquare == null) {
      final piece = position[square];
      if (piece == null) return;

      final activeColor = session.currentFen.split(' ')[1];
      final isWhitePiece = piece == piece.toUpperCase();
      final isPlayerPiece = (activeColor == 'w') == isWhitePiece;
      if (!isPlayerPiece) return;

      final legalResult = gameRepo.loadPosition(session.currentFen);
      final movesFromSquare =
          legalResult.legalMoves.where((m) => m.startsWith(square)).toList();

      setState(() {
        _selectedSquare = square;
        _legalMovesFromSelected = movesFromSquare;
      });
    } else {
      final uciMove = '$_selectedSquare$square';
      setState(() {
        _selectedSquare = null;
        _legalMovesFromSelected = [];
      });
      ref.read(puzzleNotifierProvider.notifier).submitMove(uciMove);
    }
  }

  /// Increment hint level. Clears widget-local selection so hint highlights
  /// are not immediately masked by piece-selection state.
  void _useHint() {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null || session.hintCount >= 2 || session.expectedMove == null) return;

    setState(() {
      _selectedSquare = null;
      _legalMovesFromSelected = [];
    });
    ref.read(puzzleNotifierProvider.notifier).useHint();
  }

  Future<void> _onPuzzleSolved() async {
    // Set synchronously before any await to prevent double-fire via
    // addPostFrameCallback (which may be called again before this async
    // method completes its first await).
    if (_solvedShown) return;
    setState(() { _solvedShown = true; });

    final session = ref.read(puzzleNotifierProvider);
    if (session == null) return;

    ref.read(audioServiceProvider).playSuccess();

    final chapterId = widget.chapterId;
    final puzzleId = session.puzzle.id;

    // Only award credits on first-time solve
    final alreadySolved = chapterId != null &&
        ref.read(chapterNotifierProvider.notifier).isSolved(chapterId, puzzleId);

    if (!alreadySolved) {
      final earned = (10 - session.hintCount).clamp(0, 10);
      ref.read(creditsProvider.notifier).add(earned);
    }

    // Update chapter progress (idempotent)
    if (chapterId != null) {
      await ref
          .read(chapterNotifierProvider.notifier)
          .markSolved(chapterId, puzzleId);
    }
  }

  void _loadNext() {
    setState(() {
      _solvedShown = false;
      _selectedSquare = null;
      _legalMovesFromSelected = [];
    });

    final chapterId = widget.chapterId;
    if (chapterId != null) {
      final notifier = ref.read(chapterNotifierProvider.notifier);
      final nextId = notifier.nextPuzzleId(chapterId);
      if (nextId != null) {
        ref.read(puzzleNotifierProvider.notifier).loadPuzzle(nextId);
      } else {
        context.pop();
      }
    } else {
      ref.read(puzzleNotifierProvider.notifier).loadNextPuzzle();
    }
  }

  String _buildTitle(PuzzleSession session, List<PuzzleChapter> chapters) {
    if (widget.chapterId == null) return 'Puzzle ${session.puzzle.id}';
    PuzzleChapter? chapter;
    for (final c in chapters) {
      if (c.id == widget.chapterId) { chapter = c; break; }
    }
    if (chapter == null) return 'Puzzle ${session.puzzle.id}';
    final idx = chapter.puzzleIds.indexOf(session.puzzle.id);
    final displayIdx = idx == -1 ? '?' : '${idx + 1}';
    return '${chapter.name} · #$displayIdx';
  }

  String _statusVerb() {
    if (widget.chapterId == null) return 'Find the best move';
    for (final def in kChapterDefinitions) {
      if (def.id == widget.chapterId) return def.statusVerb;
    }
    return 'Find the best move';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(puzzleNotifierProvider);
    final chapters = ref.watch(chapterNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final credits = ref.watch(creditsProvider);

    ref.listen<PuzzleSession?>(puzzleNotifierProvider, (prev, next) {
      if (prev == null || next == null) return;
      final audio = ref.read(audioServiceProvider);

      if (prev.isPlayerTurn &&
          !next.isFailed &&
          !next.isComplete &&
          next.currentFen != prev.currentFen) {
        audio.playMove();
        return;
      }

      if (!prev.isFailed && next.isFailed) {
        audio.playWrong();
        return;
      }
    });

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Puzzle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isComplete && !_solvedShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPuzzleSolved();
      });
    }

    final position = _parseFen(session.currentFen);
    final activeColor = session.currentFen.split(' ')[1];
    final flipped = activeColor == 'b';

    final earned = (10 - session.hintCount).clamp(0, 10);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_buildTitle(session, chapters)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
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
        ],
      ),
      body: Column(
        children: [
          // Status bar
          SizedBox(
            height: 52,
            child: Center(
              child: session.isFailed
                  ? _StatusBar(
                      text: '✗ Not the right move — try again',
                      color: AppColors.errorRed,
                    )
                  : _StatusBar(
                      text: 'Your turn · ${_statusVerb()}',
                      color: AppColors.textSecondary,
                      dot: true,
                    ),
            ),
          ),

          // Board
          Expanded(
            child: BoardWidget(
              flipped: flipped,
              pieceSet: settings.pieceSet,
              boardTheme: settings.boardTheme,
              position: position,
              legalMoves: _legalMovesFromSelected,
              selectedSquare: _selectedSquare,
              lastMove: null,
              hintFromSquare: session.hintFromSquare,
              hintToSquare: session.hintToSquare,
              onSquareTap: _onSquareTap,
            ),
          ),

          // Bottom area: solved banner OR bottom controls
          if (_solvedShown)
            _SolvedBanner(
              earned: earned,
              hintCount: session.hintCount,
              onNext: _loadNext,
            )
          else
            _BottomControls(
              session: session,
              onHint: _useHint,
              onReset: () {
                setState(() {
                  _solvedShown = false;
                  _selectedSquare = null;
                  _legalMovesFromSelected = [];
                });
                ref.read(puzzleNotifierProvider.notifier).resetPuzzle();
              },
            ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final String text;
  final Color color;
  final bool dot;

  const _StatusBar({required this.text, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (dot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  final PuzzleSession session;
  final VoidCallback onHint;
  final VoidCallback onReset;

  const _BottomControls({
    required this.session,
    required this.onHint,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final hintCount = session.hintCount;
    final String hintLabel;
    final bool hintEnabled;
    if (hintCount == 0) {
      hintLabel = '💡 Hint';
      hintEnabled = !session.isComplete;
    } else if (hintCount == 1) {
      hintLabel = '💡 Show full move';
      hintEnabled = !session.isComplete;
    } else {
      hintLabel = '💡 Full hint shown';
      hintEnabled = false;
    }

    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hintEnabled ? onHint : null,
                icon: Icon(
                  hintCount > 0
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                ),
                label: Text(hintLabel),
              ),
            ),
            if (session.isFailed) ...[
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent),
                onPressed: onReset,
                child: const Text('↺ Reset'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SolvedBanner extends StatefulWidget {
  final int earned;
  final int hintCount;
  final VoidCallback onNext;

  const _SolvedBanner({
    required this.earned,
    required this.hintCount,
    required this.onNext,
  });

  @override
  State<_SolvedBanner> createState() => _SolvedBannerState();
}

class _SolvedBannerState extends State<_SolvedBanner> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hintNote = widget.hintCount > 0
        ? ' (${widget.hintCount} hint${widget.hintCount > 1 ? 's' : ''} used)'
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14532D), Color(0xFF166534)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4ADE80), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '✓ Solved!',
                  style: TextStyle(
                    color: Color(0xFF4ADE80),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '+${widget.earned} ⭐$hintNote',
                  style: const TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF166534)),
            onPressed: widget.onNext,
            child: const Text(
              'Next →',
              style: TextStyle(color: Color(0xFF4ADE80)),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Build the app to confirm it compiles**

```bash
cd chess_app && flutter build apk --debug 2>&1 | tail -20
```
Expected: Build succeeds. No compile errors.

- [ ] **Step 3: Run the existing puzzle notifier and session tests**

```bash
cd chess_app && flutter test test/features/puzzles/ -v 2>&1 | tail -30
```
Expected: All tests PASS. The PuzzleScreen redesign has no unit tests (it's a widget), but the underlying domain logic is fully tested.

- [ ] **Step 4: Run full test suite**

```bash
cd chess_app && flutter test 2>&1 | tail -10
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
cd chess_app && git add lib/features/puzzles/presentation/puzzle_screen.dart && \
git commit -m "feat(puzzles): redesign PuzzleScreen with inline hint fix, solved banner, chapter context"
```

---

### Task 8: Clean up deprecated files

**Files:**
- Delete: `chess_app/lib/features/puzzles/presentation/puzzle_list_screen.dart`
- Delete: `chess_app/lib/features/puzzles/presentation/puzzle_list_tile.dart`
- Delete: `chess_app/lib/features/puzzles/presentation/puzzle_filter_bar.dart`

- [ ] **Step 1: Confirm no remaining imports of deleted files**

```bash
cd chess_app && grep -r "puzzle_list_screen\|puzzle_list_tile\|puzzle_filter_bar" lib/ test/
```
Expected: No matches (router was already updated in Task 6).

- [ ] **Step 2: Delete the files**

```bash
cd chess_app && rm lib/features/puzzles/presentation/puzzle_list_screen.dart \
  lib/features/puzzles/presentation/puzzle_list_tile.dart \
  lib/features/puzzles/presentation/puzzle_filter_bar.dart
```

- [ ] **Step 3: Build and test to confirm nothing broke**

```bash
cd chess_app && flutter build apk --debug 2>&1 | tail -10
cd chess_app && flutter test 2>&1 | tail -10
```
Expected: Build succeeds. All tests PASS.

- [ ] **Step 4: Commit**

```bash
cd chess_app && git add -A && \
git commit -m "chore(puzzles): remove deprecated puzzle_list_screen, puzzle_list_tile, puzzle_filter_bar"
```

---

## Final Verification

- [ ] Run complete test suite one last time

```bash
cd chess_app && flutter test -v 2>&1 | grep -E "PASS|FAIL|error" | tail -20
```

- [ ] Verify success criteria from spec:
  - [ ] Hint highlights survive board taps (session.hintFromSquare drives renders)
  - [ ] Piece selection and hint highlights coexist (selection overlays hints; hints re-appear on deselect)
  - [ ] Chapter list shows 9 chapters with progress and lock state
  - [ ] Stars update as puzzles are solved
  - [ ] Solve reward reduced by 1 per hint level (no upfront deduction)
  - [ ] Solved banner is inline (no modal)
  - [ ] AppBar shows chapter name + puzzle number when in chapter context
