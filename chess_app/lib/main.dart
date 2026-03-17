import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/core/router/app_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import 'package:chess_app/features/game/data/chess_repository_impl.dart';
import 'package:chess_app/features/game/data/game_persistence_service.dart';
import 'package:chess_app/features/game/data/minimax_engine.dart';
import 'package:chess_app/features/game/data/stockfish_service.dart';
import 'package:chess_app/features/game/domain/chess_engine.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/home/presentation/home_screen.dart';
import 'package:chess_app/features/puzzles/data/puzzle_database.dart';
import 'package:chess_app/features/puzzles/data/puzzle_repository_impl.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize settings
  // ignore: invalid_use_of_visible_for_testing_member
  final settingsLoader = SettingsNotifier.forLoading();
  await settingsLoader.load();

  // Initialize AudioService with loaded settings
  final audioService = AudioService();
  await audioService.init(
    musicEnabled: settingsLoader.currentSettings.music,
    sfxEnabled: settingsLoader.currentSettings.soundEffects,
  );

  // Load persisted credits
  final creditsService = CreditsService();
  await creditsService.load();

  final statsService = StatsService();
  await statsService.load();

  // Stockfish only works on iOS/Android. Use MinimaxEngine on macOS/desktop.
  ChessEngine chessEngine;
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    final stockfish = StockfishService();
    try {
      await stockfish.initialize();
      chessEngine = stockfish;
      debugPrint('Stockfish ready');
    } catch (e) {
      debugPrint('Stockfish failed, falling back to minimax: $e');
      chessEngine = MinimaxEngine();
    }
  } else {
    chessEngine = MinimaxEngine();
    debugPrint('Using MinimaxEngine (Stockfish not supported on this platform)');
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
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(ref, settingsLoader.currentSettings),
        ),
        audioServiceProvider.overrideWithValue(audioService),
        creditsProvider.overrideWith((_) => creditsService),
        statsProvider.overrideWith((_) => statsService),
        gameRepositoryProvider.overrideWithValue(chessRepo),
        chessEngineProvider.overrideWithValue(chessEngine),
        puzzleRepositoryProvider.overrideWithValue(PuzzleRepositoryImpl()),
        stockfishReadyProvider.overrideWith(
          (ref) async => true,
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
