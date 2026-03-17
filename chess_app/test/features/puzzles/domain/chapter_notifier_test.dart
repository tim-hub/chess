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
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['mateIn1', 'mateInOne'], limit: any(named: 'limit')))
        .thenAnswer((_) async => ['p1', 'p2', 'p3', 'p4', 'p5']);
    // 0 solved → 0 stars → chapter 2 locked
    final notifier = ChapterNotifier(puzzleRepo, progressRepo);
    await notifier.load();
    expect(notifier.state[1].isUnlocked, isFalse);
  });

  test('chapter 2 unlocks when chapter 1 earns 1 star (50% solved)', () async {
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['mateIn1', 'mateInOne'], limit: any(named: 'limit')))
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
    when(() => puzzleRepo.getPuzzleIdsByThemeTags(['mateIn1', 'mateInOne'], limit: any(named: 'limit')))
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
