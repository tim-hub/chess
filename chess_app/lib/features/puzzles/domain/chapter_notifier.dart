import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/features/puzzles/data/chapter_progress_repository.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter_registry.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_repository.dart';

/// Minimum star rating in a chapter required to unlock the next chapter.
const int kMinStarsToUnlock = 1;

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
      final isUnlocked = true; // all chapters accessible from the start

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
  /// Updates the in-memory set synchronously before persisting so that
  /// [nextPuzzleId] immediately skips the just-solved puzzle even if called
  /// before the async persist completes.
  Future<void> markSolved(String chapterId, String puzzleId) async {
    _solvedIds[chapterId] = {...(_solvedIds[chapterId] ?? {}), puzzleId};
    _rebuildState();
    await _progressRepo.markSolved(chapterId, puzzleId);
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
      final isUnlocked = true; // all chapters accessible from the start
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
