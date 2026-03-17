import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PuzzleChapter.starCount', () {
    PuzzleChapter chapter({required int solved, required int total}) {
      return PuzzleChapter(
        id: 'test',
        name: 'Test',
        icon: '♟',
        puzzleIds: List.generate(total, (i) => 'p$i'),
        solvedCount: solved,
        isUnlocked: true,
      );
    }

    test('0 stars when solved < 50%', () {
      expect(chapter(solved: 4, total: 10).starCount, 0);
    });

    test('1 star when solved >= 50% and < 75%', () {
      expect(chapter(solved: 5, total: 10).starCount, 1);
      expect(chapter(solved: 7, total: 10).starCount, 1); // 70%, below 75%
    });

    test('2 stars when solved >= 75% and < 100%', () {
      expect(chapter(solved: 8, total: 10).starCount, 2); // 80%
      expect(chapter(solved: 9, total: 10).starCount, 2); // 90%
    });

    test('3 stars when all solved', () {
      expect(chapter(solved: 10, total: 10).starCount, 3);
    });

    test('0 stars when totalCount is 0', () {
      expect(chapter(solved: 0, total: 0).starCount, 0);
    });
  });

  group('PuzzleChapterRegistry', () {
    test('kChapterDefinitions has 9 chapters in correct order', () {
      expect(kChapterDefinitions.length, 9);
      expect(kChapterDefinitions.first.id, 'checkmate_in_1');
      expect(kChapterDefinitions.last.id, 'advanced_tactics');
    });

    test('kTagToChapterId maps fork to forks chapter', () {
      expect(kTagToChapterId['fork'], 'forks');
    });

    test('kTagToChapterId maps pin and skewer to same chapter', () {
      expect(kTagToChapterId['pin'], 'pins_and_skewers');
      expect(kTagToChapterId['skewer'], 'pins_and_skewers');
    });

    test('kTagToChapterId maps mateIn1 to checkmate_in_1', () {
      expect(kTagToChapterId['mateIn1'], 'checkmate_in_1');
    });

    test('every chapter definition has non-empty themeTags', () {
      for (final def in kChapterDefinitions) {
        expect(def.themeTags, isNotEmpty, reason: '${def.id} has no theme tags');
      }
    });
  });
}
