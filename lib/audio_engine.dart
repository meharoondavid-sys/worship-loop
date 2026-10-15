import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// The six independent channels available in Worship Loop.
enum AudioTrack {
  pad1,
  pad2,
  pad3,
  percussion1,
  percussion2,
  percussion3,
}

/// Owns the six audio players used by the Worship Loop mixer.
///
/// Each track has its own player, volume, source, and play/stop state.
/// Percussion playback rate can be changed as a group when the song tempo
/// changes. A rate of 1.0 is the source file's original speed.
///
/// Looping uses LoopMode.one. Truly gapless results still depend on the
/// source file's encoding and the platform decoder.
class AudioEngine {
  AudioEngine()
      : _players = {
          AudioTrack.pad1: AudioPlayer(),
          AudioTrack.pad2: AudioPlayer(),
          AudioTrack.pad3: AudioPlayer(),
          AudioTrack.percussion1: AudioPlayer(),
          AudioTrack.percussion2: AudioPlayer(),
          AudioTrack.percussion3: AudioPlayer(),
        } {
    for (final player in _players.values) {
      unawaited(_configurePlayer(player));
    }
  }

  final Map<AudioTrack, AudioPlayer> _players;

  final Map<AudioTrack, double> _volumes = {
    for (final track in AudioTrack.values) track: 1.0,
  };

  bool _disposed = false;
  double _percussionRate = 1.0;

  /// Current player for a track, useful for observing playback state.
  AudioPlayer playerFor(AudioTrack track) => _players[track]!;

  /// Current volume for [track], from 0.0 (silent) to 1.0 (full volume).
  double volumeFor(AudioTrack track) => _volumes[track]!;

  /// Current shared playback rate applied to the percussion channels.
  double get percussionPlaybackRate => _percussionRate;

  static const Set<AudioTrack> _percussionTracks = {
    AudioTrack.percussion1,
    AudioTrack.percussion2,
    AudioTrack.percussion3,
  };

  Future<void> _configurePlayer(AudioPlayer player) async {
    try {
      await player.setLoopMode(LoopMode.one);
    } catch (_) {
      // Loading or playback will surface platform errors to the caller.
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('AudioEngine has already been disposed.');
    }
  }

  /// Load an audio asset into a track and prepare it for playback.
  Future<Duration?> loadAsset(AudioTrack track, String assetPath) async {
    _ensureNotDisposed();
    final player = _players[track]!;
    final duration = await player.setAsset(assetPath);
    await player.setLoopMode(LoopMode.one);
    await player.setVolume(_volumes[track]!);
    if (_isPercussion(track)) {
      await player.setSpeed(_percussionRate);
    }
    return duration;
  }

  /// Load a local file path into a track and prepare it for playback.
  Future<Duration?> loadFile(AudioTrack track, String filePath) async {
    _ensureNotDisposed();
    final player = _players[track]!;
    final duration = await player.setFilePath(filePath);
    await player.setLoopMode(LoopMode.one);
    await player.setVolume(_volumes[track]!);
    if (_isPercussion(track)) {
      await player.setSpeed(_percussionRate);
    }
    return duration;
  }

  /// Load a URI into a track and prepare it for playback.
  Future<Duration?> loadUri(AudioTrack track, Uri uri) async {
    _ensureNotDisposed();
    final player = _players[track]!;
    final duration = await player.setAudioSource(AudioSource.uri(uri));
    await player.setLoopMode(LoopMode.one);
    await player.setVolume(_volumes[track]!);
    if (_isPercussion(track)) {
      await player.setSpeed(_percussionRate);
    }
    return duration;
  }

  /// Set an independent track volume. Values are clamped to 0.0–1.0.
  Future<void> setTrackVolume(AudioTrack track, double volume) async {
    _ensureNotDisposed();
    final safeVolume = volume.clamp(0.0, 1.0).toDouble();
    _volumes[track] = safeVolume;
    await _players[track]!.setVolume(safeVolume);
  }

  /// Start a track. The track loops until stopTrack is called.
  Future<void> playTrack(AudioTrack track) async {
    _ensureNotDisposed();
    unawaited(_players[track]!.play());
  }

  /// Stop a track and reset its playhead to the beginning.
  Future<void> stopTrack(AudioTrack track) async {
    _ensureNotDisposed();
    await _players[track]!.stop();
    await _players[track]!.seek(Duration.zero);
  }

  /// Pause a track without resetting its playhead.
  Future<void> pauseTrack(AudioTrack track) async {
    _ensureNotDisposed();
    await _players[track]!.pause();
  }

  /// Start all loaded tracks without waiting for playback to finish.
  Future<void> playAll() async {
    _ensureNotDisposed();
    for (final player in _players.values) {
      unawaited(player.play());
    }
  }

  /// Stop all six tracks.
  Future<void> stopAll() async {
    _ensureNotDisposed();
    await Future.wait(_players.values.map((player) => player.stop()));
  }

  /// Apply a playback rate to all three percussion tracks.
  ///
  /// A rate of 1.0 is original speed; 1.1 is 10% faster. The native player
  /// playback-rate control is used instead of modifying the audio file.
  Future<void> setPercussionPlaybackRate(double rate) async {
    _ensureNotDisposed();
    if (!rate.isFinite || rate <= 0) {
      throw ArgumentError.value(rate, 'rate', 'Must be a finite value > 0.');
    }

    _percussionRate = rate;
    await Future.wait(_percussionTracks.map((track) {
      return _players[track]!.setSpeed(rate);
    }));
  }

  /// Adjust rate based on the loop's authored BPM and the target song BPM.
  Future<void> setPercussionBpm({
    required double sourceBpm,
    required double targetBpm,
  }) async {
    _ensureNotDisposed();
    if (!sourceBpm.isFinite || sourceBpm <= 0) {
      throw ArgumentError.value(
        sourceBpm,
        'sourceBpm',
        'Must be a finite BPM > 0.',
      );
    }
    if (!targetBpm.isFinite || targetBpm <= 0) {
      throw ArgumentError.value(
        targetBpm,
        'targetBpm',
        'Must be a finite BPM > 0.',
      );
    }

    await setPercussionPlaybackRate(targetBpm / sourceBpm);
  }

  /// Restore percussion loops to their original playback speed.
  Future<void> resetPercussionPlaybackRate() =>
      setPercussionPlaybackRate(1.0);

  bool _isPercussion(AudioTrack track) => _percussionTracks.contains(track);

  /// Release native audio resources. Call when the service is no longer used.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(_players.values.map((player) => player.dispose()));
  }
}
