import 'package:flutter/material.dart';
import 'package:chess_app/core/theme/app_colors.dart';

/// Shared scaffold with consistent AppBar styling.
class ChessScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const ChessScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title),
        actions: actions,
      ),
      body: body,
    );
  }
}
