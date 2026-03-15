import 'package:chess_app/core/theme/board_theme.dart';

class AppSettings {
  final BoardTheme boardTheme;
  final String pieceSet;
  final bool sound;
  final bool legalHints;
  final bool coordinates;

  const AppSettings({
    this.boardTheme = BoardTheme.greenClean,
    this.pieceSet = 'cburnett',
    this.sound = true,
    this.legalHints = true,
    this.coordinates = true,
  });

  AppSettings copyWith({
    BoardTheme? boardTheme,
    String? pieceSet,
    bool? sound,
    bool? legalHints,
    bool? coordinates,
  }) =>
      AppSettings(
        boardTheme: boardTheme ?? this.boardTheme,
        pieceSet: pieceSet ?? this.pieceSet,
        sound: sound ?? this.sound,
        legalHints: legalHints ?? this.legalHints,
        coordinates: coordinates ?? this.coordinates,
      );
}
