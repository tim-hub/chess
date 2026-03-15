enum DifficultyLevel {
  beginner,
  easy,
  medium,
  hard,
  expert,
  master;

  int get skillLevel => const {
        DifficultyLevel.beginner: 1,
        DifficultyLevel.easy: 4,
        DifficultyLevel.medium: 8,
        DifficultyLevel.hard: 12,
        DifficultyLevel.expert: 16,
        DifficultyLevel.master: 20,
      }[this]!;

  int get searchDepth => const {
        DifficultyLevel.beginner: 3,
        DifficultyLevel.easy: 5,
        DifficultyLevel.medium: 8,
        DifficultyLevel.hard: 10,
        DifficultyLevel.expert: 13,
        DifficultyLevel.master: 15,
      }[this]!;

  String get label => const {
        DifficultyLevel.beginner: 'Beginner',
        DifficultyLevel.easy: 'Easy',
        DifficultyLevel.medium: 'Medium',
        DifficultyLevel.hard: 'Hard',
        DifficultyLevel.expert: 'Expert',
        DifficultyLevel.master: 'Master',
      }[this]!;

  static DifficultyLevel fromName(String name) => DifficultyLevel.values
      .firstWhere((d) => d.name == name, orElse: () => DifficultyLevel.medium);
}

enum Side { white, black }

enum GameStatus { playing, checkmate, stalemate, draw }

class Move {
  final String uci; // e.g. "e2e4", "e7e8q"
  final String san; // e.g. "e4", "Nf3", "O-O", "e8=Q"

  const Move({required this.uci, required this.san});

  String get from => uci.substring(0, 2);
  String get to => uci.substring(2, 4);
  String? get promotion => uci.length == 5 ? uci[4] : null;

  @override
  bool operator ==(Object other) => other is Move && other.uci == uci;

  @override
  int get hashCode => uci.hashCode;

  @override
  String toString() => 'Move($uci / $san)';
}
