import 'package:flutter/material.dart';

class SquareWidget extends StatelessWidget {
  final String square;
  final Color color;
  final VoidCallback onTap;

  const SquareWidget({
    super.key,
    required this.square,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(color: color),
    );
  }
}
