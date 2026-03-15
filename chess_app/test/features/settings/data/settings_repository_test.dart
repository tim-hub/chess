import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'package:chess_app/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('load with no stored data returns defaults', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).load();

    final settings = container.read(settingsProvider);
    expect(settings.boardTheme, BoardTheme.greenClean);
    expect(settings.pieceSet, 'cburnett');
    expect(settings.sound, isTrue);
    expect(settings.legalHints, isTrue);
    expect(settings.coordinates, isTrue);
  });

  test('updateBoardTheme persists and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).updateBoardTheme(BoardTheme.classicWood);

    expect(container.read(settingsProvider).boardTheme, BoardTheme.classicWood);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.boardTheme'), 'classicWood');
  });

  test('toggleSound updates state and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).toggleSound();
    expect(container.read(settingsProvider).sound, isFalse);

    await container.read(settingsProvider.notifier).toggleSound();
    expect(container.read(settingsProvider).sound, isTrue);
  });
}
