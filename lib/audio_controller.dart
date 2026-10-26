import 'dart:async';
import 'dart:collection';

import 'package:just_audio/just_audio.dart';

import 'audio_engine.dart';

/// Coordinates tap tempo and musical-key changes for [AudioEngine].
///
/// Tap tempo averages the most recent four inter-tap intervals (five taps
/// produce four intervals). The resulting BPM is converted to percussion
/// playback rate using the configured source-loop BPM.
///
/// For smooth key changes, provide pre-transposed pad sources for each key.
/// just_audio does not expose independent pitch-shifting that preserves tempo;
/// changing playback speed would also change timing. This controller therefore
/// crossfades to prepared transposed audio instead of changing speed/pitch on
/// the live pad players.
class AudioController {
  AudioController(
    this.engine, {
    required this.sourcePercussionBpm,
    this.crossfadeDuration = const Duration(milliseconds: 450),
    this.tapTimeout = const Duration(seconds: 2),
  }) {
    if (!sourcePercussionBpm.isFinite || sourcePercussionBpm <= 0) {
      throw ArgumentError.value(
        sourcePercussionBpm,
        'sourcePercussionBpm',
        'Must be a finite BPM > 0.',
      );
    }
    if (crossfadeDuration <= Duration.zero) {
      throw ArgumentError.value(
        crossfadeDuration,
        'crossfadeDuration',
        'Must be greater than zero.',
      );
    }
  }

  final AudioEngine engine;
  final double sourcePercussionBpm;
  final Duration crossfadeDuration;
  final Duration tapTimeout;

  final Queue<DateTime> _tapTimes = Queue<DateTime>();
  Timer? _tapResetTimer;
  bool _disposed = false;
  double? _currentBpm;
  String _selectedKey = 'C Major';

  final Map<AudioTrack, AudioPlayer> _padTransitionPlayers = {
    AudioTrack.pad1: AudioPlayer(),
    AudioTrack.pad2: AudioPlayer(),
    AudioTrack.pad3: AudioPlayer(),
  };

  /// Musical keys and their semitone offsets relative to C.
  ///
  /// Major/minor labels are kept distinct for the UI, while equal-tempered
  /// semitone offsets describe the tonic. Minor mode changes require
  /// appropriately arranged/transposed source material, not just a pitch
  /// offset, so callers should register exact key variants with [registerPadSources].
  static const Map<String, int> keySemitoneOffsets = {
    'C Major': 0,
    'C# Major': 1,
    'Db Major': 1,
    'D Major': 2,
    'D# Major': 3,
    'Eb Major': 3,
    'E Major': 4,
    'F Major': 5,
    'F# Major': 6,
    'Gb Major': 6,
    'G Major': 7,
    'G# Major': 8,
    'Ab Major': 8,
    'A Major': 9,
    'A# Major': 10,
    'Bb Major': 10,
    'B Major': 11,
    'C Minor': 0,
    'C# Minor': 1,
    'Db Minor': 1,
    'D Minor': 2,
    'D# Minor': 3,
    'Eb Minor': 3,
    'E Minor': 4,
    'F Minor': 5,
    'F# Minor': 6,
    'Gb Minor': 6,
    'G Minor': 7,
    'G# Minor': 8,
    'Ab Minor': 8,
    'A Minor': 9,
    'A# Minor': 10,
    'Bb Minor': 10,
    'B Minor': 11,
  };

  /// For every key, map each pad track to a pre-transposed source URI.
  /// Register all three tracks for a key before calling [selectKey].
  final Map<String, Map<AudioTrack, Uri>> _padSourcesByKey = {};

  /// Current estimated BPM after a successful tap sequence.
  double? get currentBpm => _currentBpm;

  /// Currently selected key label.
  String get selectedKey => _selectedKey;

  /// Register the pre-transposed source for one pad in a particular key.
  ///
  /// Example: registerPadSource('A Minor', AudioTrack.pad1, Uri.file(path)).
  /// Source files should be rendered/processed for the desired key beforehand.
  void registerPadSource(String key, AudioTrack track, Uri source) {
    _ensureNotDisposed();
    if (!keySemitoneOffsets.containsKey(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported musical key.');
    }
    if (!_isPad(track)) {
      throw ArgumentError.value(track, 'track', 'Only pad tracks are valid.');
    }
    (_padSourcesByKey[key] ??= {})[track] = source;
  }

  /// Register all three pad variants for a key in one call.
  void registerPadSources(String key, Map<AudioTrack, Uri> sources) {
    _ensureNotDisposed();
    for (final track in _padTracks) {
      final source = sources[track];
      if (source == null) {
        throw ArgumentError('Missing source for $track in $key.');
      }
      registerPadSource(key, track, source);
    }
  }

  /// Record a tap. Returns the new BPM once there are at least four taps,
  /// averaging the last four intervals; otherwise returns null.
  ///
  /// The measured BPM is applied to percussion playback rate immediately.
  Future<double?> tapTempo({DateTime? timestamp}) async {
    _ensureNotDisposed();
    final now = timestamp ?? DateTime.now();

    if (_tapTimes.isNotEmpty) {
      final gap = now.difference(_tapTimes.last);
      if (gap <= Duration.zero || gap > tapTimeout) {
        _tapTimes.clear();
      }
    }

    _tapTimes.addLast(now);
    while (_tapTimes.length > 5) {
      _tapTimes.removeFirst();
    }

    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(tapTimeout, _tapTimes.clear);

    if (_tapTimes.length < 5) return null;

    final taps = _tapTimes.toList(growable: false);
    var totalMicroseconds = 0;
    for (var i = 1; i < taps.length; i++) {
      totalMicroseconds +=
          taps[i].difference(taps[i - 1]).inMicroseconds;
    }

    final averageIntervalMicroseconds = totalMicroseconds / 4;
    if (averageIntervalMicroseconds <= 0) return null;

    final bpm = 60000000 / averageIntervalMicroseconds;
    _currentBpm = bpm;
    await engine.setPercussionBpm(
      sourceBpm: sourcePercussionBpm,
      targetBpm: bpm,
    );
    return bpm;
  }

  /// Clear the current tap sequence without changing the applied BPM.
  void resetTapTempo() {
    _tapResetTimer?.cancel();
    _tapTimes.clear();
  }

  /// Select a key and crossfade the three active pad channels to its variants.
  ///
  /// Each target pad source must be registered in advance. If a pad is not
  /// currently playing, its source is prepared and its selected variant will
  /// be ready for later playback without forcing it to start.
  Future<void> selectKey(String key) async {
    _ensureNotDisposed();
    if (!keySemitoneOffsets.containsKey(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported musical key.');
    }

    final sources = _padSourcesByKey[key];
    if (sources == null || _padTracks.any((track) => sources[track] == null)) {
      throw StateError(
        'Register pre-transposed sources for all three pads in "$key" first.',
      );
    }

    final transitions = <Future<void>>[];
    for (final track in _padTracks) {
      transitions.add(_crossfadePad(track, sources[track]!));
    }
    await Future.wait(transitions);
    _selectedKey = key;
  }

  Future<void> _crossfadePad(AudioTrack track, Uri nextSource) async {
    final livePlayer = engine.playerFor(track);
    final nextPlayer = _padTransitionPlayers[track]!;
    final baseVolume = engine.volumeFor(track);
    final wasPlaying = livePlayer.playing;

    await nextPlayer.setVolume(0);
    await nextPlayer.setLoopMode(LoopMode.one);
    await nextPlayer.setAudioSource(AudioSource.uri(nextSource));

    if (!wasPlaying) {
      // Keep inactive pads inactive, but prepare the selected source in the
      // transition player for a later crossfade. A live player swap is only
      // possible while playing; inactive variants remain primed here.
      return;
    }

    await nextPlayer.seek(Duration.zero);
    unawaited(nextPlayer.play());

    const steps = 15;
    final stepDuration = Duration(
      microseconds: 300000 ~/ steps,
    );
    for (var step = 1; step <= steps; step++) {
      if (_disposed) return;
      final progress = step / steps;
      await Future.wait([
        livePlayer.setVolume(baseVolume * (1 - progress)),
        nextPlayer.setVolume(baseVolume * progress),
      ]);
      await Future<void>.delayed(stepDuration);
    }

    await livePlayer.pause();
    await livePlayer.seek(Duration.zero);
    await livePlayer.setVolume(baseVolume);
    // The transition player now carries the new-key audio. The engine's
    // public track player remains the original player, so future operations
    // must use this controller's active-player routing.
    _activePadPlayers[track] = nextPlayer;
  }

  final Map<AudioTrack, AudioPlayer> _activePadPlayers = {};

  /// Active pad player after a completed key crossfade, falling back to engine.
  AudioPlayer activePadPlayer(AudioTrack track) {
    if (!_isPad(track)) {
      throw ArgumentError.value(track, 'track', 'Only pad tracks are valid.');
    }
    return _activePadPlayers[track] ?? engine.playerFor(track);
  }

  static const Set<AudioTrack> _padTracks = {
    AudioTrack.pad1,
    AudioTrack.pad2,
    AudioTrack.pad3,
  };

  bool _isPad(AudioTrack track) => _padTracks.contains(track);

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError('AudioController has already been disposed.');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _tapResetTimer?.cancel();
    await Future.wait(_padTransitionPlayers.values.map((player) => player.dispose()));
  }
}
