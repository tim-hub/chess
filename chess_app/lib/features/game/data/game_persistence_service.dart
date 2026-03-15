import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/game_state.dart';
import '../domain/models.dart';

class GamePersistenceService {
  static const _keyFen = 'game.fen';
  static const _keyHistory = 'game.history';
  static const _keyPlayerColor = 'game.playerColor';
  static const _keyDifficulty = 'game.difficulty';
  static const _keyStatus = 'game.status';

  Future<void> saveGame(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFen, state.fen);
    await prefs.setString(
      _keyHistory,
      jsonEncode(state.history.map((m) => {'uci': m.uci, 'san': m.san}).toList()),
    );
    await prefs.setString(_keyPlayerColor, state.playerColor.name);
    await prefs.setString(_keyDifficulty, state.difficulty.name);
    await prefs.setString(_keyStatus, state.status.name);
  }

  Future<GameState?> restoreGame() async {
    final prefs = await SharedPreferences.getInstance();
    final fen = prefs.getString(_keyFen);
    if (fen == null) return null;

    try {
      final historyJson = jsonDecode(prefs.getString(_keyHistory) ?? '[]') as List;
      final history = historyJson
          .map((m) => Move(uci: m['uci'] as String, san: m['san'] as String))
          .toList();

      final playerColor = Side.values.firstWhere(
        (s) => s.name == prefs.getString(_keyPlayerColor),
      );
      final difficulty = DifficultyLevel.fromName(
        prefs.getString(_keyDifficulty) ?? '',
      );
      final status = GameStatus.values.firstWhere(
        (s) => s.name == prefs.getString(_keyStatus),
        orElse: () => GameStatus.playing,
      );

      return GameState(
        fen: fen,
        history: history,
        legalMoves: const [],
        playerColor: playerColor,
        difficulty: difficulty,
        status: status,
      );
    } catch (_) {
      await _clearAll(prefs);
      return null;
    }
  }

  Future<void> clearGame() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearAll(prefs);
  }

  Future<void> _clearAll(SharedPreferences prefs) async {
    await prefs.remove(_keyFen);
    await prefs.remove(_keyHistory);
    await prefs.remove(_keyPlayerColor);
    await prefs.remove(_keyDifficulty);
    await prefs.remove(_keyStatus);
  }
}
