import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/features/home/presentation/home_screen.dart';
import 'package:chess_app/features/game/presentation/difficulty_setup_screen.dart';
import 'package:chess_app/features/game/presentation/game_screen.dart';
import 'package:chess_app/features/puzzles/presentation/puzzle_list_screen.dart';
import 'package:chess_app/features/puzzles/presentation/puzzle_screen.dart';
import 'package:chess_app/features/settings/presentation/settings_screen.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/game/setup',
        builder: (context, state) => const DifficultySetupScreen(),
      ),
      GoRoute(
        path: '/game/play',
        redirect: (context, state) {
          // If no active game, redirect to setup
          final gameState = ref.read(gameNotifierProvider);
          if (gameState == null) return '/game/setup';
          return null;
        },
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: '/puzzles',
        builder: (context, state) => const PuzzleListScreen(),
      ),
      GoRoute(
        path: '/puzzles/:id',
        builder: (context, state) {
          final puzzleId = state.pathParameters['id']!;
          return PuzzleScreen(puzzleId: puzzleId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
