import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/game_state.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'board/board_widget.dart';
import 'move_history_panel.dart';
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

  /// Parse FEN position string into a map of square → piece char
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

  void _onSquareTap(String square, GameState gameState) async {
    if (!gameState.isPlayerTurn || gameState.status != GameStatus.playing) {
      return;
    }

    if (_selectedSquare == null) {
      // First tap: select if it's the player's piece
      final position = _parseFen(gameState.fen);
      final piece = position[square];
      if (piece == null) return;
      final isWhitePiece = piece == piece.toUpperCase();
      final isPlayerPiece =
          (isWhitePiece && gameState.playerColor == Side.white) ||
              (!isWhitePiece && gameState.playerColor == Side.black);
      if (!isPlayerPiece) return;

      // Show legal moves from this square
      final movesFromSquare =
          gameState.legalMoves.where((m) => m.startsWith(square)).toList();

      setState(() {
        _selectedSquare = square;
        _legalMovesFromSelected = movesFromSquare;
      });
    } else {
      // Second tap: attempt move
      final uciBase = '$_selectedSquare$square';
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

      // Check if this is a valid move
      if (!gameState.legalMoves
          .any((m) => m == uciMove || m.startsWith(uciBase))) {
        // Tap on another own piece — re-select
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

    // Show game over sheet once
    if (gameState.status != GameStatus.playing && !_gameOverShown) {
      _gameOverShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showGameOverSheet(
          context,
          status: gameState.status,
          playerColor: gameState.playerColor,
          onPlayAgain: () => context.go('/game/setup'),
          onHome: () => context.go('/'),
        );
      });
    }

    final position = _parseFen(gameState.fen);
    final flipped = gameState.playerColor == Side.black;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Chess'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'resign') {
                ref.read(gameNotifierProvider.notifier).resign();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'resign', child: Text('Resign')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (gameState.isAiThinking)
            const LinearProgressIndicator(
              backgroundColor: AppColors.background,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          Expanded(
            child: BoardWidget(
              flipped: flipped,
              pieceSet: settings.pieceSet,
              boardTheme: settings.boardTheme,
              position: position,
              legalMoves: _legalMovesFromSelected,
              selectedSquare: _selectedSquare,
              lastMove:
                  gameState.history.isNotEmpty ? gameState.history.last : null,
              onSquareTap: (sq) => _onSquareTap(sq, gameState),
            ),
          ),
          SizedBox(
            height: 120,
            child: MoveHistoryPanel(history: gameState.history),
          ),
        ],
      ),
    );
  }
}
