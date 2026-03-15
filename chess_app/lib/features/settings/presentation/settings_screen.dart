import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/core/theme/app_text_styles.dart';
import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Board Theme
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Board Theme', style: AppTextStyles.label),
          ),
          ...BoardTheme.all.map((theme) => RadioListTile<BoardTheme>(
            title: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [theme.lightSquare, theme.darkSquare],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(theme.name),
              ],
            ),
            value: theme,
            groupValue: settings.boardTheme,
            onChanged: (t) => ref.read(settingsProvider.notifier).updateBoardTheme(t!),
            activeColor: AppColors.accent,
          )),

          const Divider(),

          // Piece Style
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Piece Style', style: AppTextStyles.label),
          ),
          ...['cburnett', 'merida'].map((set) => RadioListTile<String>(
            title: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: SvgPicture.asset('assets/pieces/$set/wK.svg'),
                ),
                const SizedBox(width: 12),
                Text(set == 'cburnett' ? 'CBurnett' : 'Merida'),
              ],
            ),
            value: set,
            groupValue: settings.pieceSet,
            onChanged: (s) => ref.read(settingsProvider.notifier).updatePieceSet(s!),
            activeColor: AppColors.accent,
          )),

          const Divider(),

          // Toggles
          SwitchListTile(
            title: const Text('Sound'),
            value: settings.sound,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleSound(),
            activeColor: AppColors.accent,
          ),
          SwitchListTile(
            title: const Text('Show legal move hints'),
            value: settings.legalHints,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleLegalHints(),
            activeColor: AppColors.accent,
          ),
          SwitchListTile(
            title: const Text('Show coordinates'),
            value: settings.coordinates,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleCoordinates(),
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }
}
