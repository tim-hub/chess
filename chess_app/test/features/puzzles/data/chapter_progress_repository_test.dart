import 'package:chess_app/features/puzzles/data/chapter_progress_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getSolvedIds returns empty set for unknown chapter', () async {
    final repo = ChapterProgressRepository();
    final ids = await repo.getSolvedIds('forks');
    expect(ids, isEmpty);
  });

  test('markSolved persists puzzle ID and getSolvedIds returns it', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    final ids = await repo.getSolvedIds('forks');
    expect(ids, contains('puzzle001'));
  });

  test('markSolved is idempotent — duplicate marks do not inflate the set', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    await repo.markSolved('forks', 'puzzle001');
    final ids = await repo.getSolvedIds('forks');
    expect(ids.length, 1);
  });

  test('markSolved for different chapters are independent', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    await repo.markSolved('pins_and_skewers', 'puzzle002');
    expect(await repo.getSolvedIds('forks'), contains('puzzle001'));
    expect(await repo.getSolvedIds('forks'), isNot(contains('puzzle002')));
    expect(await repo.getSolvedIds('pins_and_skewers'), contains('puzzle002'));
  });

  test('multiple puzzles accumulate in same chapter', () async {
    final repo = ChapterProgressRepository();
    await repo.markSolved('forks', 'puzzle001');
    await repo.markSolved('forks', 'puzzle002');
    final ids = await repo.getSolvedIds('forks');
    expect(ids, containsAll(['puzzle001', 'puzzle002']));
    expect(ids.length, 2);
  });
}
