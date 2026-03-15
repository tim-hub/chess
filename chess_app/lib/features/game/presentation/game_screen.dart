import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/game_state.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'board/board_widget.dart';
import 'board/animated_piece.dart';
import 'move_history_strip.dart';
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

  Move? _animatingMove;
  String? _hidePieceOn;
  int _lastHistoryLength = 0;

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

      // Castling UX fix: if king selected and player taps own rook,
      // redirect to the king's landing square UCI.
      const castlingMap = {
        'e1h1': 'e1g1', // white kingside
        'e1a1': 'e1c1', // white queenside
        'e8h8': 'e8g8', // black kingside
        'e8a8': 'e8c8', // black queenside
      };
      var uciBase = '$_selectedSquare$square';
      final castlingRedirect = castlingMap[uciBase];
      if (castlingRedirect != null && gameState.legalMoves.contains(castlingRedirect)) {
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

  static Offset _squareToOffset(String square, double squareSize, bool flipped) {
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    final col = flipped ? 7 - file : file;
    final row = flipped ? rank : 7 - rank;
    return Offset(col * squareSize, row * squareSize);
  }

  String _pieceCharForMove(Move move, Map<String, String> position) {
    return position[move.to] ?? '';
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

    // Trigger piece slide animation when a new move is added
    final currentHistory = gameState.history;
    if (currentHistory.length > _lastHistoryLength && currentHistory.isNotEmpty) {
      _lastHistoryLength = currentHistory.length;
      final lastMove = currentHistory.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _animatingMove = lastMove;
            _hidePieceOn = lastMove.to;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Chess'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Take back',
            onPressed: gameState.canUndo
                ? () => ref.read(gameNotifierProvider.notifier).undoLastMove()
                : null,
          ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = constraints.maxWidth;
                final squareSize = boardSize / 8;

                return Stack(
                  children: [
                    BoardWidget(
                      flipped: flipped,
                      pieceSet: settings.pieceSet,
                      boardTheme: settings.boardTheme,
                      position: position,
                      legalMoves: _legalMovesFromSelected,
                      selectedSquare: _selectedSquare,
                      lastMove: gameState.history.isNotEmpty ? gameState.history.last : null,
                      onSquareTap: (sq) => _onSquareTap(sq, gameState),
                      hidePieceOnSquare: _hidePieceOn,
                    ),
                    if (_animatingMove != null)
                      AnimatedPiece(
                        pieceChar: _pieceCharForMove(_animatingMove!, position),
                        pieceSet: settings.pieceSet,
                        fromOffset: _squareToOffset(_animatingMove!.from, squareSize, flipped),
                        toOffset: _squareToOffset(_animatingMove!.to, squareSize, flipped),
                        squareSize: squareSize,
                        onComplete: () {
                          if (mounted) {
                            setState(() {
                              _animatingMove = null;
                              _hidePieceOn = null;
                            });
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          MoveHistoryStrip(history: gameState.history),
        ],
      ),
    );
  }
}
