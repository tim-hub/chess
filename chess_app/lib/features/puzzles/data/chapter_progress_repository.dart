import 'package:shared_preferences/shared_preferences.dart';

class ChapterProgressRepository {
  static const String _prefix = 'chapter_solved_';

  Future<Set<String>> getSolvedIds(String chapterId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_prefix$chapterId') ?? [];
    return list.toSet();
  }

  Future<void> markSolved(String chapterId, String puzzleId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$chapterId';
    final existing = prefs.getStringList(key) ?? [];
    if (!existing.contains(puzzleId)) {
      await prefs.setStringList(key, [...existing, puzzleId]);
    }
  }
}
