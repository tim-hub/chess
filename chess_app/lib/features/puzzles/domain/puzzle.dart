/// Represents a single chess puzzle from the Lichess database.
class Puzzle {
  final String id;
  final String fen;          // Starting FEN (before setup move is applied)
  final List<String> moves;  // UCI moves: moves[0] = setup move, moves[1..] = solution
  final int rating;
  final List<String> themes;

  const Puzzle({
    required this.id,
    required this.fen,
    required this.moves,
    required this.rating,
    required this.themes,
  });

  factory Puzzle.fromMap(Map<String, dynamic> map) {
    return Puzzle(
      id: map['id'] as String,
      fen: map['fen'] as String,
      moves: (map['moves'] as String).split(' ').where((m) => m.isNotEmpty).toList(),
      rating: map['rating'] as int,
      themes: (map['themes'] as String).split(' ').where((t) => t.isNotEmpty).toList(),
    );
  }
}
