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

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppSettings(
      boardTheme: BoardTheme.fromKey(
        prefs.getString('settings.boardTheme') ?? 'greenClean',
      ),
      pieceSet: prefs.getString('settings.pieceSet') ?? 'cburnett',
      sound: prefs.getBool('settings.sound') ?? true,
      legalHints: prefs.getBool('settings.legalHints') ?? true,
      coordinates: prefs.getBool('settings.coordinates') ?? true,
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

  Future<void> toggleSound() async {
    state = state.copyWith(sound: !state.sound);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.sound', state.sound);
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
