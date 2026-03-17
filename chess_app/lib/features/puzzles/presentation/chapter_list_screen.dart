import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/puzzles/domain/chapter_notifier.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_chapter.dart';

class ChapterListScreen extends ConsumerStatefulWidget {
  const ChapterListScreen({super.key});

  @override
  ConsumerState<ChapterListScreen> createState() => _ChapterListScreenState();
}

class _ChapterListScreenState extends ConsumerState<ChapterListScreen> {
  @override
  void initState() {
    super.initState();
    // Load chapters once when the screen is first created.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chapterNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapters = ref.watch(chapterNotifierProvider);
    final credits = ref.watch(creditsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Puzzles'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Chip(
              avatar: const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
              label: Text(
                '$credits',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              backgroundColor: const Color(0xFFFEF3C7),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: chapters.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: chapters.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final prevChapterName =
                    index > 0 ? chapters[index - 1].name : null;
                return _ChapterCard(
                  chapter: chapter,
                  prevChapterName: prevChapterName,
                  onTap: () => _onChapterTap(chapter, index),
                );
              },
            ),
    );
  }

  void _onChapterTap(PuzzleChapter chapter, int index) {
    if (!chapter.isUnlocked) {
      final chapters = ref.read(chapterNotifierProvider);
      final prevName = index > 0 ? chapters[index - 1].name : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            prevName != null
                ? 'Earn 1★ in $prevName to unlock'
                : 'Complete previous chapter to unlock',
          ),
        ),
      );
      return;
    }

    if (chapter.puzzleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No puzzles available in this chapter yet')),
      );
      return;
    }

    final notifier = ref.read(chapterNotifierProvider.notifier);

    // Compute next unsolved puzzle directly from the chapter object so we
    // never silently fail if the notifier's state lookup returns null.
    String puzzleId = chapter.puzzleIds.first; // fallback: replay from first
    for (final id in chapter.puzzleIds) {
      if (!notifier.isSolved(chapter.id, id)) {
        puzzleId = id;
        break;
      }
    }

    context.push(
      '/puzzles/play/$puzzleId',
      extra: {'chapterId': chapter.id},
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final PuzzleChapter chapter;
  final String? prevChapterName;
  final VoidCallback onTap;

  const _ChapterCard({
    required this.chapter,
    required this.prevChapterName,
    required this.onTap,
  });

  Color get _borderColor {
    if (!chapter.isUnlocked) return const Color(0xFF334155);
    if (chapter.starCount == 3) return AppColors.successGreen;
    if (chapter.solvedCount > 0) return const Color(0xFF3B82F6);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = !chapter.isUnlocked;

    return Opacity(
      opacity: isLocked ? 0.55 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: _borderColor, width: 4)),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(chapter.icon, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chapter.name,
                            style: TextStyle(
                              color: isLocked
                                  ? const Color(0xFF64748B)
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isLocked) _StarRow(starCount: chapter.starCount),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (!isLocked) ...[
                      LinearProgressIndicator(
                        value: chapter.totalCount == 0
                            ? 0
                            : chapter.solvedCount / chapter.totalCount,
                        backgroundColor: const Color(0xFF0F172A),
                        color: _borderColor,
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 6,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _subtitleText(),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                    ] else ...[
                      Text(
                        prevChapterName != null
                            ? 'Earn 1★ in $prevChapterName to unlock'
                            : 'Locked',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleText() {
    if (chapter.totalCount == 0) return '0 / 0 solved';
    if (chapter.starCount == 3) {
      return '${chapter.solvedCount} / ${chapter.totalCount} solved';
    }
    final nextStar = chapter.starCount + 1;
    final threshold = nextStar == 1 ? 0.50 : nextStar == 2 ? 0.75 : 1.0;
    final needed = (threshold * chapter.totalCount).ceil();
    if (chapter.solvedCount > 0) {
      return '${chapter.solvedCount} / ${chapter.totalCount} solved · $nextStar★ at $needed';
    }
    return '0 / ${chapter.totalCount} solved · unlocked';
  }
}

class _StarRow extends StatelessWidget {
  final int starCount;

  const _StarRow({required this.starCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Icon(
          i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: i < starCount
              ? const Color(0xFFFBBF24)
              : const Color(0xFF334155),
        ),
      ),
    );
  }
}
