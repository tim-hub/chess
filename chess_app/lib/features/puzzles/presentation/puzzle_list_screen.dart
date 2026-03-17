import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/puzzles/domain/puzzle.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_filter.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'daily_puzzle_card.dart';
import 'puzzle_filter_bar.dart';
import 'puzzle_list_tile.dart';

final _dailyPuzzleProvider = FutureProvider<Puzzle?>((ref) async {
  return ref.watch(puzzleRepositoryProvider).getDailyPuzzle();
});

final _puzzleListProvider =
    StateNotifierProvider<_PuzzleListNotifier, _PuzzleListState>(_PuzzleListNotifier.new);

class _PuzzleListState {
  final List<Puzzle> puzzles;
  final PuzzleFilter filter;
  final bool isLoading;
  final bool hasMore;

  const _PuzzleListState({
    this.puzzles = const [],
    this.filter = const PuzzleFilter(),
    this.isLoading = false,
    this.hasMore = true,
  });

  _PuzzleListState copyWith({
    List<Puzzle>? puzzles,
    PuzzleFilter? filter,
    bool? isLoading,
    bool? hasMore,
  }) => _PuzzleListState(
    puzzles: puzzles ?? this.puzzles,
    filter: filter ?? this.filter,
    isLoading: isLoading ?? this.isLoading,
    hasMore: hasMore ?? this.hasMore,
  );
}

class _PuzzleListNotifier extends StateNotifier<_PuzzleListState> {
  final Ref _ref;
  static const _pageSize = 20;

  _PuzzleListNotifier(this._ref) : super(const _PuzzleListState()) {
    loadMore();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    try {
      final repo = _ref.read(puzzleRepositoryProvider);
      final newPuzzles = await repo.getPuzzles(
        state.filter,
        limit: _pageSize,
        offset: state.puzzles.length,
      );
      state = state.copyWith(
        puzzles: [...state.puzzles, ...newPuzzles],
        isLoading: false,
        hasMore: newPuzzles.length == _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void updateFilter(PuzzleFilter filter) {
    state = _PuzzleListState(filter: filter);
    loadMore();
  }
}

class PuzzleListScreen extends ConsumerWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyPuzzle = ref.watch(_dailyPuzzleProvider);
    final listState = ref.watch(_puzzleListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Puzzles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DailyPuzzleCard(
                puzzle: dailyPuzzle.value,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PuzzleFilterBar(
              filter: listState.filter,
              onFilterChanged: (f) => ref.read(_puzzleListProvider.notifier).updateFilter(f),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == listState.puzzles.length) {
                  if (listState.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return null;
                }
                if (index == listState.puzzles.length - 3 && listState.hasMore) {
                  ref.read(_puzzleListProvider.notifier).loadMore();
                }
                return PuzzleListTile(puzzle: listState.puzzles[index]);
              },
              childCount: listState.puzzles.length + (listState.isLoading ? 1 : 0),
            ),
          ),
        ],
      ),
    );
  }
}
