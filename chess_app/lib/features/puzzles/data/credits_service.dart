import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final creditsProvider =
    StateNotifierProvider<CreditsService, int>((_) => CreditsService());

class CreditsService extends StateNotifier<int> {
  static const _key = 'puzzle.credits';

  CreditsService() : super(0);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> add(int amount) async {
    state = state + amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, state);
  }

  Future<void> deduct(int amount) async {
    state = (state - amount).clamp(0, 9999999);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, state);
  }
}
