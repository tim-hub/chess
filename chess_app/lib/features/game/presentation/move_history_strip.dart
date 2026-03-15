import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/game/domain/models.dart';

/// Compact 36px-tall horizontal scrollable chip strip showing the move history.
/// Latest move is highlighted in accent green; older moves are light grey.
class MoveHistoryStrip extends StatefulWidget {
  final List<Move> history;

  const MoveHistoryStrip({super.key, required this.history});

  @override
  State<MoveHistoryStrip> createState() => _MoveHistoryStripState();
}

class _MoveHistoryStripState extends State<MoveHistoryStrip> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveHistoryStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.history.length > oldWidget.history.length) {
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
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: _buildChips(),
        ),
      ),
    );
  }

  List<Widget> _buildChips() {
    final chips = <Widget>[];
    for (var i = 0; i < widget.history.length; i += 2) {
      final moveNum = i ~/ 2 + 1;
      final whiteSan = widget.history[i].san;
      final blackSan = i + 1 < widget.history.length ? widget.history[i + 1].san : null;
      final isLatestWhite = i == widget.history.length - 1;
      final isLatestBlack = blackSan != null && i + 1 == widget.history.length - 1;

      chips.add(_NumberLabel('$moveNum.'));
      chips.add(_MoveChip(san: whiteSan, isLatest: isLatestWhite));
      if (blackSan != null) {
        chips.add(_MoveChip(san: blackSan, isLatest: isLatestBlack));
      }
    }
    return chips;
  }
}

class _NumberLabel extends StatelessWidget {
  final String text;
  const _NumberLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  final String san;
  final bool isLatest;
  const _MoveChip({required this.san, required this.isLatest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isLatest ? AppColors.accent : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        san,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
          color: isLatest ? Colors.white : const Color(0xFF333333),
        ),
      ),
    );
  }
}
