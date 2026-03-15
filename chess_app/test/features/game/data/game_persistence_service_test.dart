import 'dart:convert';
import 'package:chess_app/features/game/data/game_persistence_service.dart';
import 'package:chess_app/features/game/domain/game_state.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late GamePersistenceService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = GamePersistenceService();
  });

  test('saveGame stores all fields', () async {
    final state = GameState(
      fen: GameState.kStartFen,
      history: [Move(uci: 'e2e4', san: 'e4')],
      legalMoves: ['e7e5'],
      playerColor: Side.white,
      difficulty: DifficultyLevel.medium,
      status: GameStatus.playing,
    );

    await service.saveGame(state);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('game.fen'), GameState.kStartFen);
    expect(prefs.getString('game.playerColor'), 'white');
    expect(prefs.getString('game.difficulty'), 'medium');
    expect(prefs.getString('game.status'), 'playing');

    final history = jsonDecode(prefs.getString('game.history')!) as List;
    expect(history, hasLength(1));
    expect(history[0]['uci'], 'e2e4');
    expect(history[0]['san'], 'e4');
  });

  test('restoreGame returns saved state', () async {
    final original = GameState(
      fen: GameState.kStartFen,
      history: [Move(uci: 'e2e4', san: 'e4'), Move(uci: 'e7e5', san: 'e5')],
      legalMoves: [],
      playerColor: Side.black,
      difficulty: DifficultyLevel.hard,
      status: GameStatus.playing,
    );

    await service.saveGame(original);
    final restored = await service.restoreGame();

    expect(restored, isNotNull);
    expect(restored!.fen, GameState.kStartFen);
    expect(restored.playerColor, Side.black);
    expect(restored.difficulty, DifficultyLevel.hard);
    expect(restored.status, GameStatus.playing);
    expect(restored.history.length, 2);
    expect(restored.history[0].uci, 'e2e4');
    expect(restored.history[1].san, 'e5');
  });

  test('restoreGame returns null when no data', () async {
    final result = await service.restoreGame();
    expect(result, isNull);
  });

  test('corrupt data clears all keys and returns null', () async {
    SharedPreferences.setMockInitialValues({
      'game.fen': GameState.kStartFen,
      'game.history': 'not valid json{{{{',
      'game.playerColor': 'white',
      'game.difficulty': 'medium',
      'game.status': 'playing',
    });

    final result = await service.restoreGame();
    expect(result, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('game.fen'), isNull);
    expect(prefs.getString('game.history'), isNull);
  });
}
