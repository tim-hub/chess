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

    // Configure SFX player volume
    await _sfx.setVolume(1.0);
    // Preload the first SFX source so playback is instant on first trigger
    await _sfx.setSource(AssetSource('audio/move.mp3'));
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
