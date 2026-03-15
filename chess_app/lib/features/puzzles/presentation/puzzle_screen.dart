import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/core/theme/app_text_styles.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/presentation/board/board_widget.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final String puzzleId;

  const PuzzleScreen({super.key, required this.puzzleId});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  String? _selectedSquare;
  List<String> _legalMovesFromSelected = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(puzzleNotifierProvider.notifier).loadPuzzle(widget.puzzleId);
    });
  }

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

  void _onSquareTap(String square) {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null || !session.isPlayerTurn) return;

    final gameRepo = ref.read(gameRepositoryProvider);
    final position = _parseFen(session.currentFen);

    if (_selectedSquare == null) {
      final piece = position[square];
      if (piece == null) return;

      // Determine player color from FEN active color
      final activeColor = session.currentFen.split(' ')[1];
      final isWhitePiece = piece == piece.toUpperCase();
      final isPlayerPiece = (activeColor == 'w') == isWhitePiece;
      if (!isPlayerPiece) return;

      final legalResult = gameRepo.loadPosition(session.currentFen);
      final movesFromSquare = legalResult.legalMoves
          .where((m) => m.startsWith(square))
          .toList();

      setState(() {
        _selectedSquare = square;
        _legalMovesFromSelected = movesFromSquare;
      });
    } else {
      final uciMove = '$_selectedSquare$square';
      setState(() {
        _selectedSquare = null;
        _legalMovesFromSelected = [];
      });
      ref.read(puzzleNotifierProvider.notifier).submitMove(uciMove);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(puzzleNotifierProvider);
    final settings = ref.watch(settingsProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Puzzle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final position = _parseFen(session.currentFen);
    final activeColor = session.currentFen.split(' ')[1];
    final flipped = activeColor == 'b'; // show board from player's perspective

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Puzzle ${session.puzzle.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              session.isComplete ? '✓ Puzzle solved!' :
              session.isFailed ? 'Wrong move — try again' :
              'Find the best move',
              style: session.isComplete
                  ? AppTextStyles.heading2.copyWith(color: AppColors.successGreen)
                  : session.isFailed
                      ? AppTextStyles.heading2.copyWith(color: AppColors.errorRed)
                      : AppTextStyles.heading2,
            ),
          ),
          Expanded(
            child: BoardWidget(
              flipped: flipped,
              pieceSet: settings.pieceSet,
              boardTheme: settings.boardTheme,
              position: position,
              legalMoves: _legalMovesFromSelected,
              selectedSquare: _selectedSquare,
              lastMove: null,
              onSquareTap: _onSquareTap,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: session.hintCount < 2
                      ? () => ref.read(puzzleNotifierProvider.notifier).useHint()
                      : null,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(
                    session.hintCount == 0 ? 'Hint' :
                    session.hintCount == 1 ? 'More hint' : 'No more hints',
                  ),
                ),
                const SizedBox(width: 12),
                if (session.isFailed)
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: () => ref.read(puzzleNotifierProvider.notifier).resetPuzzle(),
                    child: const Text('Try again'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
