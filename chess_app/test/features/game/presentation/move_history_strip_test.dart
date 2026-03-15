import 'package:chess_app/features/game/domain/models.dart';
import 'package:chess_app/features/game/presentation/move_history_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders empty strip when no moves', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoveHistoryStrip(history: []))),
    );
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('1.'), findsNothing);
  });

  testWidgets('renders move chips for each move', (tester) async {
    const history = [
      Move(uci: 'e2e4', san: 'e4'),
      Move(uci: 'e7e5', san: 'e5'),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoveHistoryStrip(history: history))),
    );
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);
    expect(find.text('e5'), findsOneWidget);
  });

  testWidgets('latest move chip is visually distinct', (tester) async {
    const history = [
      Move(uci: 'e2e4', san: 'e4'),
      Move(uci: 'e7e5', san: 'e5'),
    ];
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoveHistoryStrip(history: history))),
    );
    // Latest chip ('e5') should be wrapped in a Container with accent color
    final containers = tester.widgetList<Container>(find.byType(Container));
    final latestChip = containers.where((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.color != null &&
          decoration.color != const Color(0xFFF0F0F0);
    });
    expect(latestChip.isNotEmpty, isTrue);
  });
}
