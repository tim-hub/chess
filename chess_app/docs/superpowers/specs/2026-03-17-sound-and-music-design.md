# Sound & Music — Design Spec

_Date: 2026-03-17_
_Status: Approved_

---

## Overview

Add ambient background music and move sound effects to the chess app. Both are independently togglable from Settings. Open-source assets only — Lichess sound effects (MIT) and a Kevin MacLeod ambient track (CC BY 4.0).

---

## 1. Audio Assets

### Files

| File | Event | Source |
|---|---|---|
| `assets/audio/move.mp3` | Piece placed on square | Lichess (MIT) |
| `assets/audio/wrong.mp3` | Wrong puzzle move / loss | Lichess (MIT) |
| `assets/audio/success.mp3` | Puzzle solved / game won | Lichess (MIT) |
| `assets/audio/music.mp3` | Ambient loop (all screens) | Kevin MacLeod (CC BY 4.0) |

### Sources

- **Lichess sounds:** `https://github.com/lichess-org/lila/tree/master/public/sound` — use files from the `standard` pack (`Move.mp3`, `Capture.mp3`, `GenericNotify.mp3` or equivalent). Rename to `move.mp3`, `wrong.mp3`, `success.mp3`.
- **Kevin MacLeod music:** `https://incompetech.com` — choose an ambient/atmospheric track (e.g. "Cipher", "Floating Cities", or similar). Download the MP3, rename to `music.mp3`.

### pubspec.yaml

Add under `flutter > assets`:

```yaml
assets:
  - assets/audio/
```

### Licenses & Attribution

- Lichess sounds: MIT License — no attribution required, but credited in app.
- Kevin MacLeod music: CC BY 4.0 — attribution **required** in app.

---

## 2. Package

Add `audioplayers: ^6.1.0` (or latest stable) to `pubspec.yaml` dependencies.

`audioplayers` supports iOS, Android, macOS, Web, Linux, Windows. No additional entitlements beyond the default macOS sandbox are required for bundled-asset playback. Verify that `macos/Runner/DebugProfile.entitlements` and `Release.entitlements` have `com.apple.security.app-sandbox` set to `true` (this is the Flutter default and should already be present).

---

## 3. AudioService

### New file: `lib/features/audio/audio_service.dart`

```dart
final audioServiceProvider = Provider<AudioService>((_) => AudioService());
```

`AudioService` is a plain Dart class (not a StateNotifier). No reactive state is exposed — callers invoke methods directly. The provider is always overridden in `ProviderScope` (see §3 main.dart snippet).

### API

```dart
class AudioService {
  Future<void> init({required bool musicEnabled, required bool sfxEnabled});

  // Sound effects — each checks _sfxEnabled internally; no-ops when false
  void playMove();
  void playWrong();
  void playSuccess();

  // Called when settings toggles change
  void setMusicEnabled(bool enabled);
  void setSfxEnabled(bool enabled);

  void dispose();
}
```

### Implementation notes

- Two `AudioPlayer` instances: `_music` (looping) and `_sfx` (one-shot).
- `init()` sets `_music` to loop (`ReleaseMode.loop`), sets volume (`0.4` for music, `1.0` for sfx), starts playback if `musicEnabled`. Preloads sfx sources via `AssetSource`.
- `setMusicEnabled(true)` resumes/plays; `setMusicEnabled(false)` pauses.
- `setSfxEnabled` sets an internal `_sfxEnabled` flag; `play*()` methods return early when false.
- `dispose()` stops and releases both players.

### Initialization in `main.dart`

**Prerequisite:** `AppSettings` model must be updated (§4) before this step compiles — `settingsNotifier.state.music` and `.soundEffects` do not exist until the model is changed.

```dart
// After settingsNotifier is loaded:
final audioService = AudioService();
await audioService.init(
  musicEnabled: settingsNotifier.state.music,
  sfxEnabled: settingsNotifier.state.soundEffects,
);

// In ProviderScope overrides:
audioServiceProvider.overrideWithValue(audioService),
```

---

## 4. Settings Changes

### Implementation order

1. Update `AppSettings` model first (required before `main.dart` compiles)
2. Update `SettingsNotifier` constructor and methods
3. Update `main.dart`
4. Update settings screen UI

### `AppSettings` model (`lib/features/settings/domain/app_settings.dart`)

Replace the existing `sound: bool` field with two fields:

| Field | Type | Default | SharedPreferences key |
|---|---|---|---|
| `soundEffects` | `bool` | `true` | `settings.sound_effects` |
| `music` | `bool` | `true` | `settings.music` |

Update `copyWith` to accept `bool? soundEffects` and `bool? music` (remove `bool? sound`).

**Migration in `load()`:** When reading `settings.sound_effects`, fall back to the old `settings.sound` key if absent:

```dart
final soundEffects = prefs.getBool('settings.sound_effects')
    ?? prefs.getBool('settings.sound')   // legacy fallback
    ?? true;
final music = prefs.getBool('settings.music') ?? true;
```

### `SettingsNotifier` (`lib/features/settings/data/settings_repository.dart`)

`SettingsNotifier` currently takes no `Ref`. Add a `Ref` parameter so it can call `audioServiceProvider`:

```dart
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._ref, [super.initial = const AppSettings()]);
  final Ref _ref;
  // ...
}
```

Update `settingsProvider` and the `main.dart` override lambda accordingly:

```dart
// provider definition (unchanged):
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref),
);
```

In `main.dart`, the existing pattern pre-loads a temporary `SettingsNotifier` to get the initial state, then creates the real one inside the override lambda where a valid `Ref` is available. Continue this pattern after adding `Ref`:

```dart
// main.dart — pre-load phase (temporary notifier, no Ref needed):
final settingsLoader = SettingsNotifier._forLoading(); // private factory, no Ref
await settingsLoader.load();

// In ProviderScope overrides:
settingsProvider.overrideWith(
  (ref) => SettingsNotifier(ref, settingsLoader.currentSettings),
),
```

`_forLoading()` is a private named constructor (or the same public constructor with an optional `Ref?` parameter that defaults to `null`). The pre-load phase only calls `load()` — it never calls `toggleSoundEffects()` or `toggleMusic()`, so no `Ref` is needed there. The override factory receives a real `Ref` from Riverpod and constructs the live instance with the pre-loaded state. `currentSettings` is a getter: `AppSettings get currentSettings => state;`.

Replace `toggleSound()` with two new methods:

```dart
void toggleSoundEffects() {
  final next = !state.soundEffects;
  state = state.copyWith(soundEffects: next);
  _prefs.setBool('settings.sound_effects', next);
  _ref.read(audioServiceProvider).setSfxEnabled(next);
}

void toggleMusic() {
  final next = !state.music;
  state = state.copyWith(music: next);
  _prefs.setBool('settings.music', next);
  _ref.read(audioServiceProvider).setMusicEnabled(next);
}
```

(`_prefs` is a `SharedPreferences` instance held by the notifier, following the existing pattern.)

### Settings screen UI

Replace the existing single "Sound" `SwitchListTile` with two tiles, then add a static credits tile at the bottom of the `ListView`:

```
🔊 Sound Effects    [switch]   → calls settingsNotifier.toggleSoundEffects()
🎵 Music            [switch]   → calls settingsNotifier.toggleMusic()

── (divider) ──
ℹ️  Credits
    Sounds: Lichess (MIT) · Music: Kevin MacLeod (CC BY 4.0)
```

The credits tile is a non-interactive `ListTile`:
```dart
ListTile(
  leading: const Icon(Icons.info_outline),
  title: const Text('Credits'),
  subtitle: const Text('Sounds: Lichess (MIT) · Music: Kevin MacLeod (CC BY 4.0)'),
)
```

---

## 5. Sound Effect Trigger Points

### GameScreen (`lib/features/game/presentation/game_screen.dart`)

Add `ref.listen(gameNotifierProvider, (prev, next) { ... })` inside `build()`. Guard every branch with `if (prev == null || next == null) return;`.

| Condition | Sound |
|---|---|
| Player submits move — call `playMove()` directly after `applyPlayerMove` in `_onSquareTap` | `playMove()` |
| `prev.isAiThinking == true && next.isAiThinking == false && next.status == GameStatus.playing` | `playMove()` |
| `prev.status == GameStatus.playing && next.status == GameStatus.checkmate` and player won | `playSuccess()` |
| `prev.status == GameStatus.playing && next.status == GameStatus.checkmate` and player lost | `playWrong()` |
| `prev.status == GameStatus.playing && next.status == GameStatus.resigned` | `playWrong()` |
| `prev.status == GameStatus.playing && next.status == GameStatus.stalemate` | _(no sound)_ |

**Important:** The AI move sound must check `next.status == GameStatus.playing` to avoid double-firing when the AI delivers checkmate (in that case the checkmate branch fires instead). The `isAiThinking` transition and the checkmate/resign/stalemate transitions are mutually exclusive via these guards.

### PuzzleScreen (`lib/features/puzzles/presentation/puzzle_screen.dart`)

Add `ref.listen(puzzleNotifierProvider, (prev, next) { ... })` inside `build()`. Guard with `if (prev == null || next == null) return;`.

| Condition | Sound |
|---|---|
| Move submitted and accepted: `next.isFailed == false && !next.isComplete && next.currentFen != prev.currentFen` | `playMove()` |
| Wrong move: `prev.isFailed == false && next.isFailed == true` | `playWrong()` |
| Puzzle solved: already handled in `_onPuzzleSolved()` callback | `playSuccess()` |

The `_onPuzzleSolved()` call already exists in `PuzzleScreen` — add `audioService.playSuccess()` there directly rather than in the listener to avoid double-firing.

---

## 6. Music Behaviour

- Music starts at app launch (if `music == true`) and loops continuously on all screens.
- No per-screen start/stop. Music state is entirely controlled by the Settings toggle and by `AudioService.init()`.
- Volume: music at 40% (`0.4`), sound effects at 100% (`1.0`).

---

## 7. File Structure

```
lib/features/audio/
  audio_service.dart       # AudioService class + audioServiceProvider
assets/audio/
  move.mp3
  wrong.mp3
  success.mp3
  music.mp3
```

Existing files modified (in recommended implementation order):
1. `pubspec.yaml` — add `audioplayers`, add `assets/audio/`
2. `lib/features/settings/domain/app_settings.dart` — replace `sound` with `soundEffects` + `music`, update `copyWith`
3. `lib/features/settings/data/settings_repository.dart` — add `Ref` param, migration in `load()`, new toggle methods
4. `lib/features/audio/audio_service.dart` — new file
5. `lib/main.dart` — AudioService init + provider override
6. `lib/features/settings/presentation/settings_screen.dart` — new tiles + credits
7. `lib/features/game/presentation/game_screen.dart` — ref.listen for sounds
8. `lib/features/puzzles/presentation/puzzle_screen.dart` — ref.listen for sounds

---

## Out of Scope

- Different sounds for move vs capture (minimal set chosen)
- Hint sound
- Per-screen music tracks
- Volume sliders (toggle only)
- Streaming music from network
