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

// ── Service (stub — full impl in Task 3) ─────────────────────────────────────

class StatsService extends StateNotifier<StatsState> {
  StatsService() : super(StatsState.empty);

  Future<void> load() async {}
  void recordPuzzleSolved({required int hintsUsed}) {}
  void recordGameWin(DifficultyLevel difficulty) {}
  void recordGameLoss(DifficultyLevel difficulty) {}
}
