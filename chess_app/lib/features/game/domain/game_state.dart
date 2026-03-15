import 'models.dart';

class GameState {
  final String fen;
  final List<Move> history;
  final List<String> legalMoves; // UCI strings
  final Side playerColor;
  final DifficultyLevel difficulty;
  final GameStatus status;
  final bool isAiThinking;
  final List<String> fenHistory;

  static const kStartFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  const GameState({
    required this.fen,
    required this.history,
    required this.legalMoves,
    required this.playerColor,
    required this.difficulty,
    required this.status,
    this.isAiThinking = false,
    this.fenHistory = const [],
  });

  bool get canUndo => history.length >= 2 && !isAiThinking && fenHistory.length >= 2;

  /// True when it is the human player's turn to move.
  bool get isPlayerTurn {
    final activeColor = fen.split(' ')[1]; // 'w' or 'b'
    return (activeColor == 'w') == (playerColor == Side.white);
  }

  GameState copyWith({
    String? fen,
    List<Move>? history,
    List<String>? legalMoves,
    Side? playerColor,
    DifficultyLevel? difficulty,
    GameStatus? status,
    bool? isAiThinking,
    List<String>? fenHistory,
  }) =>
      GameState(
        fen: fen ?? this.fen,
        history: history ?? this.history,
        legalMoves: legalMoves ?? this.legalMoves,
        playerColor: playerColor ?? this.playerColor,
        difficulty: difficulty ?? this.difficulty,
        status: status ?? this.status,
        isAiThinking: isAiThinking ?? this.isAiThinking,
        fenHistory: fenHistory ?? this.fenHistory,
      );
}
