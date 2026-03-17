import 'package:chess_app/core/theme/board_theme.dart';

class AppSettings {
  final BoardTheme boardTheme;
  final String pieceSet;
  final bool soundEffects;
  final bool music;
  final bool legalHints;
  final bool coordinates;

  const AppSettings({
    this.boardTheme = BoardTheme.greenClean,
    this.pieceSet = 'cburnett',
    this.soundEffects = true,
    this.music = true,
    this.legalHints = true,
    this.coordinates = true,
  });

  AppSettings copyWith({
    BoardTheme? boardTheme,
    String? pieceSet,
    bool? soundEffects,
    bool? music,
    bool? legalHints,
    bool? coordinates,
  }) =>
      AppSettings(
        boardTheme: boardTheme ?? this.boardTheme,
        pieceSet: pieceSet ?? this.pieceSet,
        soundEffects: soundEffects ?? this.soundEffects,
        music: music ?? this.music,
        legalHints: legalHints ?? this.legalHints,
        coordinates: coordinates ?? this.coordinates,
      );
}
