/// Filter criteria for puzzle list queries.
class PuzzleFilter {
  final String? theme;
  final int minRating;
  final int maxRating;

  const PuzzleFilter({
    this.theme,
    this.minRating = 800,
    this.maxRating = 2800,
  });

  PuzzleFilter copyWith({
    Object? theme = _sentinel,
    int? minRating,
    int? maxRating,
  }) => PuzzleFilter(
    theme: theme == _sentinel ? this.theme : theme as String?,
    minRating: minRating ?? this.minRating,
    maxRating: maxRating ?? this.maxRating,
  );

  static const _sentinel = Object();
}

/// Lichess puzzle themes available for filtering.
const kPuzzleThemes = [
  'mateIn1', 'mateIn2', 'mateIn3', 'mateIn4',
  'advantage', 'crushing', 'equality',
  'fork', 'pin', 'skewer', 'discoveredAttack',
  'sacrifice', 'deflection', 'attraction',
  'endgame', 'middlegame', 'opening',
  'backRankMate', 'arabianMate', 'master',
];
