import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/core/theme/board_theme.dart';
import '../domain/app_settings.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier([super.initial = const AppSettings()]);

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

  /// Toggles sound effects on/off.
  void toggleSoundEffects() {
    final next = !state.soundEffects;
    state = state.copyWith(soundEffects: next);
    _persistBool('settings.sound_effects', next)
        .catchError((_) {}); // persist failure is non-fatal; state already updated
    // AudioService notification added in Task 4 (Ref injection)
  }

  /// Toggles background music on/off.
  void toggleMusic() {
    final next = !state.music;
    state = state.copyWith(music: next);
    _persistBool('settings.music', next)
        .catchError((_) {}); // persist failure is non-fatal; state already updated
    // AudioService notification added in Task 4 (Ref injection)
  }

  Future<void> _persistBool(String key, bool value) async {
    _prefsCompleter ??= SharedPreferences.getInstance();
    final prefs = await _prefsCompleter!;
    await prefs.setBool(key, value);
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
}
