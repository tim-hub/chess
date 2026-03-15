import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/core/router/app_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/data/chess_repository_impl.dart';
import 'package:chess_app/features/game/data/game_persistence_service.dart';
import 'package:chess_app/features/game/data/stockfish_service.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/home/presentation/home_screen.dart';
import 'package:chess_app/features/puzzles/data/puzzle_database.dart';
import 'package:chess_app/features/puzzles/data/puzzle_repository_impl.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings
  final settingsNotifier = SettingsNotifier();
  await settingsNotifier.load();

  // Initialize Stockfish
  final stockfishService = StockfishService();
  bool stockfishReady = false;
  try {
    await stockfishService.initialize();
    stockfishReady = true;
  } catch (e) {
    debugPrint('Stockfish initialization failed: $e');
  }

  // Initialize puzzle database
  bool puzzlesAvailable = false;
  try {
    await PuzzleDatabase.getInstance();
    puzzlesAvailable = true;
  } catch (e) {
    debugPrint('Puzzle database initialization failed: $e');
  }

  // Restore saved game
  final persistenceService = GamePersistenceService();
  final savedGame = await persistenceService.restoreGame();

  // Build chess repository
  final chessRepo = ChessRepositoryImpl();

  // Restore legal moves if there's a saved game
  final restoredGame = savedGame?.copyWith(
    legalMoves: chessRepo.loadPosition(savedGame.fen).legalMoves,
  );

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) {
          return SettingsNotifier(settingsNotifier.currentSettings);
        }),
        gameRepositoryProvider.overrideWithValue(chessRepo),
        chessEngineProvider.overrideWithValue(stockfishService),
        puzzleRepositoryProvider.overrideWithValue(PuzzleRepositoryImpl()),
        stockfishReadyProvider.overrideWith(
          (ref) async => stockfishReady,
        ),
        puzzlesAvailableProvider.overrideWith(
          (ref) async => puzzlesAvailable,
        ),
        gameNotifierProvider.overrideWith((ref) {
          final notifier = GameNotifier(ref);
          if (restoredGame != null) {
            notifier.restoreState(restoredGame);
          }
          return notifier;
        }),
      ],
      child: const ChessApp(),
    ),
  );
}

class ChessApp extends ConsumerWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Chess',
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
