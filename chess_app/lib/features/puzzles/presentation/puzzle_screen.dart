import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/presentation/board/board_widget.dart';
import 'package:chess_app/features/game/presentation/promotion_modal.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/puzzles/domain/chapter_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter_registry.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_session.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';

class PuzzleScreen extends ConsumerStatefulWidget {
  final String puzzleId;

  /// When navigating from ChapterListScreen, this is the chapter the puzzle
  /// belongs to. Null when opened outside chapter context (e.g. daily puzzle).
  final String? chapterId;

  const PuzzleScreen({
    super.key,
    required this.puzzleId,
    this.chapterId,
  });

  @override
  ConsumerState<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends ConsumerState<PuzzleScreen> {
  String? _selectedSquare;
  List<String> _legalMovesFromSelected = [];
  bool _solvedShown = false;

  // Frozen at solve time so the banner shows correct values even after
  // _loadNext starts loading the next puzzle and the session changes.
  int _earnedAtSolve = 0;
  int _hintCountAtSolve = 0;

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

  void _onSquareTap(String square) async {
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
      final movesFromSquare =
          legalResult.legalMoves.where((m) => m.startsWith(square)).toList();

      setState(() {
        _selectedSquare = square;
        _legalMovesFromSelected = movesFromSquare;
      });
    } else {
      final uciBase = '$_selectedSquare$square';

      // Check for pawn promotion (legal moves include 5-char variants like e7e8q).
      final legalResult = gameRepo.loadPosition(session.currentFen);
      final isPromotion = legalResult.legalMoves
          .any((m) => m.length == 5 && m.startsWith(uciBase));

      String uciMove;
      if (isPromotion) {
        final piece = position[_selectedSquare!];
        final isWhite = piece != null && piece == piece.toUpperCase();
        final promotion = await showPromotionPicker(
          context,
          isWhite: isWhite,
          pieceSet: ref.read(settingsProvider).pieceSet,
        );
        if (!mounted) return;
        if (promotion == null) {
          // User dismissed the picker — deselect.
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

      setState(() {
        _selectedSquare = null;
        _legalMovesFromSelected = [];
      });
      ref.read(puzzleNotifierProvider.notifier).submitMove(uciMove);
    }
  }

  /// Increment hint level. Clears widget-local selection so hint highlights
  /// are not immediately masked by piece-selection state.
  void _useHint() {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null || session.hintCount >= 2 || session.expectedMove == null) return;

    setState(() {
      _selectedSquare = null;
      _legalMovesFromSelected = [];
    });
    ref.read(puzzleNotifierProvider.notifier).useHint();
  }

  Future<void> _onPuzzleSolved() async {
    // Set synchronously before any await to prevent double-fire via
    // addPostFrameCallback (which may be called again before this async
    // method completes its first await).
    if (_solvedShown) return;

    final session = ref.read(puzzleNotifierProvider);
    if (session == null) return;

    // Freeze earned/hintCount before any state changes so the banner
    // always shows the values from the moment of solve.
    final earned = (10 - session.hintCount).clamp(0, 10);
    setState(() {
      _solvedShown = true;
      _earnedAtSolve = earned;
      _hintCountAtSolve = session.hintCount;
    });

    ref.read(audioServiceProvider).playSuccess();

    final chapterId = widget.chapterId;
    final puzzleId = session.puzzle.id;

    // Only award credits on first-time solve
    final alreadySolved = chapterId != null &&
        ref.read(chapterNotifierProvider.notifier).isSolved(chapterId, puzzleId);

    if (!alreadySolved) {
      ref.read(creditsProvider.notifier).add(earned);
    }

    // Update chapter progress (idempotent). In-memory _solvedIds in
    // ChapterNotifier is updated synchronously before the async persist,
    // so nextPuzzleId() immediately skips this puzzle.
    if (chapterId != null) {
      await ref
          .read(chapterNotifierProvider.notifier)
          .markSolved(chapterId, puzzleId);
    }
  }

  void _loadNext() {
    setState(() {
      _solvedShown = false;
      _selectedSquare = null;
      _legalMovesFromSelected = [];
      _earnedAtSolve = 0;
      _hintCountAtSolve = 0;
    });

    final chapterId = widget.chapterId;
    if (chapterId != null) {
      // Check if every puzzle in the chapter has now been solved.
      final chapters = ref.read(chapterNotifierProvider);
      final chapter = chapters.where((c) => c.id == chapterId).firstOrNull;
      if (chapter != null &&
          chapter.totalCount > 0 &&
          chapter.solvedCount >= chapter.totalCount) {
        _showChapterCompleteDialog(chapter);
        return;
      }

      final notifier = ref.read(chapterNotifierProvider.notifier);
      final nextId = notifier.nextPuzzleId(chapterId);
      if (nextId != null) {
        ref.read(puzzleNotifierProvider.notifier).loadPuzzle(nextId);
      } else {
        context.pop();
      }
    } else {
      ref.read(puzzleNotifierProvider.notifier).loadNextPuzzle();
    }
  }

  void _showChapterCompleteDialog(PuzzleChapter chapter) {
    final stars = chapter.starCount;
    final starLabel = ['', '⭐', '⭐⭐', '⭐⭐⭐'][stars.clamp(0, 3)];
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '🎉 Chapter Complete!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              chapter.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              starLabel,
              style: const TextStyle(fontSize: 36),
            ),
            const SizedBox(height: 8),
            Text(
              '${chapter.solvedCount} / ${chapter.totalCount} puzzles solved',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size(180, 44),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop(); // back to chapter list
            },
            child: const Text('Back to Chapters'),
          ),
        ],
      ),
    );
  }

  String _buildTitle(PuzzleSession session, List<PuzzleChapter> chapters) {
    if (widget.chapterId == null) return 'Puzzle ${session.puzzle.id}';
    PuzzleChapter? chapter;
    for (final c in chapters) {
      if (c.id == widget.chapterId) { chapter = c; break; }
    }
    if (chapter == null) return 'Puzzle ${session.puzzle.id}';
    final idx = chapter.puzzleIds.indexOf(session.puzzle.id);
    final displayIdx = idx == -1 ? '?' : '${idx + 1}';
    return '${chapter.name} · #$displayIdx';
  }

  String _statusVerb() {
    if (widget.chapterId == null) return 'Find the best move';
    for (final def in kChapterDefinitions) {
      if (def.id == widget.chapterId) return def.statusVerb;
    }
    return 'Find the best move';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(puzzleNotifierProvider);
    final chapters = ref.watch(chapterNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final credits = ref.watch(creditsProvider);

    ref.listen<PuzzleSession?>(puzzleNotifierProvider, (prev, next) {
      if (prev == null || next == null) return;
      final audio = ref.read(audioServiceProvider);

      if (prev.isPlayerTurn &&
          !next.isFailed &&
          !next.isComplete &&
          next.currentFen != prev.currentFen) {
        audio.playMove();
        return;
      }

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
        title: Text(_buildTitle(session, chapters)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
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
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Status bar
            SizedBox(
              height: 52,
              child: Center(
                child: session.isFailed
                    ? _StatusBar(
                        text: '✗ Not the right move — try again',
                        color: AppColors.errorRed,
                      )
                    : _StatusBar(
                        text: 'Your turn · ${_statusVerb()}',
                        color: AppColors.textSecondary,
                        dot: true,
                      ),
              ),
            ),

            // Board — fills screen width, pushed toward bottom controls
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: BoardWidget(
                  flipped: flipped,
                  pieceSet: settings.pieceSet,
                  boardTheme: settings.boardTheme,
                  position: position,
                  legalMoves: _legalMovesFromSelected,
                  selectedSquare: _selectedSquare,
                  lastMove: null,
                  hintFromSquare: session.hintFromSquare,
                  hintToSquare: session.hintToSquare,
                  onSquareTap: _onSquareTap,
                ),
              ),
            ),

            // Bottom area: solved banner OR bottom controls
            if (_solvedShown)
              _SolvedBanner(
                earned: _earnedAtSolve,
                hintCount: _hintCountAtSolve,
                onNext: _loadNext,
              )
            else
              _BottomControls(
                session: session,
                onHint: _useHint,
                onReset: () {
                  setState(() {
                    _solvedShown = false;
                    _selectedSquare = null;
                    _legalMovesFromSelected = [];
                  });
                  ref.read(puzzleNotifierProvider.notifier).resetPuzzle();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final String text;
  final Color color;
  final bool dot;

  const _StatusBar({required this.text, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (dot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  final PuzzleSession session;
  final VoidCallback onHint;
  final VoidCallback onReset;

  const _BottomControls({
    required this.session,
    required this.onHint,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final hintCount = session.hintCount;
    final String hintLabel;
    final bool hintEnabled;
    if (hintCount == 0) {
      hintLabel = '💡 Hint';
      hintEnabled = !session.isComplete;
    } else if (hintCount == 1) {
      hintLabel = '💡 Show full move';
      hintEnabled = !session.isComplete;
    } else {
      hintLabel = '💡 Full hint shown';
      hintEnabled = false;
    }

    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hintEnabled ? onHint : null,
                icon: Icon(
                  hintCount > 0
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                ),
                label: Text(hintLabel),
              ),
            ),
            if (session.isFailed) ...[
              const SizedBox(width: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent),
                onPressed: onReset,
                child: const Text('↺ Reset'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SolvedBanner extends StatefulWidget {
  final int earned;
  final int hintCount;
  final VoidCallback onNext;

  const _SolvedBanner({
    required this.earned,
    required this.hintCount,
    required this.onNext,
  });

  @override
  State<_SolvedBanner> createState() => _SolvedBannerState();
}

class _SolvedBannerState extends State<_SolvedBanner> {
  bool _advanced = false;

  void _advance() {
    if (_advanced) return;
    _advanced = true;
    widget.onNext();
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _advance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hintNote = widget.hintCount > 0
        ? ' (${widget.hintCount} hint${widget.hintCount > 1 ? 's' : ''} used)'
        : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14532D), Color(0xFF166534)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4ADE80), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '✓ Solved!',
                  style: TextStyle(
                    color: Color(0xFF4ADE80),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '+${widget.earned} ⭐$hintNote',
                  style: const TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF166534)),
            onPressed: _advance,
            child: const Text(
              'Next →',
              style: TextStyle(color: Color(0xFF4ADE80)),
            ),
          ),
        ],
      ),
    );
  }
}
