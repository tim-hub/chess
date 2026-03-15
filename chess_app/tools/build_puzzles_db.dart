import 'dart:io';
import 'package:csv/csv.dart';
import 'package:sqlite3/sqlite3.dart';

// Usage: dart run tools/build_puzzles_db.dart <input.csv> <output.db>
// Example: dart run tools/build_puzzles_db.dart puzzles.csv assets/puzzles.db

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('Usage: dart run tools/build_puzzles_db.dart <input.csv> <output.db>');
    exit(1);
  }

  final csvPath = args[0];
  final dbPath = args[1];

  if (!File(csvPath).existsSync()) {
    stderr.writeln('Error: CSV file not found: $csvPath');
    exit(1);
  }

  // Delete existing DB
  final dbFile = File(dbPath);
  if (dbFile.existsSync()) dbFile.deleteSync();

  final db = sqlite3.open(dbPath);

  try {
    // Create tables
    db.execute('''
      CREATE TABLE puzzles (
        id TEXT PRIMARY KEY,
        fen TEXT NOT NULL,
        moves TEXT NOT NULL,
        rating INTEGER NOT NULL,
        themes TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE VIRTUAL TABLE puzzles_fts USING fts5(
        id,
        themes,
        content=puzzles,
        content_rowid=rowid
      )
    ''');

    db.execute('CREATE INDEX idx_rating ON puzzles(rating)');

    // Read and insert CSV
    final csvContent = await File(csvPath).readAsString();
    final rows = const CsvToListConverter(eol: '\n').convert(csvContent);

    // Skip header row (PuzzleId,FEN,Moves,Rating,RatingDeviation,Popularity,NbPlays,Themes,GameUrl,OpeningTags)
    final dataRows = rows.skip(1).toList();
    final total = dataRows.length;

    print('Inserting $total puzzles...');

    final insertStmt = db.prepare(
      'INSERT OR IGNORE INTO puzzles (id, fen, moves, rating, themes) VALUES (?, ?, ?, ?, ?)',
    );

    var count = 0;
    db.execute('BEGIN');

    for (final row in dataRows) {
      if (row.length < 8) continue;

      final id = row[0].toString().trim();
      final fen = row[1].toString().trim();
      final moves = row[2].toString().trim();
      final rating = int.tryParse(row[3].toString().trim()) ?? 1500;
      final themes = row[7].toString().trim();

      insertStmt.execute([id, fen, moves, rating, themes]);
      count++;

      if (count % 10000 == 0) {
        db.execute('COMMIT');
        print('  $count / $total inserted...');
        db.execute('BEGIN');
      }
    }

    db.execute('COMMIT');
    insertStmt.dispose();

    // Rebuild FTS index
    print('Rebuilding FTS index...');
    db.execute("INSERT INTO puzzles_fts(puzzles_fts) VALUES('rebuild')");

    // Report stats
    final result = db.select('SELECT COUNT(*) as n FROM puzzles').first;
    print('Done! ${result['n']} puzzles in database.');
  } finally {
    db.dispose();
  }
}
