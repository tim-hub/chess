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

`audioplayers` supports iOS, Android, macOS, Web, Linux, Windows. No special platform entitlements are required for playback from bundled assets on macOS.

---

## 3. AudioService

### New file: `lib/features/audio/audio_service.dart`

```dart
final audioServiceProvider = Provider<AudioService>((_) => AudioService());
```

`AudioService` is a plain Dart class (not a StateNotifier). No reactive state is exposed — callers invoke methods directly.

### API

```dart
class AudioService {
  Future<void> init({required bool musicEnabled, required bool sfxEnabled});

  // Sound effects — each checks _sfxEnabled internally
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
- `init()` sets `_music` to loop (`ReleaseMode.loop`), sets volume, starts playback if `musicEnabled`. Preloads sfx sources.
- `setMusicEnabled(true)` resumes/plays; `setMusicEnabled(false)` pauses.
- `setSfxEnabled` sets an internal `_sfxEnabled` flag; `play*()` methods no-op when false.
- `dispose()` stops and releases both players.

### Initialization in `main.dart`

```dart
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

### `AppSettings` model (`lib/features/settings/domain/app_settings.dart`)

Replace the existing `sound` field with two fields:

| Field | Type | Default | SharedPreferences key |
|---|---|---|---|
| `soundEffects` | `bool` | `true` | `settings.sound_effects` |
| `music` | `bool` | `true` | `settings.music` |

**Migration:** When loading, read `settings.sound_effects` first; if absent, fall back to the old `settings.sound` key so existing users keep their saved preference.

### `SettingsNotifier`

Add two methods (replacing `toggleSound()`):

```dart
void toggleSoundEffects()  // flips soundEffects, persists, calls audioService.setSfxEnabled()
void toggleMusic()         // flips music, persists, calls audioService.setMusicEnabled()
```

Both methods read `audioServiceProvider` via `_ref.read(audioServiceProvider)` to notify the service of the change.

### Settings screen UI

Replace the existing single "Sound" tile with two tiles, then add a static credits tile at the bottom:

```
🔊 Sound Effects    [switch]
🎵 Music            [switch]

── (divider) ──
ℹ️  Credits
    Sounds: Lichess (MIT) · Music: Kevin MacLeod (CC BY 4.0)
```

The credits tile is a non-interactive `ListTile` with `leading: Icon(Icons.info_outline)`, `title: Text('Credits')`, `subtitle: Text('Sounds: Lichess (MIT) · Music: Kevin MacLeod (CC BY 4.0)')`.

---

## 5. Sound Effect Trigger Points

### GameScreen (`lib/features/game/presentation/game_screen.dart`)

Use `ref.listen(gameNotifierProvider, (prev, next) { ... })` to observe state transitions:

| Transition | Sound |
|---|---|
| Player submits move (any `applyPlayerMove` call) | `playMove()` |
| `isAiThinking`: true → false, status still `playing` | `playMove()` |
| Status → `checkmate`, player is winner | `playSuccess()` |
| Status → `checkmate`, player is loser | `playWrong()` |
| Status → `resigned` | `playWrong()` |
| Status → `stalemate` | _(no sound — ambiguous)_ |

### PuzzleScreen (`lib/features/puzzles/presentation/puzzle_screen.dart`)

| Event | Sound |
|---|---|
| Move submitted and accepted (not failed, not complete) | `playMove()` |
| `session.isFailed` becomes true | `playWrong()` |
| `_onPuzzleSolved()` called | `playSuccess()` |

The `isFailed` trigger uses `ref.listen(puzzleNotifierProvider, ...)` watching for `isFailed: true` transitions.

---

## 6. Music Behaviour

- Music starts at app launch (if `music == true`) and loops continuously on all screens.
- No per-screen start/stop. Music state is entirely controlled by the Settings toggle and by `AudioService.init()`.
- Volume: music at ~40% (`0.4`), sound effects at 100% (`1.0`).

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

Existing files modified:
- `pubspec.yaml` — add `audioplayers`, add `assets/audio/`
- `lib/features/settings/domain/app_settings.dart` — replace `sound` with `soundEffects` + `music`
- `lib/features/settings/data/settings_repository.dart` — new keys + migration
- `lib/features/settings/presentation/settings_screen.dart` — new tiles + credits
- `lib/main.dart` — AudioService init + provider override
- `lib/features/game/presentation/game_screen.dart` — ref.listen for sounds
- `lib/features/puzzles/presentation/puzzle_screen.dart` — ref.listen for sounds

---

## Out of Scope

- Different sounds for move vs capture (minimal set chosen)
- Hint sound
- Per-screen music tracks
- Volume sliders (toggle only)
- Streaming music from network
