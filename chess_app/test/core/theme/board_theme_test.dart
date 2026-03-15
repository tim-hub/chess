import 'package:chess_app/core/theme/board_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoardTheme', () {
    test('greenClean has correct square colors', () {
      expect(BoardTheme.greenClean.lightSquare, const Color(0xFFEEEED2));
      expect(BoardTheme.greenClean.darkSquare, const Color(0xFF769656));
      expect(BoardTheme.greenClean.key, 'greenClean');
    });

    test('classicWood has correct square colors', () {
      expect(BoardTheme.classicWood.lightSquare, const Color(0xFFF0D9B5));
      expect(BoardTheme.classicWood.darkSquare, const Color(0xFFB58863));
      expect(BoardTheme.classicWood.key, 'classicWood');
    });

    test('fromKey returns correct theme', () {
      expect(BoardTheme.fromKey('greenClean'), BoardTheme.greenClean);
      expect(BoardTheme.fromKey('classicWood'), BoardTheme.classicWood);
    });

    test('fromKey falls back to greenClean for unknown key', () {
      expect(BoardTheme.fromKey('unknown'), BoardTheme.greenClean);
    });

    test('all contains exactly 2 themes', () {
      expect(BoardTheme.all.length, 2);
    });
  });
}
