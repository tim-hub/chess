import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_text_styles.dart';
import 'package:chess_app/features/game/domain/models.dart';

/// Displays the game's move history as numbered pairs (1. e4 e5, 2. Nf3 Nc6...).
/// Auto-scrolls to the latest move.
class MoveHistoryPanel extends StatefulWidget {
  final List<Move> history;

  const MoveHistoryPanel({super.key, required this.history});

  @override
  State<MoveHistoryPanel> createState() => _MoveHistoryPanelState();
}

class _MoveHistoryPanelState extends State<MoveHistoryPanel> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.length != oldWidget.history.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movePairs = <(String, String?)>[];
    for (var i = 0; i < widget.history.length; i += 2) {
      final white = widget.history[i].san;
      final black = i + 1 < widget.history.length ? widget.history[i + 1].san : null;
      movePairs.add((white, black));
    }

    if (movePairs.isEmpty) {
      return const Center(
        child: Text('No moves yet', style: AppTextStyles.bodySecondary),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: movePairs.length,
      itemBuilder: (context, index) {
        final (white, black) = movePairs[index];
        final isLatestWhite = index == movePairs.length - 1 && black == null;
        final isLatestBlack = index == movePairs.length - 1 && black != null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text('${index + 1}.', style: AppTextStyles.bodySecondary),
              ),
              Expanded(
                child: Text(
                  white,
                  style: isLatestWhite
                      ? AppTextStyles.moveHistoryActive
                      : AppTextStyles.moveHistory,
                ),
              ),
              if (black != null)
                Expanded(
                  child: Text(
                    black,
                    style: isLatestBlack
                        ? AppTextStyles.moveHistoryActive
                        : AppTextStyles.moveHistory,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
