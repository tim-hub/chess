import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/game_state.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'board/board_widget.dart';
import 'move_history_strip.dart';
import 'captured_pieces_row.dart';
import 'game_over_sheet.dart';
import 'promotion_modal.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  String? _selectedSquare;
  List<String> _legalMovesFromSelected = [];
  bool _gameOverShown = false;


  Map<String, String> _parseFen(String fen) {
    final position = <String, String>{};
    final board = fen.split(' ')[0];
    final ranks = board.split('/');
    for (var rankIdx = 0; rankIdx < 8; rankIdx++) {
      final rank = ranks[rankIdx];
      var fileIdx = 0;
      for (final char in rank.split('')) {
        if (int.tryParse(char) != null) {
          fileIdx += int.parse(char);
        } else {
          final square =
              '${String.fromCharCode('a'.codeUnitAt(0) + fileIdx)}${8 - rankIdx}';
          position[square] = char;
          fileIdx++;
        }
      }
    }
    return position;
  }

  /// Returns pieces captured by each side derived from the FEN.
  /// [whiteCaptured] = white pieces missing (captured by black).
  /// [blackCaptured] = black pieces missing (captured by white).
  static ({List<String> whiteCaptured, List<String> blackCaptured})
      _computeCaptured(String fen) {
    const start = {
      'P': 8, 'N': 2, 'B': 2, 'R': 2, 'Q': 1,
      'p': 8, 'n': 2, 'b': 2, 'r': 2, 'q': 1,
    };
    final counts = <String, int>{};
    for (final c in fen.split(' ')[0].replaceAll('/', '').split('')) {
      if (int.tryParse(c) == null) counts[c] = (counts[c] ?? 0) + 1;
    }
    final whiteCaptured = <String>[];
    final blackCaptured = <String>[];
    for (final e in start.entries) {
      final missing = e.value - (counts[e.key] ?? 0);
      for (var i = 0; i < missing; i++) {
        if (e.key == e.key.toUpperCase()) {
          whiteCaptured.add(e.key); // white piece gone → captured by black
        } else {
          blackCaptured.add(e.key); // black piece gone → captured by white
        }
      }
    }
    return (whiteCaptured: whiteCaptured, blackCaptured: blackCaptured);
  }

  /// Last move made by the given side (white=even indices, black=odd indices).
  static Move? _lastMoveFor(List<Move> history, Side side) {
    if (history.isEmpty) return null;
    final wantEven = side == Side.white;
    Move? found;
    for (var i = 0; i < history.length; i++) {
      if ((i % 2 == 0) == wantEven) found = history[i];
    }
    return found;
  }

  void _onSquareTap(String square, GameState gameState) async {
    if (!gameState.isPlayerTurn || gameState.status != GameStatus.playing) {
      return;
    }

    if (_selectedSquare == null) {
      final position = _parseFen(gameState.fen);
      final piece = position[square];
      if (piece == null) return;
      final isWhitePiece = piece == piece.toUpperCase();
      final isPlayerPiece =
          (isWhitePiece && gameState.playerColor == Side.white) ||
              (!isWhitePiece && gameState.playerColor == Side.black);
      if (!isPlayerPiece) return;

      final movesFromSquare =
          gameState.legalMoves.where((m) => m.startsWith(square)).toList();
      setState(() {
        _selectedSquare = square;
        _legalMovesFromSelected = movesFromSquare;
      });
    } else {
      const castlingMap = {
        'e1h1': 'e1g1',
        'e1a1': 'e1c1',
        'e8h8': 'e8g8',
        'e8a8': 'e8c8',
      };
      var uciBase = '$_selectedSquare$square';
      final castlingRedirect = castlingMap[uciBase];
      if (castlingRedirect != null &&
          gameState.legalMoves.contains(castlingRedirect)) {
        uciBase = castlingRedirect;
      }

      final isPromotion = gameState.legalMoves.any(
        (m) => m.length == 5 && m.startsWith(uciBase),
      );

      String uciMove;
      if (isPromotion) {
        final position = _parseFen(gameState.fen);
        final piece = position[_selectedSquare!];
        final isWhite = piece != null && piece == piece.toUpperCase();
        final promotion = await showPromotionPicker(
          context,
          isWhite: isWhite,
          pieceSet: ref.read(settingsProvider).pieceSet,
        );
        if (promotion == null) {
          setState(() {
            _selectedSquare = null;
            _legalMovesFromSelected = [];
          });
          return;
        }
        uciMove = '$uciBase$promotion';
      } else {
        uciMove = uciBase;
      }

      if (!gameState.legalMoves
          .any((m) => m == uciMove || m.startsWith(uciBase))) {
        final position = _parseFen(gameState.fen);
        final piece = position[square];
        if (piece != null) {
          final isWhitePiece = piece == piece.toUpperCase();
          final isPlayerPiece =
              (isWhitePiece && gameState.playerColor == Side.white) ||
                  (!isWhitePiece && gameState.playerColor == Side.black);
          if (isPlayerPiece) {
            final movesFromSquare = gameState.legalMoves
                .where((m) => m.startsWith(square))
                .toList();
            setState(() {
              _selectedSquare = square;
              _legalMovesFromSelected = movesFromSquare;
            });
            return;
          }
        }
        setState(() {
          _selectedSquare = null;
          _legalMovesFromSelected = [];
        });
        return;
      }

      setState(() {
        _selectedSquare = null;
        _legalMovesFromSelected = [];
      });

      await ref.read(gameNotifierProvider.notifier).applyPlayerMove(uciMove);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameNotifierProvider);
    final settings = ref.watch(settingsProvider);

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (gameState.status != GameStatus.playing && !_gameOverShown) {
      _gameOverShown = true;
      // Determine winner: the side that made the last move won (for checkmate)
      Side? winnerSide;
      if (gameState.status == GameStatus.checkmate &&
          gameState.history.isNotEmpty) {
        winnerSide = gameState.history.length % 2 == 1 ? Side.white : Side.black;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showGameOverSheet(
          context,
          status: gameState.status,
          playerColor: gameState.playerColor,
          winnerSide: winnerSide,
          onPlayAgain: () => context.go('/game/setup'),
          onHome: () => context.go('/'),
        );
      });
    }

    final position = _parseFen(gameState.fen);
    final flipped = gameState.playerColor == Side.black;

    final captured = _computeCaptured(gameState.fen);
    final opponentSide =
        gameState.playerColor == Side.white ? Side.black : Side.white;

    // Opponent's panel shows pieces they captured (player's pieces now missing)
    final opponentCaptured = gameState.playerColor == Side.white
        ? captured.whiteCaptured
        : captured.blackCaptured;

    // Player's panel shows pieces they captured (opponent's pieces now missing)
    final playerCaptured = gameState.playerColor == Side.white
        ? captured.blackCaptured
        : captured.whiteCaptured;

    final opponentLastMove = _lastMoveFor(gameState.history, opponentSide);
    final playerLastMove =
        _lastMoveFor(gameState.history, gameState.playerColor);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Chess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 3,
            child: gameState.isAiThinking
                ? const LinearProgressIndicator(
                    backgroundColor: AppColors.background,
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  )
                : null,
          ),

          // Opponent panel (top)
          _PlayerInfoPanel(
            name: 'Computer',
            isOpponent: true,
            isActive: !gameState.isPlayerTurn && !gameState.isAiThinking,
            capturedPieces: opponentCaptured,
            lastMoveSan: opponentLastMove?.san,
            pieceSet: settings.pieceSet,
          ),

          // Board
          Expanded(
            child: BoardWidget(
              flipped: flipped,
              pieceSet: settings.pieceSet,
              boardTheme: settings.boardTheme,
              position: position,
              legalMoves: _legalMovesFromSelected,
              selectedSquare: _selectedSquare,
              lastMove: gameState.history.isNotEmpty
                  ? gameState.history.last
                  : null,
              onSquareTap: (sq) => _onSquareTap(sq, gameState),
              hidePieceOnSquare: null,
            ),
          ),

          // Player panel (bottom)
          _PlayerInfoPanel(
            name: 'You',
            isOpponent: false,
            isActive: gameState.isPlayerTurn,
            capturedPieces: playerCaptured,
            lastMoveSan: playerLastMove?.san,
            pieceSet: settings.pieceSet,
            onUndo: gameState.canUndo
                ? () {
                    setState(() {
                      _selectedSquare = null;
                      _legalMovesFromSelected = [];
                    });
                    ref.read(gameNotifierProvider.notifier).undoLastMove();
                  }
                : null,
            onResign: () => ref.read(gameNotifierProvider.notifier).resign(),
          ),

          // Move history
          MoveHistoryStrip(history: gameState.history),
        ],
      ),
    );
  }
}

class _PlayerInfoPanel extends StatelessWidget {
  final String name;
  final bool isOpponent;
  final bool isActive;
  final List<String> capturedPieces;
  final String? lastMoveSan;
  final String pieceSet;
  final VoidCallback? onUndo;
  final VoidCallback? onResign;

  const _PlayerInfoPanel({
    required this.name,
    required this.isOpponent,
    required this.isActive,
    required this.capturedPieces,
    required this.lastMoveSan,
    required this.pieceSet,
    this.onUndo,
    this.onResign,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor:
                isActive ? AppColors.accent : const Color(0xFFE0E0E0),
            child: Icon(
              isOpponent ? Icons.computer : Icons.person,
              size: 18,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          // Name + captured pieces
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (lastMoveSan != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.accent
                              : const Color(0xFFE8E8E8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lastMoveSan!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (capturedPieces.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  CapturedPiecesRow(
                    capturedPieces: capturedPieces,
                    pieceSet: pieceSet,
                    showWhitePieces: !isOpponent,
                  ),
                ],
              ],
            ),
          ),
          if (!isOpponent) ...[
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Take back',
              onPressed: onUndo,
              color: AppColors.textSecondary,
            ),
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Leave',
              onPressed: onResign,
              color: AppColors.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}
