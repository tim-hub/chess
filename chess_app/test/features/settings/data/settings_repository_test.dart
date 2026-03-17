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
    expect(settings.soundEffects, isTrue);
    expect(settings.music, isTrue);
    expect(settings.legalHints, isTrue);
    expect(settings.coordinates, isTrue);
  });

  test('load migrates legacy settings.sound key to soundEffects', () async {
    SharedPreferences.setMockInitialValues({'settings.sound': false});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).load();

    expect(container.read(settingsProvider).soundEffects, isFalse);
    expect(container.read(settingsProvider).music, isTrue);
  });

  test('load reads settings.sound_effects key when present', () async {
    SharedPreferences.setMockInitialValues({
      'settings.sound_effects': false,
      'settings.music': false,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).load();

    expect(container.read(settingsProvider).soundEffects, isFalse);
    expect(container.read(settingsProvider).music, isFalse);
  });

  test('updateBoardTheme persists and updates state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).updateBoardTheme(BoardTheme.classicWood);
    expect(container.read(settingsProvider).boardTheme, BoardTheme.classicWood);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.boardTheme'), 'classicWood');
  });

  test('toggleSoundEffects flips state and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // load() must be called first to populate _prefs
    await container.read(settingsProvider.notifier).load();

    container.read(settingsProvider.notifier).toggleSoundEffects();
    expect(container.read(settingsProvider).soundEffects, isFalse);

    container.read(settingsProvider.notifier).toggleSoundEffects();
    expect(container.read(settingsProvider).soundEffects, isTrue);
  });

  test('toggleMusic flips state and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).load();

    container.read(settingsProvider.notifier).toggleMusic();
    expect(container.read(settingsProvider).music, isFalse);

    container.read(settingsProvider.notifier).toggleMusic();
    expect(container.read(settingsProvider).music, isTrue);
  });
}
