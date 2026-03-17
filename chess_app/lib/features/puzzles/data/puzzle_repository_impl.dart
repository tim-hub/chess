import 'package:sqflite/sqflite.dart';
import '../domain/puzzle.dart';
import '../domain/puzzle_filter.dart';
import '../domain/puzzle_repository.dart';
import 'puzzle_database.dart';

class PuzzleRepositoryImpl implements PuzzleRepository {
  Future<Database> get _db => PuzzleDatabase.getInstance();

  @override
  Future<List<Puzzle>> getPuzzles(
    PuzzleFilter filter, {
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await _db;

    if (filter.theme != null) {
      // FTS5 JOIN for theme filtering
      final rows = await db.rawQuery('''
        SELECT p.id, p.fen, p.moves, p.rating, p.themes
        FROM puzzles p
        JOIN puzzles_fts f ON p.id = f.id
        WHERE puzzles_fts MATCH ?
          AND p.rating BETWEEN ? AND ?
        ORDER BY p.rating
        LIMIT ? OFFSET ?
      ''', [filter.theme!, filter.minRating, filter.maxRating, limit, offset]);
      return rows.map(Puzzle.fromMap).toList();
    } else {
      final rows = await db.query(
        'puzzles',
        where: 'rating BETWEEN ? AND ?',
        whereArgs: [filter.minRating, filter.maxRating],
        orderBy: 'rating',
        limit: limit,
        offset: offset,
      );
      return rows.map(Puzzle.fromMap).toList();
    }
  }

  @override
  Future<Puzzle?> getDailyPuzzle() async {
    final db = await _db;
    final countResult = await db.rawQuery('SELECT COUNT(*) as n FROM puzzles');
    final count = countResult.first['n'] as int;
    if (count == 0) return null;

    final now = DateTime.now();
    final index = (now.year * 10000 + now.month * 100 + now.day) % count;

    final rows = await db.rawQuery(
      'SELECT id, fen, moves, rating, themes FROM puzzles LIMIT 1 OFFSET ?',
      [index],
    );
    if (rows.isEmpty) return null;
    return Puzzle.fromMap(rows.first);
  }

  @override
  Future<Puzzle?> getNextPuzzle(String excludeId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT id, fen, moves, rating, themes FROM puzzles WHERE id != ? ORDER BY RANDOM() LIMIT 1',
      [excludeId],
    );
    if (rows.isEmpty) return null;
    return Puzzle.fromMap(rows.first);
  }

  @override
  Future<Puzzle?> getPuzzleById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'puzzles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Puzzle.fromMap(rows.first);
  }

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
}
