import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/presentation/board/board_widget.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'package:chess_app/features/audio/audio_service.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final String puzzleId;

  const PuzzleScreen({super.key, required this.puzzleId});

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  String? _selectedSquare;
  List<String> _legalMovesFromSelected = [];
  bool _solvedShown = false;
  bool _hintUsed = false;

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
    if (session == null || !session.isPlayerTurn || session.isComplete) return;

    final gameRepo = ref.read(gameRepositoryProvider);
    final position = _parseFen(session.currentFen);

    if (_selectedSquare == null) {
      final piece = position[square];
      if (piece == null) return;

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

  /// Show the expected move as a board highlight and deduct 2 credits.
  void _useHint() {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null || session.expectedMove == null) return;

    final move = session.expectedMove!;
    final from = move.substring(0, 2);
    final to = move.substring(2, 4);

    // Deduct 2 credits (won't go below 0)
    ref.read(creditsProvider.notifier).deduct(2);

    setState(() {
      _hintUsed = true;
      _selectedSquare = from;
      _legalMovesFromSelected = [move.length > 4 ? move.substring(0, 4) : move];
    });

    ref.read(puzzleNotifierProvider.notifier).useHint();
    debugPrint('Hint: move $from → $to');
  }

  void _onPuzzleSolved() {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null) return;

    ref.read(audioServiceProvider).playSuccess();

    // 10 credits base − 2 per hint, minimum 0
    final earned = (10 - session.hintCount * 2).clamp(0, 10);
    ref.read(creditsProvider.notifier).add(earned);

    _showSolvedBanner(earned);
  }

  void _showSolvedBanner(int earned) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SolvedSheet(
        earned: earned,
        onNext: () {
          Navigator.of(context).pop();
          _loadNext();
        },
        onBack: () {
          Navigator.of(context).pop();
          context.pop();
        },
      ),
    );
  }

  void _loadNext() {
    setState(() {
      _solvedShown = false;
      _hintUsed = false;
      _selectedSquare = null;
      _legalMovesFromSelected = [];
    });
    ref.read(puzzleNotifierProvider.notifier).loadNextPuzzle();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(puzzleNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final credits = ref.watch(creditsProvider);

    ref.listen<PuzzleSession?>(puzzleNotifierProvider, (prev, next) {
      if (prev == null || next == null) return;
      final audio = ref.read(audioServiceProvider);

      // Correct move accepted (FEN changed, not failed, not yet complete —
      // complete is handled separately in _onPuzzleSolved to avoid double-firing)
      if (!next.isFailed && !next.isComplete && next.currentFen != prev.currentFen) {
        audio.playMove();
        return;
      }

      // Wrong move
      if (!prev.isFailed && next.isFailed) {
        audio.playWrong();
        return;
      }
    });

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Puzzle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isComplete && !_solvedShown) {
      _solvedShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onPuzzleSolved();
      });
    }

    final position = _parseFen(session.currentFen);
    final activeColor = session.currentFen.split(' ')[1];
    final flipped = activeColor == 'b';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Puzzle ${session.puzzle.id}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Credits badge
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.star_rounded,
                  size: 16, color: Color(0xFFF59E0B)),
              label: Text(
                '$credits',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13),
              ),
              backgroundColor: const Color(0xFFFEF3C7),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Fixed-height status bar
          SizedBox(
            height: 52,
            child: Center(
              child: session.isFailed
                  ? const Text(
                      'Wrong move — try again',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorRed,
                      ),
                    )
                  : const Text(
                      'Find the best move',
                      style: TextStyle(
                          fontSize: 15, color: AppColors.textSecondary),
                    ),
            ),
          ),

          // Board — always same size
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

          // Fixed-height bottom controls
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Hint button
                  OutlinedButton.icon(
                    onPressed: (!_hintUsed && !session.isComplete)
                        ? _useHint
                        : null,
                    icon: Icon(
                      _hintUsed
                          ? Icons.lightbulb
                          : Icons.lightbulb_outline,
                    ),
                    label: Text(_hintUsed ? 'Hint used (−2)' : 'Hint (−2 ⭐)'),
                  ),
                  const SizedBox(width: 12),
                  if (session.isFailed)
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent),
                      onPressed: () {
                        setState(() {
                          _hintUsed = false;
                          _selectedSquare = null;
                          _legalMovesFromSelected = [];
                        });
                        ref
                            .read(puzzleNotifierProvider.notifier)
                            .resetPuzzle();
                      },
                      child: const Text('Try again'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolvedSheet extends StatefulWidget {
  final int earned;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _SolvedSheet({
    required this.earned,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_SolvedSheet> createState() => _SolvedSheetState();
}

class _SolvedSheetState extends State<_SolvedSheet> {
  @override
  void initState() {
    super.initState();
    // Auto-advance to next puzzle after 2.5 s
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.successGreen, size: 56),
            const SizedBox(height: 12),
            const Text(
              'Puzzle Solved!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 4),
                Text(
                  '+${widget.earned} credits',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Next puzzle loading…',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBack,
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent),
                    onPressed: widget.onNext,
                    child: const Text('Next Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
