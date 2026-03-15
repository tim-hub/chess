import 'package:chess_app/features/puzzles/data/puzzle_database.dart';
import 'package:chess_app/features/puzzles/data/puzzle_repository_impl.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Creates an in-memory test database with the puzzle schema.
Future<Database> createTestDb() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final db = await factory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE puzzles (
            id TEXT PRIMARY KEY,
            fen TEXT NOT NULL,
            moves TEXT NOT NULL,
            rating INTEGER NOT NULL,
            themes TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE VIRTUAL TABLE puzzles_fts USING fts5(
            id,
            themes,
            content=puzzles,
            content_rowid=rowid
          )
        ''');
        await db.execute('CREATE INDEX idx_rating ON puzzles(rating)');

        // Insert test data
        await db.insert('puzzles', {
          'id': 'p001', 'fen': 'fen1', 'moves': 'e2e4 e7e5',
          'rating': 1200, 'themes': 'fork advantage',
        });
        await db.insert('puzzles', {
          'id': 'p002', 'fen': 'fen2', 'moves': 'd2d4 d7d5',
          'rating': 1800, 'themes': 'pin endgame',
        });
        await db.insert('puzzles', {
          'id': 'p003', 'fen': 'fen3', 'moves': 'f2f3 e7e5 g2g4 d8h4',
          'rating': 1500, 'themes': 'mateIn2 fork',
        });
        // Rebuild FTS
        await db.execute("INSERT INTO puzzles_fts(puzzles_fts) VALUES('rebuild')");
      },
    ),
  );
  return db;
}

void main() {
  late Database testDb;
  late PuzzleRepositoryImpl repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    testDb = await createTestDb();
    // Override PuzzleDatabase singleton for testing
    PuzzleDatabase.setTestDatabase(testDb);
    repo = PuzzleRepositoryImpl();
  });

  tearDown(() async {
    await testDb.close();
    PuzzleDatabase.clearTestDatabase();
  });

  test('getPuzzles returns all puzzles without filter', () async {
    final puzzles = await repo.getPuzzles(const PuzzleFilter());
    expect(puzzles.length, 3);
  });

  test('getPuzzles filters by rating range', () async {
    final puzzles = await repo.getPuzzles(
      const PuzzleFilter(minRating: 1400, maxRating: 1600),
    );
    expect(puzzles.length, 1);
    expect(puzzles.first.id, 'p003');
  });

  test('getPuzzles filters by theme using FTS5', () async {
    final puzzles = await repo.getPuzzles(
      const PuzzleFilter(theme: 'fork'),
    );
    expect(puzzles.length, 2); // p001 and p003 both have 'fork' theme
  });

  test('getDailyPuzzle returns a puzzle', () async {
    final puzzle = await repo.getDailyPuzzle();
    expect(puzzle, isNotNull);
    expect(['p001', 'p002', 'p003'], contains(puzzle!.id));
  });

  test('getPuzzleById returns correct puzzle', () async {
    final puzzle = await repo.getPuzzleById('p002');
    expect(puzzle, isNotNull);
    expect(puzzle!.id, 'p002');
    expect(puzzle.rating, 1800);
  });

  test('getPuzzleById returns null for unknown id', () async {
    final puzzle = await repo.getPuzzleById('nonexistent');
    expect(puzzle, isNull);
  });
}
