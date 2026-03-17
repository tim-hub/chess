import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final credits = ref.watch(creditsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: const Text('My Stats'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: const TabBar(
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.accent,
            tabs: [
              Tab(text: 'Games'),
              Tab(text: 'Puzzles'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GamesTab(stats: stats),
            _PuzzlesTab(stats: stats, credits: credits),
          ],
        ),
      ),
    );
  }
}

class _PuzzlesTab extends StatelessWidget {
  final StatsState stats;
  final int credits;

  const _PuzzlesTab({required this.stats, required this.credits});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
          label: 'Credits',
          value: '$credits',
          icon: Icons.star_rounded,
          iconColor: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Solved', value: '${stats.puzzlesSolved}')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Perfect', value: '${stats.perfectSolves}')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Hints Used', value: '${stats.totalHintsUsed}')),
          ],
        ),
      ],
    );
  }
}

class _GamesTab extends StatelessWidget {
  final StatsState stats;

  const _GamesTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final levels = DifficultyLevel.values;
    int totalWins = 0;
    int totalLosses = 0;
    for (final d in levels) {
      totalWins += stats.wins[d] ?? 0;
      totalLosses += stats.losses[d] ?? 0;
    }
    final total = totalWins + totalLosses;
    final overallRate = total == 0 ? null : totalWins / total;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: const [
                    Expanded(child: Text('Level', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(width: 32, child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(width: 32, child: Text('L', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    SizedBox(width: 8),
                    SizedBox(width: 48, child: Text('Win %', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...levels.map((d) {
                final w = stats.wins[d] ?? 0;
                final l = stats.losses[d] ?? 0;
                final played = w + l;
                final rate = played == 0 ? null : w / played;
                return _DifficultyRow(level: d, wins: w, losses: l, rate: rate);
              }),
              const Divider(height: 1),
              _DifficultyRow(
                label: 'Overall',
                wins: totalWins,
                losses: totalLosses,
                rate: overallRate,
                bold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final DifficultyLevel? level;
  final String? label;
  final int wins;
  final int losses;
  final double? rate;
  final bool bold;

  const _DifficultyRow({
    this.level,
    this.label,
    required this.wins,
    required this.losses,
    required this.rate,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final played = wins + losses;
    final rateText = rate == null ? '—' : '${(rate! * 100).round()}%';
    final rateColor = rate == null
        ? AppColors.textSecondary
        : rate! >= 0.6
            ? AppColors.successGreen
            : rate! >= 0.3
                ? const Color(0xFFF59E0B)
                : AppColors.errorRed;
    final name = label ?? (level != null ? _capitalize(level!.name) : '');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              played == 0 ? '—' : '$wins',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              played == 0 ? '—' : '$losses',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            child: Text(
              rateText,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: rateColor),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;

  const _StatCard({required this.label, required this.value, this.icon, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? AppColors.accent, size: 20),
            const SizedBox(height: 6),
          ],
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
