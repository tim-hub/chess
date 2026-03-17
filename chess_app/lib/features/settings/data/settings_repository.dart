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

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      boardTheme: BoardTheme.fromKey(
        _prefs!.getString('settings.boardTheme') ?? 'greenClean',
      ),
      pieceSet: _prefs!.getString('settings.pieceSet') ?? 'cburnett',
      soundEffects: _prefs!.getBool('settings.sound_effects')
          ?? _prefs!.getBool('settings.sound') // legacy migration
          ?? true,
      music: _prefs!.getBool('settings.music') ?? true,
      legalHints: _prefs!.getBool('settings.legalHints') ?? true,
      coordinates: _prefs!.getBool('settings.coordinates') ?? true,
    );
  }

  Future<void> updateBoardTheme(BoardTheme theme) async {
    state = state.copyWith(boardTheme: theme);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings.boardTheme', theme.key);
  }

  Future<void> updatePieceSet(String pieceSet) async {
    state = state.copyWith(pieceSet: pieceSet);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings.pieceSet', pieceSet);
  }

  /// Toggles sound effects on/off.
  void toggleSoundEffects() {
    final next = !state.soundEffects;
    state = state.copyWith(soundEffects: next);
    _persistBool('settings.sound_effects', next); // fire-and-forget
    // AudioService notification added in Task 4 (Ref injection)
  }

  /// Toggles background music on/off.
  void toggleMusic() {
    final next = !state.music;
    state = state.copyWith(music: next);
    _persistBool('settings.music', next); // fire-and-forget
    // AudioService notification added in Task 4 (Ref injection)
  }

  Future<void> _persistBool(String key, bool value) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(key, value);
  }

  Future<void> toggleLegalHints() async {
    state = state.copyWith(legalHints: !state.legalHints);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.legalHints', state.legalHints);
  }

  Future<void> toggleCoordinates() async {
    state = state.copyWith(coordinates: !state.coordinates);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.coordinates', state.coordinates);
  }
}
