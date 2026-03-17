import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import '../domain/app_settings.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  /// Live constructor — receives a real [Ref] from Riverpod.
  SettingsNotifier(this._ref, [super.initial = const AppSettings()]);

  /// Used in [main()] for pre-loading before [ProviderScope] exists.
  /// Never calls toggle methods; does not need a live [Ref].
  @visibleForTesting
  SettingsNotifier.forLoading() : _ref = null, super(const AppSettings());

  final Ref? _ref;

  /// Public accessor for the current settings value (used during app startup).
  AppSettings get currentSettings => state;

  Future<SharedPreferences>? _prefsCompleter;

  Future<void> load() async {
    _prefsCompleter ??= SharedPreferences.getInstance();
    final prefs = await _prefsCompleter!;
    state = AppSettings(
      boardTheme: BoardTheme.fromKey(
        prefs.getString('settings.boardTheme') ?? 'greenClean',
      ),
      pieceSet: prefs.getString('settings.pieceSet') ?? 'cburnett',
      soundEffects: prefs.getBool('settings.sound_effects')
          ?? prefs.getBool('settings.sound') // legacy migration
          ?? true,
      music: prefs.getBool('settings.music') ?? true,
      legalHints: prefs.getBool('settings.legalHints') ?? true,
      coordinates: prefs.getBool('settings.coordinates') ?? true,
    );
  }

  Future<void> updateBoardTheme(BoardTheme theme) async {
    state = state.copyWith(boardTheme: theme);
    _prefsCompleter ??= SharedPreferences.getInstance();
    final prefs = await _prefsCompleter!;
    await prefs.setString('settings.boardTheme', theme.key);
  }

  Future<void> updatePieceSet(String pieceSet) async {
    state = state.copyWith(pieceSet: pieceSet);
    _prefsCompleter ??= SharedPreferences.getInstance();
    final prefs = await _prefsCompleter!;
    await prefs.setString('settings.pieceSet', pieceSet);
  }

  void toggleSoundEffects() {
    assert(_ref != null, 'toggleSoundEffects() must not be called on a forLoading() instance');
    final next = !state.soundEffects;
    state = state.copyWith(soundEffects: next);
    _persistBool('settings.sound_effects', next).catchError((_) {});
    _ref!.read(audioServiceProvider).setSfxEnabled(next);
  }

  void toggleMusic() {
    assert(_ref != null, 'toggleMusic() must not be called on a forLoading() instance');
    final next = !state.music;
    state = state.copyWith(music: next);
    _persistBool('settings.music', next).catchError((_) {});
    _ref!.read(audioServiceProvider).setMusicEnabled(next);
  }

  Future<void> toggleLegalHints() async {
    final next = !state.legalHints;
    state = state.copyWith(legalHints: next);
    await _persistBool('settings.legalHints', next);
  }

  Future<void> toggleCoordinates() async {
    final next = !state.coordinates;
    state = state.copyWith(coordinates: next);
    await _persistBool('settings.coordinates', next);
  }

  Future<void> _persistBool(String key, bool value) async {
    _prefsCompleter ??= SharedPreferences.getInstance();
    final prefs = await _prefsCompleter!;
    await prefs.setBool(key, value);
  }
}
