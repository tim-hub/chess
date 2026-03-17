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
