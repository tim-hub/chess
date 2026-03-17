import 'package:chess_app/features/game/domain/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class StatsState {
  final int puzzlesSolved;
  final int totalHintsUsed;
  final int perfectSolves;
  final Map<DifficultyLevel, int> wins;
  final Map<DifficultyLevel, int> losses;

  const StatsState({
    this.puzzlesSolved = 0,
    this.totalHintsUsed = 0,
    this.perfectSolves = 0,
    this.wins = const {},
    this.losses = const {},
  });

  // Not const — logical zero-value sentinel, not a singleton.
  static final empty = StatsState();

  StatsState copyWith({
    int? puzzlesSolved,
    int? totalHintsUsed,
    int? perfectSolves,
    Map<DifficultyLevel, int>? wins,
    Map<DifficultyLevel, int>? losses,
  }) =>
      StatsState(
        puzzlesSolved: puzzlesSolved ?? this.puzzlesSolved,
        totalHintsUsed: totalHintsUsed ?? this.totalHintsUsed,
        perfectSolves: perfectSolves ?? this.perfectSolves,
        wins: wins ?? this.wins,
        losses: losses ?? this.losses,
      );
}

// ── Provider (overridden in main.dart) ───────────────────────────────────────

final statsProvider =
    StateNotifierProvider<StatsService, StatsState>((_) => StatsService());

// ── Service ───────────────────────────────────────────────────────────────────

class StatsService extends StateNotifier<StatsState> {
  static const _keySolved = 'stats.puzzles.solved';
  static const _keyHints = 'stats.puzzles.hints_used';
  static const _keyPerfect = 'stats.puzzles.perfect';
  static String _winsKey(DifficultyLevel d) => 'stats.game.wins.${d.name}';
  static String _lossesKey(DifficultyLevel d) => 'stats.game.losses.${d.name}';

  SharedPreferences? _prefs;

  StatsService() : super(StatsState.empty);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final wins = <DifficultyLevel, int>{};
      final losses = <DifficultyLevel, int>{};
      for (final d in DifficultyLevel.values) {
        final w = prefs.getInt(_winsKey(d));
        final l = prefs.getInt(_lossesKey(d));
        if (w != null) wins[d] = w;
        if (l != null) losses[d] = l;
      }
      state = StatsState(
        puzzlesSolved: prefs.getInt(_keySolved) ?? 0,
        totalHintsUsed: prefs.getInt(_keyHints) ?? 0,
        perfectSolves: prefs.getInt(_keyPerfect) ?? 0,
        wins: wins,
        losses: losses,
      );
    } catch (e) {
      debugPrint('StatsService.load failed: $e');
      state = StatsState.empty;
    }
  }

  void recordPuzzleSolved({required int hintsUsed}) {
    state = state.copyWith(
      puzzlesSolved: state.puzzlesSolved + 1,
      totalHintsUsed: state.totalHintsUsed + hintsUsed,
      perfectSolves: hintsUsed == 0 ? state.perfectSolves + 1 : state.perfectSolves,
    );
    _persist();
  }

  void recordGameWin(DifficultyLevel difficulty) {
    final updated = Map<DifficultyLevel, int>.from(state.wins);
    updated[difficulty] = (updated[difficulty] ?? 0) + 1;
    state = state.copyWith(wins: updated);
    _persist();
  }

  void recordGameLoss(DifficultyLevel difficulty) {
    final updated = Map<DifficultyLevel, int>.from(state.losses);
    updated[difficulty] = (updated[difficulty] ?? 0) + 1;
    state = state.copyWith(losses: updated);
    _persist();
  }

  void _persist() async {
    try {
      final prefs = _prefs;
      if (prefs == null) return; // not loaded yet, skip
      await prefs.setInt(_keySolved, state.puzzlesSolved);
      await prefs.setInt(_keyHints, state.totalHintsUsed);
      await prefs.setInt(_keyPerfect, state.perfectSolves);
      for (final d in DifficultyLevel.values) {
        final w = state.wins[d];
        final l = state.losses[d];
        if (w != null) await prefs.setInt(_winsKey(d), w);
        if (l != null) await prefs.setInt(_lossesKey(d), l);
      }
    } catch (e) {
      debugPrint('StatsService._persist failed: $e');
    }
  }
}
