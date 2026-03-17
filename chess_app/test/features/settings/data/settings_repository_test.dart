import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'package:chess_app/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

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

  test('load prefers sound_effects over legacy sound key when both present', () async {
    SharedPreferences.setMockInitialValues({
      'settings.sound_effects': true,
      'settings.sound': false, // legacy disagrees — new key must win
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).load();

    expect(container.read(settingsProvider).soundEffects, isTrue);
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
    final container = ProviderContainer(overrides: [
      audioServiceProvider.overrideWithValue(_FakeAudioService()),
    ]);
    addTearDown(container.dispose);

    // load() must be called first to populate _prefsCompleter (or lazy init handles it)
    await container.read(settingsProvider.notifier).load();

    container.read(settingsProvider.notifier).toggleSoundEffects();
    expect(container.read(settingsProvider).soundEffects, isFalse);

    // Wait for the fire-and-forget persist to complete
    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.sound_effects'), isFalse);

    container.read(settingsProvider.notifier).toggleSoundEffects();
    expect(container.read(settingsProvider).soundEffects, isTrue);

    // Wait for the second fire-and-forget persist to complete
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getBool('settings.sound_effects'), isTrue);
  });

  test('toggleMusic flips state and persists', () async {
    final container = ProviderContainer(overrides: [
      audioServiceProvider.overrideWithValue(_FakeAudioService()),
    ]);
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).load();

    container.read(settingsProvider.notifier).toggleMusic();
    expect(container.read(settingsProvider).music, isFalse);

    await Future<void>.delayed(Duration.zero);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.music'), isFalse);

    container.read(settingsProvider.notifier).toggleMusic();
    expect(container.read(settingsProvider).music, isTrue);

    // Wait for the second fire-and-forget persist to complete
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getBool('settings.music'), isTrue);
  });

  group('toggle AudioService notifications', () {
    late _FakeAudioService fakeAudio;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fakeAudio = _FakeAudioService();
    });

    test('toggleSoundEffects notifies AudioService', () async {
      final container = ProviderContainer(overrides: [
        audioServiceProvider.overrideWithValue(fakeAudio),
      ]);
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).load();
      container.read(settingsProvider.notifier).toggleSoundEffects();

      expect(fakeAudio.calls, contains('setSfxEnabled:false'));
    });

    test('toggleMusic notifies AudioService', () async {
      final container = ProviderContainer(overrides: [
        audioServiceProvider.overrideWithValue(fakeAudio),
      ]);
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).load();
      container.read(settingsProvider.notifier).toggleMusic();

      expect(fakeAudio.calls, contains('setMusicEnabled:false'));
    });
  });
}

// Fake AudioService for testing toggle notifications
class _FakeAudioService implements AudioService {
  final List<String> calls = [];

  @override
  Future<void> init({required bool musicEnabled, required bool sfxEnabled}) async {}
  @override
  void playMove() {}
  @override
  void playWrong() {}
  @override
  void playSuccess() {}
  @override
  void setMusicEnabled(bool enabled) => calls.add('setMusicEnabled:$enabled');
  @override
  void setSfxEnabled(bool enabled) => calls.add('setSfxEnabled:$enabled');
  @override
  void dispose() {}
}
