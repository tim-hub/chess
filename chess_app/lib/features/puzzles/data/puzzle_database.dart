import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Manages the puzzle SQLite database asset.
/// Copies from Flutter assets to the documents directory on first run.
/// Seeds sample puzzles if the asset DB has no schema (empty file).
class PuzzleDatabase {
  static Database? _db;

  static Future<Database> getInstance() async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, 'puzzles.db');

    // Copy from assets if not present
    if (!File(dbPath).existsSync()) {
      await _copyFromAssets(dbPath);
    }

    final db = await openDatabase(dbPath).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Puzzle database open timed out'),
    );

    await _ensureSchema(db);
    await _applyMigrations(db);
    return db;
  }

  static Future<void> _copyFromAssets(String destPath) async {
    final data = await rootBundle.load('assets/puzzles.db');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(destPath).writeAsBytes(bytes);
  }

  /// Creates schema and seeds sample puzzles if the DB has no tables.
  /// This handles the case where the bundled assets/puzzles.db is an empty file.
  static Future<void> _ensureSchema(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='puzzles'",
    );
    if (tables.isNotEmpty) return;

    await db.execute('''
      CREATE TABLE IF NOT EXISTS puzzles (
        id TEXT PRIMARY KEY,
        fen TEXT NOT NULL,
        moves TEXT NOT NULL,
        rating INTEGER NOT NULL,
        themes TEXT NOT NULL
      )
    ''');

    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS puzzles_fts USING fts5(
          id,
          themes,
          content=puzzles,
          content_rowid=rowid
        )
      ''');
    } catch (_) {}

    await db.execute('CREATE INDEX IF NOT EXISTS idx_rating ON puzzles(rating)');

    // Seed a few sample puzzles so the app is usable without a full puzzle CSV.
    // Replace assets/puzzles.db using tools/build_puzzles_db.dart for full content.
    await db.insert('puzzles', {
      'id': 'sample_fool_mate',
      // After 1.f3 e5, White plays the blunder g4, Black finds Qh4#
      'fen': 'rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR w KQkq e6 0 2',
      'moves': 'g2g4 d8h4',
      'rating': 600,
      'themes': 'mateIn1 short',
    });

    await db.insert('puzzles', {
      'id': 'sample_scholar_mate',
      // After 1.e4 e5 2.Bc4 Nc6 3.Qh5, Black plays Nf6?? allowing Qxf7#
      'fen': 'r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 3 3',
      'moves': 'g8f6 h5f7',
      'rating': 700,
      'themes': 'mateIn1 short',
    });

    await db.insert('puzzles', {
      'id': 'sample_fork',
      // White knight on c3 forks black king on e7 and rook on c7 with Nd5+
      'fen': '8/2r1k3/8/8/8/2N5/8/4K3 w - - 0 1',
      'moves': 'c3d5',
      'rating': 800,
      'themes': 'fork short',
    });

    await db.insert('puzzles', {
      'id': 'sample_pin',
      // White bishop on b5 pins black knight on d7 to black king on e8; Bxd7+
      'fen': '4k3/3n4/8/1B6/8/8/8/4K3 w - - 0 1',
      'moves': 'b5d7',
      'rating': 850,
      'themes': 'pin short',
    });

    try {
      await db.execute("INSERT INTO puzzles_fts(puzzles_fts) VALUES('rebuild')");
    } catch (_) {}
  }

  /// Idempotent migrations applied every open.
  /// - Fixes legacy 'mateInOne' tag → 'mateIn1' in any existing rows.
  /// - Inserts missing sample puzzles (fork, pin) if they don't yet exist.
  static Future<void> _applyMigrations(Database db) async {
    // Fix old Lichess tag in any seeded or imported rows.
    await db.rawUpdate(
      "UPDATE puzzles SET themes = REPLACE(themes, 'mateInOne', 'mateIn1') "
      "WHERE themes LIKE '%mateInOne%'",
    );

    // Upsert additional sample puzzles (no-op if already present).
    await db.insert(
      'puzzles',
      {
        'id': 'sample_fork',
        'fen': '8/2r1k3/8/8/8/2N5/8/4K3 w - - 0 1',
        'moves': 'c3d5',
        'rating': 800,
        'themes': 'fork short',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'puzzles',
      {
        'id': 'sample_pin',
        'fen': '4k3/3n4/8/1B6/8/8/8/4K3 w - - 0 1',
        'moves': 'b5d7',
        'rating': 850,
        'themes': 'pin short',
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    // Rebuild FTS index to reflect any changes (best-effort; FTS5 may be
    // unavailable on some Android SQLite builds).
    try {
      await db.execute("INSERT INTO puzzles_fts(puzzles_fts) VALUES('rebuild')");
    } catch (_) {}
  }

  // For testing only
  static void setTestDatabase(Database db) => _db = db;
  static void clearTestDatabase() => _db = null;
}
