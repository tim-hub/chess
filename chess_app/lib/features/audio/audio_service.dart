import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(service.dispose);
  return service;
});

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
  bool _musicStarted = false;

  Future<void> init({required bool musicEnabled, required bool sfxEnabled}) async {
    _sfxEnabled = sfxEnabled;
    _musicEnabled = musicEnabled;

    // Music player: request long-term audio focus so it owns the stream.
    await _music.setAudioContext(AudioContext(
      android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.gain),
    ));
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.setVolume(0.4);
    if (musicEnabled) {
      _musicStarted = true;
      _music.play(AssetSource('audio/music.mp3')).catchError((_) {});
    }

    // SFX player: request no audio focus so it never interrupts the music.
    await _sfx.setAudioContext(AudioContext(
      android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    ));
    await _sfx.setVolume(1.0);
    // Preload the first SFX source so playback is instant on first trigger
    await _sfx.setSource(AssetSource('audio/move.mp3'));
  }

  void playMove() {
    if (!_sfxEnabled) return;
    _sfx.play(AssetSource('audio/move.mp3')).catchError((_) {});
  }

  void playWrong() {
    if (!_sfxEnabled) return;
    _sfx.play(AssetSource('audio/wrong.mp3')).catchError((_) {});
  }

  void playSuccess() {
    if (!_sfxEnabled) return;
    _sfx.play(AssetSource('audio/success.mp3')).catchError((_) {});
  }

  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (enabled) {
      if (_musicStarted) {
        _music.resume().catchError((_) {});
      } else {
        _musicStarted = true;
        _music.play(AssetSource('audio/music.mp3')).catchError((_) {});
      }
    } else {
      _music.pause().catchError((_) {});
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
