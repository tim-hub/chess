import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/app_settings.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());
  // Full implementation in Task 18
}
