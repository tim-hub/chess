import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:chess_app/features/audio/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Minimal fake platform implementations so AudioPlayer doesn't hit native
// channels in unit tests.
// ---------------------------------------------------------------------------

class _FakeGlobalPlatform extends GlobalAudioplayersPlatformInterface {
  final StreamController<GlobalAudioEvent> _ctrl =
      StreamController<GlobalAudioEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => _ctrl.stream;
}

class _FakePlayerPlatform extends AudioplayersPlatformInterface {
  /// Tracks every (playerId, method) pair that was called.
  final List<String> methodLog = [];

  final Map<String, StreamController<AudioEvent>> _streams = {};

  StreamController<AudioEvent> _streamFor(String id) =>
      _streams.putIfAbsent(id, () => StreamController<AudioEvent>.broadcast());

  @override
  Future<void> create(String playerId) async {
    methodLog.add('$playerId:create');
    _streamFor(playerId); // ensure exists
  }

  @override
  Future<void> dispose(String playerId) async {
    methodLog.add('$playerId:dispose');
    await _streams[playerId]?.close();
  }

  @override
  Future<void> resume(String playerId) async {
    methodLog.add('$playerId:resume');
  }

  @override
  Future<void> pause(String playerId) async {
    methodLog.add('$playerId:pause');
  }

  @override
  Future<void> stop(String playerId) async {
    methodLog.add('$playerId:stop');
  }

  @override
  Future<void> release(String playerId) async {
    methodLog.add('$playerId:release');
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {
    methodLog.add('$playerId:setVolume');
  }

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode mode) async {
    methodLog.add('$playerId:setReleaseMode:${mode.name}');
  }

  @override
  Future<void> setSource(String playerId, Source source) async {
    methodLog.add('$playerId:setSource');
    _streamFor(playerId).add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceUrl(String playerId, String url, {bool? isLocal, String? mimeType}) async {
    methodLog.add('$playerId:setSourceUrl');
    _streamFor(playerId).add(
      const AudioEvent(eventType: AudioEventType.prepared, isPrepared: true),
    );
  }

  @override
  Future<void> setSourceBytes(String playerId, Uint8List bytes, {String? mimeType}) async {
    methodLog.add('$playerId:setSourceBytes');
  }

  @override
  Future<void> seek(String playerId, Duration position) async {
    methodLog.add('$playerId:seek');
  }

  @override
  Future<void> setBalance(String playerId, double balance) async {
    methodLog.add('$playerId:setBalance');
  }

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {
    methodLog.add('$playerId:setPlaybackRate');
  }

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {
    methodLog.add('$playerId:setPlayerMode');
  }

  @override
  Future<void> setAudioContext(String playerId, AudioContext audioContext) async {
    methodLog.add('$playerId:setAudioContext');
  }

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) {
    methodLog.add('$playerId:getEventStream');
    return _streamFor(playerId).stream;
  }

  // Helper: filter log to just method parts for a given player id.
  Iterable<String> methodsFor(String id) =>
      methodLog.where((e) => e.startsWith('$id:')).map((e) => e.substring(id.length + 1));

  // Helper: filter to just method names (across all player ids).
  Iterable<String> get methods => methodLog.map((e) => e.split(':').skip(1).join(':'));
}

// ---------------------------------------------------------------------------
// Helper: waits for AudioPlayer creation to complete.
// ---------------------------------------------------------------------------
Future<AudioPlayer> _createPlayer({String? playerId}) async {
  final p = playerId != null ? AudioPlayer(playerId: playerId) : AudioPlayer();
  p.positionUpdater = null;
  await p.creatingCompleter.future;
  return p;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock path_provider so AssetSource resolution doesn't hit native.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async {
      if (call.method == 'getTemporaryDirectory') return '/tmp';
      if (call.method == 'getApplicationDocumentsDirectory') return '/tmp';
      return null;
    },
  );

  // Mock flutter/assets so loadAsset('assets/audio/...') returns empty bytes.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    // Return minimal valid byte data (1 silent byte) for any asset request.
    return ByteData(1);
  });

  // Register the fake global platform once for all tests.
  GlobalAudioplayersPlatformInterface.instance = _FakeGlobalPlatform();

  late _FakePlayerPlatform platform;

  setUp(() {
    platform = _FakePlayerPlatform();
    AudioplayersPlatformInterface.instance = platform;
  });

  // -------------------------------------------------------------------------
  // Build two AudioPlayers, wire them into AudioService.withPlayers, and run
  // init so we know a music player id and sfx player id.
  // -------------------------------------------------------------------------
  Future<({AudioService service, String musicId, String sfxId})> _build({
    bool music = false,
    bool sfx = true,
  }) async {
    final musicPlayer = await _createPlayer(playerId: 'music');
    final sfxPlayer   = await _createPlayer(playerId: 'sfx');
    final service = AudioService.withPlayers(music: musicPlayer, sfx: sfxPlayer);
    platform.methodLog.clear(); // ignore creation noise
    await service.init(musicEnabled: music, sfxEnabled: sfx);
    return (service: service, musicId: 'music', sfxId: 'sfx');
  }

  group('AudioService SFX guard', () {
    test('playMove is a no-op when sfx disabled', () async {
      final r = await _build(sfx: false);
      platform.methodLog.clear();

      r.service.playMove();

      expect(platform.methodsFor(r.sfxId).where((m) => m.startsWith('set') || m == 'resume' || m == 'play' || m == 'setSourceUrl'), isEmpty);
    });

    test('playWrong is a no-op when sfx disabled', () async {
      final r = await _build(sfx: false);
      platform.methodLog.clear();

      r.service.playWrong();

      expect(platform.methodsFor(r.sfxId).where((m) => m == 'setSourceUrl' || m == 'resume'), isEmpty);
    });

    test('playSuccess is a no-op when sfx disabled', () async {
      final r = await _build(sfx: false);
      platform.methodLog.clear();

      r.service.playSuccess();

      expect(platform.methodsFor(r.sfxId).where((m) => m == 'setSourceUrl' || m == 'resume'), isEmpty);
    });

    test('setSfxEnabled(false) disables sfx; setSfxEnabled(true) re-enables', () async {
      final r = await _build(sfx: true);
      platform.methodLog.clear();

      r.service.setSfxEnabled(false);
      r.service.playMove();
      // sfx player should have received nothing after disable
      expect(platform.methodsFor(r.sfxId).where((m) => m == 'setSourceUrl' || m == 'resume'), isEmpty);

      // re-enable; next playMove should reach the platform
      r.service.setSfxEnabled(true);
      r.service.playMove();
      await pumpEventQueue(times: 100); // let async asset-loading calls settle
      expect(platform.methodsFor(r.sfxId).where((m) => m == 'setSourceUrl' || m == 'resume'), isNotEmpty);
    });

    test('setMusicEnabled(true) calls resume on music player', () async {
      final r = await _build(music: false);
      platform.methodLog.clear();

      r.service.setMusicEnabled(true);
      await Future<void>.delayed(Duration.zero);

      expect(platform.methodsFor(r.musicId), contains('resume'));
    });

    test('setMusicEnabled(false) calls pause on music player', () async {
      final r = await _build(music: true);
      platform.methodLog.clear();

      r.service.setMusicEnabled(false);
      await Future<void>.delayed(Duration.zero);

      expect(platform.methodsFor(r.musicId), contains('pause'));
    });
  });

  group('AudioService init', () {
    test('init with musicEnabled=true plays music', () async {
      final musicPlayer = await _createPlayer(playerId: 'music2');
      final sfxPlayer   = await _createPlayer(playerId: 'sfx2');
      final service = AudioService.withPlayers(music: musicPlayer, sfx: sfxPlayer);
      platform.methodLog.clear();

      await service.init(musicEnabled: true, sfxEnabled: true);

      // play() routes through setSourceUrl then resume on the platform
      expect(
        platform.methodsFor('music2').where((m) => m == 'setSourceUrl' || m == 'resume'),
        isNotEmpty,
      );
    });

    test('init with musicEnabled=false does not play music', () async {
      final musicPlayer = await _createPlayer(playerId: 'music3');
      final sfxPlayer   = await _createPlayer(playerId: 'sfx3');
      final service = AudioService.withPlayers(music: musicPlayer, sfx: sfxPlayer);
      platform.methodLog.clear();

      await service.init(musicEnabled: false, sfxEnabled: true);

      expect(
        platform.methodsFor('music3').where((m) => m == 'setSourceUrl' || m == 'resume'),
        isEmpty,
      );
    });
  });
}
