import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/core/theme/app_text_styles.dart';

final stockfishReadyProvider = FutureProvider<bool>((ref) async {
  // Stockfish readiness is provided by the main.dart startup via override
  // This provider is overridden in main.dart after initialization
  return true;
});

final puzzlesAvailableProvider = FutureProvider<bool>((ref) async {
  // Puzzle DB availability is provided by main.dart startup via override
  return true;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockfishReady = ref.watch(stockfishReadyProvider);
    final puzzlesAvailable = ref.watch(puzzlesAvailableProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.grid_on, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 20),
              Text('Chess', style: AppTextStyles.heading1),
              const SizedBox(height: 48),

              // Play with bot locally
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
                  ),
                  onPressed: stockfishReady.valueOrNull == true
                      ? () => context.push('/game/setup')
                      : null,
                  child: stockfishReady.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Play with bot locally', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16),

              // Puzzles
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: puzzlesAvailable.valueOrNull == true
                          ? AppColors.accent
                          : AppColors.divider,
                    ),
                  ),
                  onPressed: puzzlesAvailable.valueOrNull == true
                      ? () => context.push('/puzzles')
                      : null,
                  child: puzzlesAvailable.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Puzzles', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),

              // My Stats
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.divider),
                  ),
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text('My Stats', style: TextStyle(fontSize: 16)),
                  onPressed: () => context.push('/stats'),
                ),
              ),

              // Error display
              if (stockfishReady.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    'AI engine unavailable',
                    style: TextStyle(color: AppColors.errorRed, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
