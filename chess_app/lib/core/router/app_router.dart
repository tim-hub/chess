import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/features/home/presentation/home_screen.dart';
import 'package:chess_app/features/game/presentation/difficulty_setup_screen.dart';
import 'package:chess_app/features/game/presentation/game_screen.dart';
import 'package:chess_app/features/puzzles/presentation/chapter_list_screen.dart';
import 'package:chess_app/features/puzzles/presentation/puzzle_screen.dart';
import 'package:chess_app/features/settings/presentation/settings_screen.dart';
import 'package:chess_app/features/stats/presentation/stats_screen.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';

/// Builds a [CustomTransitionPage] with a 200ms fade + subtle upward slide.
CustomTransitionPage<void> _fadePage({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/game/setup',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const DifficultySetupScreen(),
        ),
      ),
      GoRoute(
        path: '/game/play',
        redirect: (context, state) {
          final gameState = ref.read(gameNotifierProvider);
          if (gameState == null) return '/game/setup';
          return null;
        },
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const GameScreen(),
        ),
      ),
      GoRoute(
        path: '/puzzles',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const ChapterListScreen(),
        ),
      ),
      GoRoute(
        path: '/puzzles/play/:id',
        pageBuilder: (context, state) {
          final puzzleId = state.pathParameters['id']!;
          final extra = state.extra as Map<String, dynamic>?;
          final chapterId = extra?['chapterId'] as String?;
          return _fadePage(
            state: state,
            child: PuzzleScreen(puzzleId: puzzleId, chapterId: chapterId),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/stats',
        pageBuilder: (context, state) => _fadePage(
          state: state,
          child: const StatsScreen(),
        ),
      ),
    ],
  );
});
