import 'package:shared_preferences/shared_preferences.dart';

class ChapterProgressRepository {
  static const String _prefix = 'chapter_solved_';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<Set<String>> getSolvedIds(String chapterId) async {
    final prefs = await _prefs;
    final list = prefs.getStringList('$_prefix$chapterId') ?? [];
    return list.toSet();
  }

  Future<void> markSolved(String chapterId, String puzzleId) async {
    final prefs = await _prefs;
    final key = '$_prefix$chapterId';
    final existing = prefs.getStringList(key) ?? [];
    if (!existing.contains(puzzleId)) {
      await prefs.setStringList(key, [...existing, puzzleId]);
    }
  }
}
