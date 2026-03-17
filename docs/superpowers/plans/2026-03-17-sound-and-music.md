# Sound & Music Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add looping ambient background music and move/result sound effects to the chess app, with independent settings toggles for each.

**Architecture:** `AudioService` (plain Dart class, two `AudioPlayer` instances) is initialized in `main()` before `runApp` and injected via a Riverpod `Provider`. `SettingsNotifier` gains a `Ref` parameter to synchronously notify `AudioService` when toggles change. Sound triggers in `GameScreen` and `PuzzleScreen` use `ref.listen` for reactive state-driven sounds. AppSettings renames `sound` to two fields (`soundEffects`, `music`) with a migration fallback for existing users.

**Tech Stack:** Flutter/Dart, `audioplayers ^6.1.0`, Riverpod (Provider/StateNotifier), SharedPreferences

---

## Compilation Safety Order

Each task must leave the project in a compilable state. The order is:
1. pubspec + audio directory (no code changes)
2. AppSettings + SettingsNotifier rename (no Ref yet; replaces `sound` field everywhere) + settings screen UI
3. AudioService (new file; independent)
4. SettingsNotifier Ref injection + main.dart wiring (wires Tasks 2+3 together)
5. GameScreen sounds
6. PuzzleScreen sounds

---

## Chunk 1: Foundation

### Task 1: pubspec and audio asset directory

**Note — manual prerequisite (not automatable):** Before this task commits, download the following MP3 files and place them in `chess_app/assets/audio/`:
- `move.mp3` — download `Move.mp3` from `https://github.com/lichess-org/lila/tree/master/public/sound/standard`, rename to `move.mp3`
- `wrong.mp3` — download `Capture.mp3` from same directory, rename to `wrong.mp3`
- `success.mp3` — download `GenericNotify.mp3` from same directory, rename to `success.mp3`
- `music.mp3` — download an ambient track from `https://incompetech.com` (e.g. "Cipher" or "Floating Cities"), rename to `music.mp3`

If the MP3 files are not yet available, commit the directory structure only and note them as a follow-up.

**Files:**
- Modify: `chess_app/pubspec.yaml`
- Create: `chess_app/assets/audio/` directory

- [ ] **Step 1: Create audio assets directory with .gitkeep**

```bash
mkdir -p chess_app/assets/audio
touch chess_app/assets/audio/.gitkeep
```

- [ ] **Step 2: Add audioplayers to pubspec.yaml dependencies**

In `chess_app/pubspec.yaml`, under `dependencies:`, add after `flutter_svg`:

```yaml
  audioplayers: ^6.1.0
```

- [ ] **Step 3: Register assets/audio/ in pubspec.yaml**

In `chess_app/pubspec.yaml`, under the `flutter: > assets:` section, add:

```yaml
    - assets/audio/
```

The full assets block becomes:

```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/puzzles.db
    - assets/pieces/cburnett/
    - assets/pieces/merida/
    - assets/audio/
```

- [ ] **Step 4: Run flutter pub get**

```bash
cd chess_app && flutter pub get
```

Expected: resolves audioplayers and all transitive dependencies without errors. `pubspec.lock` is updated.

- [ ] **Step 5: Verify macOS entitlements (read-only check)**

Read `chess_app/macos/Runner/DebugProfile.entitlements` and `chess_app/macos/Runner/Release.entitlements`. Confirm `com.apple.security.app-sandbox` is `true` in both. No edits expected — this is a Flutter default.

- [ ] **Step 6: Run all tests to confirm no regression**

```bash
cd chess_app && flutter test
```

Expected: all tests pass (no code has changed).

- [ ] **Step 7: Commit**

```bash
cd chess_app && git add pubspec.yaml pubspec.lock assets/audio/.gitkeep
git commit -m "feat: add audioplayers dependency and register assets/audio"
```

---

### Task 2: AppSettings model + SettingsNotifier rename + settings screen UI

This task performs the `sound` → `soundEffects`+`music` rename across all files that reference it. The `SettingsNotifier` does **not** get `Ref` yet — that's Task 4. The new toggle methods are sync void and use a cached `_prefs` instance.

**Files:**
- Modify: `chess_app/lib/features/settings/domain/app_settings.dart`
- Modify: `chess_app/lib/features/settings/data/settings_repository.dart`
- Modify: `chess_app/lib/features/settings/presentation/settings_screen.dart`
- Modify: `chess_app/test/features/settings/data/settings_repository_test.dart`

- [ ] **Step 1: Write failing tests**

Replace the entire contents of `chess_app/test/features/settings/data/settings_repository_test.dart`:

```dart
import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'package:chess_app/features/settings/domain/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // load() must be called first to populate _prefs
    await container.read(settingsProvider.notifier).load();

    container.read(settingsProvider.notifier).toggleSoundEffects();
    expect(container.read(settingsProvider).soundEffects, isFalse);

    container.read(settingsProvider.notifier).toggleSoundEffects();
    expect(container.read(settingsProvider).soundEffects, isTrue);
  });

  test('toggleMusic flips state and persists', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(settingsProvider.notifier).load();

    container.read(settingsProvider.notifier).toggleMusic();
    expect(container.read(settingsProvider).music, isFalse);

    container.read(settingsProvider.notifier).toggleMusic();
    expect(container.read(settingsProvider).music, isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd chess_app && flutter test test/features/settings/data/settings_repository_test.dart -v
```

Expected: compile error or failures referencing `soundEffects`, `music`, `toggleSoundEffects`, `toggleMusic`.

- [ ] **Step 3: Update AppSettings model**

Replace the entire contents of `chess_app/lib/features/settings/domain/app_settings.dart`:

```dart
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
```

- [ ] **Step 4: Update SettingsNotifier**

Replace the entire contents of `chess_app/lib/features/settings/data/settings_repository.dart`:

```dart
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

  /// Toggles sound effects on/off. Requires [load()] to have been called first.
  void toggleSoundEffects() {
    final next = !state.soundEffects;
    state = state.copyWith(soundEffects: next);
    _prefs!.setBool('settings.sound_effects', next); // fire-and-forget
    // AudioService notification added in Task 4 (Ref injection)
  }

  /// Toggles background music on/off. Requires [load()] to have been called first.
  void toggleMusic() {
    final next = !state.music;
    state = state.copyWith(music: next);
    _prefs!.setBool('settings.music', next); // fire-and-forget
    // AudioService notification added in Task 4 (Ref injection)
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
```

- [ ] **Step 5: Update settings screen UI**

Replace the entire contents of `chess_app/lib/features/settings/presentation/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/core/theme/app_text_styles.dart';
import 'package:chess_app/core/theme/board_theme.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/game/domain/models.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final gameState = ref.watch(gameNotifierProvider);
    final showBackToHome = gameState != null && gameState.status == GameStatus.playing;

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

          // Audio Toggles
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_rounded),
            title: const Text('Sound Effects'),
            value: settings.soundEffects,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleSoundEffects(),
            activeColor: AppColors.accent,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.music_note_rounded),
            title: const Text('Music'),
            value: settings.music,
            onChanged: (_) => ref.read(settingsProvider.notifier).toggleMusic(),
            activeColor: AppColors.accent,
          ),

          const Divider(),

          // Other Toggles
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

          const Divider(),

          // Credits
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Credits'),
            subtitle: Text('Sounds: Lichess (MIT) · Music: Kevin MacLeod (CC BY 4.0)'),
          ),

          if (showBackToHome) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Back to Home'),
              subtitle: const Text('Leaves the current game without recording a result'),
              onTap: () {
                ref.read(gameNotifierProvider.notifier).clearGame();
                context.go('/');
              },
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests**

```bash
cd chess_app && flutter test test/features/settings/data/settings_repository_test.dart -v
```

Expected: all 6 tests pass.

- [ ] **Step 7: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
cd chess_app && git add lib/features/settings/domain/app_settings.dart \
  lib/features/settings/data/settings_repository.dart \
  lib/features/settings/presentation/settings_screen.dart \
  test/features/settings/data/settings_repository_test.dart
git commit -m "feat: rename sound setting to soundEffects+music, add credits tile"
```

---

### Task 3: AudioService

`AudioService` is a plain Dart class (not a `StateNotifier`) that wraps two `AudioPlayer` instances: one for looping music and one for one-shot SFX. It accepts optional `AudioPlayer` injection via a named test constructor, allowing unit tests to avoid platform channel calls.

**Files:**
- Create: `chess_app/lib/features/audio/audio_service.dart`
- Create: `chess_app/test/features/audio/audio_service_test.dart`

- [ ] **Step 1: Write failing tests**

Create `chess_app/test/features/audio/audio_service_test.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

// Fake AudioPlayer that records calls and no-ops platform methods.
class _FakeAudioPlayer extends AudioPlayer {
  final List<String> calls = [];

  @override
  Future<void> play(Source source, {double? volume, double? balance, AudioContext? ctx, Duration? position, PlayerMode? mode}) async {
    calls.add('play');
  }

  @override
  Future<void> resume() async {
    calls.add('resume');
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
  }

  @override
  Future<void> release() async {
    calls.add('release');
  }

  @override
  Future<void> setReleaseMode(ReleaseMode releaseMode) async {
    calls.add('setReleaseMode:${releaseMode.name}');
  }

  @override
  Future<void> setVolume(double volume) async {
    calls.add('setVolume:$volume');
  }

  @override
  Future<void> setSource(Source source) async {
    calls.add('setSource');
  }
}

void main() {
  group('AudioService SFX guard', () {
    late _FakeAudioPlayer fakeSfx;
    late _FakeAudioPlayer fakeMusic;
    late AudioService service;

    setUp(() {
      fakeSfx = _FakeAudioPlayer();
      fakeMusic = _FakeAudioPlayer();
      service = AudioService.withPlayers(music: fakeMusic, sfx: fakeSfx);
    });

    test('playMove is a no-op when sfx disabled', () async {
      await service.init(musicEnabled: false, sfxEnabled: false);
      fakeSfx.calls.clear();

      service.playMove();

      expect(fakeSfx.calls, isEmpty);
    });

    test('playWrong is a no-op when sfx disabled', () async {
      await service.init(musicEnabled: false, sfxEnabled: false);
      fakeSfx.calls.clear();

      service.playWrong();

      expect(fakeSfx.calls, isEmpty);
    });

    test('playSuccess is a no-op when sfx disabled', () async {
      await service.init(musicEnabled: false, sfxEnabled: false);
      fakeSfx.calls.clear();

      service.playSuccess();

      expect(fakeSfx.calls, isEmpty);
    });

    test('setSfxEnabled(false) disables sfx; setSfxEnabled(true) re-enables', () async {
      await service.init(musicEnabled: false, sfxEnabled: true);
      fakeSfx.calls.clear();

      service.setSfxEnabled(false);
      service.playMove();
      expect(fakeSfx.calls.where((c) => c == 'play'), isEmpty);

      service.setSfxEnabled(true);
      service.playMove();
      expect(fakeSfx.calls.where((c) => c == 'play'), isNotEmpty);
    });

    test('setMusicEnabled(true) calls resume on music player', () async {
      await service.init(musicEnabled: false, sfxEnabled: false);
      fakeMusic.calls.clear();

      service.setMusicEnabled(true);

      expect(fakeMusic.calls, contains('resume'));
    });

    test('setMusicEnabled(false) calls pause on music player', () async {
      await service.init(musicEnabled: true, sfxEnabled: false);
      fakeMusic.calls.clear();

      service.setMusicEnabled(false);

      expect(fakeMusic.calls, contains('pause'));
    });
  });

  group('AudioService init', () {
    test('init with musicEnabled=true plays music', () async {
      final fakeMusic = _FakeAudioPlayer();
      final fakeSfx = _FakeAudioPlayer();
      final service = AudioService.withPlayers(music: fakeMusic, sfx: fakeSfx);

      await service.init(musicEnabled: true, sfxEnabled: true);

      expect(fakeMusic.calls, contains('play'));
    });

    test('init with musicEnabled=false does not play music', () async {
      final fakeMusic = _FakeAudioPlayer();
      final fakeSfx = _FakeAudioPlayer();
      final service = AudioService.withPlayers(music: fakeMusic, sfx: fakeSfx);

      await service.init(musicEnabled: false, sfxEnabled: true);

      expect(fakeMusic.calls.where((c) => c == 'play'), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd chess_app && flutter test test/features/audio/audio_service_test.dart -v
```

Expected: compile error — `AudioService` not found.

- [ ] **Step 3: Create AudioService implementation**

Create `chess_app/lib/features/audio/audio_service.dart`:

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((_) => AudioService());

class AudioService {
  AudioService()
      : _music = AudioPlayer(),
        _sfx = AudioPlayer();

  @visibleForTesting
  AudioService.withPlayers({required AudioPlayer music, required AudioPlayer sfx})
      : _music = music,
        _sfx = sfx;

  final AudioPlayer _music;
  final AudioPlayer _sfx;
  bool _sfxEnabled = true;
  bool _musicEnabled = true;

  Future<void> init({required bool musicEnabled, required bool sfxEnabled}) async {
    _sfxEnabled = sfxEnabled;
    _musicEnabled = musicEnabled;

    // Configure music player for looping
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.4);
    if (musicEnabled) {
      await _music.play(AssetSource('audio/music.mp3'));
    }

    // Configure SFX player volume (audioplayers reuses the same player per call to play())
    await _sfx.setVolume(1.0);
  }

  void playMove() {
    if (!_sfxEnabled) return;
    _sfx.play(AssetSource('audio/move.mp3'));
  }

  void playWrong() {
    if (!_sfxEnabled) return;
    _sfx.play(AssetSource('audio/wrong.mp3'));
  }

  void playSuccess() {
    if (!_sfxEnabled) return;
    _sfx.play(AssetSource('audio/success.mp3'));
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (enabled) {
      _music.resume();
    } else {
      _music.pause();
    }
  }

  void setSfxEnabled(bool enabled) {
    _sfxEnabled = enabled;
  }

  void dispose() {
    _music.stop();
    _music.release();
    _sfx.stop();
    _sfx.release();
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd chess_app && flutter test test/features/audio/audio_service_test.dart -v
```

Expected: all 8 tests pass.

- [ ] **Step 5: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd chess_app && git add lib/features/audio/audio_service.dart \
  test/features/audio/audio_service_test.dart
git commit -m "feat: add AudioService with looping music and SFX guard logic"
```

---

### Task 4: SettingsNotifier Ref injection + main.dart wiring

This task adds `Ref` to `SettingsNotifier` so toggle methods can notify `AudioService`. It also adds a `@visibleForTesting` public named constructor `forLoading()` used in `main()` to pre-load settings without a live Ref (only `load()` is ever called on this instance — never toggle methods). Then `main.dart` is updated to initialize `AudioService` and wire all providers.

**Files:**
- Modify: `chess_app/lib/features/settings/data/settings_repository.dart`
- Modify: `chess_app/lib/main.dart`
- Modify: `chess_app/test/features/settings/data/settings_repository_test.dart`

- [ ] **Step 1: Write failing tests for AudioService notification**

In `chess_app/test/features/settings/data/settings_repository_test.dart`, add these tests at the bottom of `main()`, before the closing `}`.

First add the import at the top of the file:
```dart
import 'package:chess_app/features/audio/audio_service.dart';
```

Then add a helper class and new tests at the bottom of the file:

```dart
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

// Add these inside main() at the bottom:

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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd chess_app && flutter test test/features/settings/data/settings_repository_test.dart -v
```

Expected: failures — `audioServiceProvider` not found in AudioService import path (not yet on SettingsNotifier).

- [ ] **Step 3: Update SettingsNotifier with Ref injection**

Replace the entire contents of `chess_app/lib/features/settings/data/settings_repository.dart`:

```dart
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

  void toggleSoundEffects() {
    assert(_ref != null, 'toggleSoundEffects() must not be called on a forLoading() instance');
    final next = !state.soundEffects;
    state = state.copyWith(soundEffects: next);
    _prefs!.setBool('settings.sound_effects', next); // fire-and-forget
    _ref!.read(audioServiceProvider).setSfxEnabled(next);
  }

  void toggleMusic() {
    assert(_ref != null, 'toggleMusic() must not be called on a forLoading() instance');
    final next = !state.music;
    state = state.copyWith(music: next);
    _prefs!.setBool('settings.music', next); // fire-and-forget
    _ref!.read(audioServiceProvider).setMusicEnabled(next);
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
```

- [ ] **Step 4: Update main.dart**

Replace the entire contents of `chess_app/lib/main.dart`:

```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/core/router/app_router.dart';
import 'package:chess_app/core/theme/app_colors.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import 'package:chess_app/features/game/data/chess_repository_impl.dart';
import 'package:chess_app/features/game/data/game_persistence_service.dart';
import 'package:chess_app/features/game/data/minimax_engine.dart';
import 'package:chess_app/features/game/data/stockfish_service.dart';
import 'package:chess_app/features/game/domain/chess_engine.dart';
import 'package:chess_app/features/puzzles/data/credits_service.dart';
import 'package:chess_app/features/stats/data/stats_service.dart';
import 'package:chess_app/features/game/domain/game_notifier.dart';
import 'package:chess_app/features/home/presentation/home_screen.dart';
import 'package:chess_app/features/puzzles/data/puzzle_database.dart';
import 'package:chess_app/features/puzzles/data/puzzle_repository_impl.dart';
import 'package:chess_app/features/puzzles/domain/puzzle_notifier.dart';
import 'package:chess_app/features/settings/data/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-load settings using a temporary notifier (no Ref needed for load-only).
  // ignore: invalid_use_of_visible_for_testing_member
  final settingsLoader = SettingsNotifier.forLoading();
  await settingsLoader.load();

  // Initialize AudioService with the loaded settings values.
  final audioService = AudioService();
  await audioService.init(
    musicEnabled: settingsLoader.currentSettings.music,
    sfxEnabled: settingsLoader.currentSettings.soundEffects,
  );

  // Load persisted credits
  final creditsService = CreditsService();
  await creditsService.load();

  final statsService = StatsService();
  await statsService.load();

  // Stockfish only works on iOS/Android. Use MinimaxEngine on macOS/desktop.
  ChessEngine chessEngine;
  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    final stockfish = StockfishService();
    try {
      await stockfish.initialize();
      chessEngine = stockfish;
      debugPrint('Stockfish ready');
    } catch (e) {
      debugPrint('Stockfish failed, falling back to minimax: $e');
      chessEngine = MinimaxEngine();
    }
  } else {
    chessEngine = MinimaxEngine();
    debugPrint('Using MinimaxEngine (Stockfish not supported on this platform)');
  }

  // Initialize puzzle database
  bool puzzlesAvailable = false;
  try {
    await PuzzleDatabase.getInstance();
    puzzlesAvailable = true;
  } catch (e) {
    debugPrint('Puzzle database initialization failed: $e');
  }

  // Restore saved game
  final persistenceService = GamePersistenceService();
  final savedGame = await persistenceService.restoreGame();

  // Build chess repository
  final chessRepo = ChessRepositoryImpl();

  // Restore legal moves if there's a saved game
  final restoredGame = savedGame?.copyWith(
    legalMoves: chessRepo.loadPosition(savedGame.fen).legalMoves,
  );

  runApp(
    ProviderScope(
      overrides: [
        audioServiceProvider.overrideWithValue(audioService),
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(ref, settingsLoader.currentSettings),
        ),
        creditsProvider.overrideWith((_) => creditsService),
        statsProvider.overrideWith((_) => statsService),
        gameRepositoryProvider.overrideWithValue(chessRepo),
        chessEngineProvider.overrideWithValue(chessEngine),
        puzzleRepositoryProvider.overrideWithValue(PuzzleRepositoryImpl()),
        stockfishReadyProvider.overrideWith(
          (ref) async => true,
        ),
        puzzlesAvailableProvider.overrideWith(
          (ref) async => puzzlesAvailable,
        ),
        gameNotifierProvider.overrideWith((ref) {
          final notifier = GameNotifier(ref);
          if (restoredGame != null) {
            notifier.restoreState(restoredGame);
          }
          return notifier;
        }),
      ],
      child: const ChessApp(),
    ),
  );
}

class ChessApp extends ConsumerWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Chess',
      routerConfig: router,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          surface: AppColors.background,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

**Note:** `SettingsNotifier.forLoading()` is annotated `@visibleForTesting`. The `// ignore` comment in `main.dart` is intentional — this is the one legitimate non-test call site. The annotation documents that other callers should use the `Ref`-accepting constructor.

- [ ] **Step 5: Run tests**

```bash
cd chess_app && flutter test test/features/settings/data/settings_repository_test.dart -v
```

Expected: all tests pass (6 original + 2 new AudioService notification tests = 8 total).

- [ ] **Step 6: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
cd chess_app && git add lib/features/settings/data/settings_repository.dart \
  lib/main.dart \
  test/features/settings/data/settings_repository_test.dart
git commit -m "feat: wire AudioService into SettingsNotifier and main.dart"
```

---

## Chunk 2: Sound Triggers

### Task 5: GameScreen sound triggers

The `GameScreen` needs two types of sound integration:
1. **Direct call** — `playMove()` immediately after `applyPlayerMove()` in `_onSquareTap` (the player knows the move was accepted when this line returns)
2. **Reactive listener** — `ref.listen(gameNotifierProvider, ...)` to detect AI move completion and game-over transitions

**Files:**
- Modify: `chess_app/lib/features/game/presentation/game_screen.dart`

- [ ] **Step 1: Read game_screen.dart to find insertion points**

Read `chess_app/lib/features/game/presentation/game_screen.dart` fully before editing. Key locations:
- `_onSquareTap`: line ~181 has `await ref.read(gameNotifierProvider.notifier).applyPlayerMove(uciMove);` — add `playMove()` **after** this line
- `build()`: the start of the build method — add `ref.listen(...)` call here, after the existing `ref.watch` calls

- [ ] **Step 2: Add audioservice import to game_screen.dart**

At the top of `chess_app/lib/features/game/presentation/game_screen.dart`, add this import after the existing imports:

```dart
import 'package:chess_app/features/audio/audio_service.dart';
```

- [ ] **Step 3: Add playMove() after applyPlayerMove in _onSquareTap**

Find the line:
```dart
      await ref.read(gameNotifierProvider.notifier).applyPlayerMove(uciMove);
```

Replace it with:
```dart
      await ref.read(gameNotifierProvider.notifier).applyPlayerMove(uciMove);
      ref.read(audioServiceProvider).playMove();
```

- [ ] **Step 4: Add ref.listen in build()**

In the `build()` method of `_GameScreenState`, immediately after `final settings = ref.watch(settingsProvider);`, add the following listener:

```dart
    ref.listen<GameState?>(gameNotifierProvider, (prev, next) {
      if (prev == null || next == null) return;
      final audio = ref.read(audioServiceProvider);

      // AI move completed (only when game is still playing to avoid
      // double-firing when AI delivers checkmate — checkmate branch fires instead)
      if (prev.isAiThinking && !next.isAiThinking && next.status == GameStatus.playing) {
        audio.playMove();
        return;
      }

      // Game-over transitions
      if (prev.status == GameStatus.playing && next.status == GameStatus.checkmate) {
        // After checkmate, FEN active color is the LOSER (the side that can't move).
        // So the winner is the opposite color.
        final fenActive = next.fen.split(' ')[1];
        final winnerColor = fenActive == 'w' ? Side.black : Side.white;
        if (winnerColor == next.playerColor) {
          audio.playSuccess();
        } else {
          audio.playWrong();
        }
        return;
      }

      if (prev.status == GameStatus.playing && next.status == GameStatus.resigned) {
        audio.playWrong();
        return;
      }

      // stalemate → no sound
    });
```

- [ ] **Step 5: Verify Side import**

Ensure `package:chess_app/features/game/domain/models.dart` is imported (it contains `Side`). It should already be imported in game_screen.dart. If not, add:

```dart
import 'package:chess_app/features/game/domain/models.dart';
```

- [ ] **Step 6: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all tests pass. (GameScreen sound triggers are UI-layer changes; no new unit tests needed.)

- [ ] **Step 7: Commit**

```bash
cd chess_app && git add lib/features/game/presentation/game_screen.dart
git commit -m "feat: add sound triggers to GameScreen"
```

---

### Task 6: PuzzleScreen sound triggers

`PuzzleScreen` needs:
1. **Reactive listener** — `ref.listen(puzzleNotifierProvider, ...)` for move accepted and wrong move sounds
2. **Direct call** — `playSuccess()` added inside `_onPuzzleSolved()` which already exists

**Files:**
- Modify: `chess_app/lib/features/puzzles/presentation/puzzle_screen.dart`

- [ ] **Step 1: Add audioservice import**

At the top of `chess_app/lib/features/puzzles/presentation/puzzle_screen.dart`, add this import after the existing imports:

```dart
import 'package:chess_app/features/audio/audio_service.dart';
```

- [ ] **Step 2: Add playSuccess() to _onPuzzleSolved()**

Find the `_onPuzzleSolved()` method:

```dart
  void _onPuzzleSolved() {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null) return;

    // 10 credits base − 2 per hint, minimum 0
    final earned = (10 - session.hintCount * 2).clamp(0, 10);
    ref.read(creditsProvider.notifier).add(earned);

    _showSolvedBanner(earned);
  }
```

Replace it with:

```dart
  void _onPuzzleSolved() {
    final session = ref.read(puzzleNotifierProvider);
    if (session == null) return;

    ref.read(audioServiceProvider).playSuccess();

    // 10 credits base − 2 per hint, minimum 0
    final earned = (10 - session.hintCount * 2).clamp(0, 10);
    ref.read(creditsProvider.notifier).add(earned);

    _showSolvedBanner(earned);
  }
```

- [ ] **Step 3: Add ref.listen in build()**

In the `build()` method of `_PuzzleScreenState`, immediately after `final settings = ref.watch(settingsProvider);` (around line 158 of the original file), add:

```dart
    ref.listen<PuzzleSession?>(puzzleNotifierProvider, (prev, next) {
      if (prev == null || next == null) return;
      final audio = ref.read(audioServiceProvider);

      // Correct move accepted (FEN changed, not failed, not yet complete —
      // complete is handled separately in _onPuzzleSolved to avoid double-firing)
      if (!next.isFailed && !next.isComplete && next.currentFen != prev.currentFen) {
        audio.playMove();
        return;
      }

      // Wrong move
      if (!prev.isFailed && next.isFailed) {
        audio.playWrong();
        return;
      }
    });
```

- [ ] **Step 4: Verify PuzzleSession import**

`PuzzleSession` should already be available via the `puzzleNotifierProvider` import. Check that `package:chess_app/features/puzzles/domain/puzzle_notifier.dart` is imported (it exports `PuzzleSession`). It should already be present.

- [ ] **Step 5: Run full test suite**

```bash
cd chess_app && flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd chess_app && git add lib/features/puzzles/presentation/puzzle_screen.dart
git commit -m "feat: add sound triggers to PuzzleScreen"
```

---

## Post-Implementation Checklist

After all 6 tasks complete:

- [ ] Download the 4 required MP3 files (see Task 1 note) and place in `chess_app/assets/audio/` if not already done
- [ ] Run `flutter test` — all tests pass
- [ ] Launch app on device/simulator — confirm music starts at app launch
- [ ] Test Settings → toggle Sound Effects off → make a move → no sound
- [ ] Test Settings → toggle Music off → music stops
- [ ] Test puzzle wrong move → wrong sound plays
- [ ] Test puzzle solved → success sound plays
- [ ] Test game checkmate → correct sound (success or wrong based on who won)
