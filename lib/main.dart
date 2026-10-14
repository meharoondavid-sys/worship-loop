import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const WorshipLoopApp());
}

class WorshipLoopApp extends StatelessWidget {
  const WorshipLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5595FF);
    return MaterialApp(
      title: 'Worship Loop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
          surface: const Color(0xFF111722),
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1018),
        cardTheme: CardThemeData(
          color: const Color(0xFF151D2A),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF26354A)),
          ),
        ),
        sliderTheme: const SliderThemeData(trackHeight: 3),
      ),
      home: const MixerScreen(),
    );
  }
}

enum LayerKind { pad, percussion }

class AudioLayer {
  AudioLayer({
    required this.name,
    required this.kind,
    required this.subtitle,
    this.volume = 0.72,
  });

  final String name;
  final LayerKind kind;
  final String subtitle;
  double volume;
  bool isPlaying = false;
}

class MixerScreen extends StatefulWidget {
  const MixerScreen({super.key});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  final List<AudioLayer> _layers = [
    AudioLayer(name: 'Pad 1', kind: LayerKind.pad, subtitle: 'Warm atmosphere'),
    AudioLayer(name: 'Pad 2', kind: LayerKind.pad, subtitle: 'Soft texture'),
    AudioLayer(name: 'Pad 3', kind: LayerKind.pad, subtitle: 'Deep ambience'),
    AudioLayer(name: 'Percussion 1', kind: LayerKind.percussion, subtitle: 'Soft pulse'),
    AudioLayer(name: 'Percussion 2', kind: LayerKind.percussion, subtitle: 'Shaker / groove'),
    AudioLayer(name: 'Percussion 3', kind: LayerKind.percussion, subtitle: 'Build / accents'),
  ];

  int _bpm = 72;
  String _globalKey = 'C Major';
  static const List<String> _availableKeys = [
    'C Major', 'Db Major', 'D Major', 'Eb Major', 'E Major', 'F Major',
    'F# Major', 'G Major', 'Ab Major', 'A Major', 'Bb Major', 'B Major',
    'C Minor', 'C# Minor', 'D Minor', 'Eb Minor', 'E Minor', 'F Minor',
    'F# Minor', 'G Minor', 'Ab Minor', 'A Minor', 'Bb Minor', 'B Minor',
  ];
  double _masterVolume = 0.85;
  String _fadeLength = '½ bar';
  bool _transitionTogether = true;
  final List<DateTime> _tapTimes = [];
  final Map<String, AudioPlayer> _players = {};
  bool _audioReady = false;
  bool _audioLoading = false;
  String? _audioError;

  @override
  void initState() {
    super.initState();
    for (final layer in _layers) { _players[layer.name] = AudioPlayer(); }
    _preparePadAudio();
  }

  @override
  void dispose() {
    for (final player in _players.values) { player.dispose(); }
    super.dispose();
  }

  Future<void> _preparePadAudio() async {
    setState(() => _audioLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      for (var i = 0; i < _layers.length; i++) {
        final layer = _layers[i];
        final file = File('${directory.path}/worship_loop_${i + 1}.wav');
        await file.writeAsBytes(_createLayerWav(i), flush: true);
        final player = _players[layer.name]!;
        await player.setFilePath(file.path);
        await player.setLoopMode(LoopMode.one);
        await player.setVolume(_effectiveVolume(layer));
      }
      if (!mounted) return;
      setState(() {
        _audioReady = true;
        _audioLoading = false;
        _audioError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _audioLoading = false;
        _audioError = 'Audio setup failed: $error';
      });
    }
  }

  double _effectiveVolume(AudioLayer layer) =>
      layer.volume * (layer.kind == LayerKind.pad ? _padBusVolume : _percussionBusVolume) * _masterVolume;

  Uint8List _createLayerWav(int layerIndex) {
    final isPad = layerIndex < 3;
    final seconds = isPad ? 4.0 : 240.0 / _bpm;
    const sampleRate = 44100;
    const channels = 2;
    const bitsPerSample = 16;
    final frameCount = (sampleRate * seconds).round();
    final dataSize = frameCount * channels * (bitsPerSample ~/ 8);
    final bytes = ByteData(44 + dataSize);
    void writeText(int offset, String value) {
      for (var i = 0; i < value.length; i++) { bytes.setUint8(offset + i, value.codeUnitAt(i)); }
    }
    writeText(0, 'RIFF');
    bytes.setUint32(4, 36 + dataSize, Endian.little);
    writeText(8, 'WAVE');
    writeText(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * channels * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(32, channels * (bitsPerSample ~/ 8), Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeText(36, 'data');
    bytes.setUint32(40, dataSize, Endian.little);

    final keyRoot = _availableKeys.indexOf(_globalKey) % 12;
    final rootHz = (65.406 * math.pow(2, keyRoot / 12)).toDouble();
    final padNotes = [rootHz, rootHz * 1.5, rootHz * 2.0, rootHz * 2.5];
    final random = math.Random(100 + layerIndex);
    final beatSeconds = 60.0 / _bpm;
    for (var frame = 0; frame < frameCount; frame++) {
      final time = frame / sampleRate;
      double sample = 0;
      if (isPad) {
        final notes = layerIndex == 0 ? padNotes : layerIndex == 1
            ? [padNotes[1], padNotes[2], padNotes[3]]
            : [padNotes[0] / 2, padNotes[2], padNotes[3] * 1.5];
        for (var n = 0; n < notes.length; n++) {
          final shimmer = 1 + 0.018 * math.sin(2 * math.pi * time / 5 + n);
          sample += math.sin(2 * math.pi * notes[n] * time) * shimmer;
        }
        sample = sample / notes.length * 0.23;
      } else {
        final beatPosition = time % beatSeconds;
        final beat = (time / beatSeconds).floor() % 4;
        if (layerIndex == 3) {
          sample = beatPosition < 0.12 ? math.sin(2 * math.pi * 85 * beatPosition) * math.exp(-beatPosition * 24) : 0;
        } else if (layerIndex == 4) {
          sample = (beatPosition < 0.055 ? (random.nextDouble() * 2 - 1) * math.exp(-beatPosition * 55) : 0) * (beat.isEven ? 0.55 : 0.8);
        } else {
          final hit = beatPosition < 0.08 && (beat == 0 || beat == 2);
          sample = hit ? (random.nextDouble() * 2 - 1) * math.exp(-beatPosition * 40) : 0;
        }
        sample *= 0.65;
      }
      final value = (sample * 12000).round().clamp(-32768, 32767).toInt();
      final offset = 44 + frame * 4;
      bytes.setInt16(offset, value, Endian.little);
      bytes.setInt16(offset + 2, value, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  Future<void> _toggleLayer(AudioLayer layer) async {
    if (!_audioReady) {
      _showNotice(_audioError ?? 'Preparing audio. Please try again in a moment.');
      return;
    }
    final player = _players[layer.name]!;
    try {
      if (player.playing) {
        await player.pause();
        await player.seek(Duration.zero);
        if (mounted) setState(() => layer.isPlaying = false);
      } else {
        await player.setVolume(_effectiveVolume(layer));
        await player.seek(Duration.zero);
        player.play();
        if (mounted) setState(() => layer.isPlaying = true);
      }
    } catch (error) {
      _showNotice('Could not play ${layer.name}: $error');
    }
  }

  Future<void> _updateLayerVolume(AudioLayer layer, double value) async {
    setState(() => layer.volume = value);
    if (_audioReady) await _players[layer.name]!.setVolume(_effectiveVolume(layer));
  }

  Future<void> _updatePadVolume(double value) => _updateLayerVolume(_layers.first, value);

  Future<void> _updateMasterVolume(double value) async {
    setState(() => _masterVolume = value);
    if (_audioReady) {
      for (final layer in _layers) {
        await _players[layer.name]!.setVolume(_effectiveVolume(layer));
      }
    }
  }

  void _tapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 5) _tapTimes.removeAt(0);
    if (_tapTimes.length >= 2) {
      final intervals = <int>[];
      for (var i = 1; i < _tapTimes.length; i++) {
        intervals.add(_tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds);
      }
      final average = intervals.reduce((a, b) => a + b) / intervals.length;
      if (average >= 250 && average <= 2000) {
        setState(() => _bpm = (60000 / average).round().clamp(30, 240).toInt());
        return;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pads = _layers.where((layer) => layer.kind == LayerKind.pad).toList();
    final percussion = _layers
        .where((layer) => layer.kind == LayerKind.percussion)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Worship Loop', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              'LIVE MIXER',
              style: TextStyle(fontSize: 10, letterSpacing: 2, color: Color(0xFF9AA9BE)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Setlists (coming soon)',
            onPressed: () => _showNotice('Setlists will be added after the audio prototype.'),
            icon: const Icon(Icons.queue_music_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, _) {
            final landscape = MediaQuery.sizeOf(context).width >
                MediaQuery.sizeOf(context).height;
            if (landscape) {
              return _landscapeLayout(pads, percussion);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _prototypeNotice(),
                const SizedBox(height: 8),
                _audioStatus(),
                const SizedBox(height: 16),
                _tempoPanel(),
                const SizedBox(height: 14),
                _globalKeyPanel(),
                const SizedBox(height: 18),
                _sectionHeader('PADS', 'SUSTAINING ATMOSPHERE', Icons.graphic_eq_rounded),
                const SizedBox(height: 10),
                ...pads.map((layer) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _layerCard(layer),
                    )),
                const SizedBox(height: 10),
                _sectionHeader('PERCUSSION', 'TEMPO-SYNCED LOOPS', Icons.waves_rounded),
                const SizedBox(height: 10),
                ...percussion.map((layer) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _layerCard(layer),
                    )),
                const SizedBox(height: 8),
                _transitionPanel(),
                const SizedBox(height: 14),
                _masterPanel(),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => _showNotice(
                    'Audio is available in the Android app prototype. The web preview remains visual-only.',
                  ),
                  icon: const Icon(Icons.info_outline_rounded),
                  label: const Text('What works in this preview?'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _landscapeLayout(List<AudioLayer> pads, List<AudioLayer> percussion) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 4, 9, 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 10, child: _landscapeFaderGroup('PADS', 'SUSTAINING', pads, const Color(0xFF60A5FA), const Color(0xFF3B82F6), true)),
                const SizedBox(width: 7),
                Expanded(flex: 10, child: _landscapeFaderGroup('PERCUSSION', 'TEMPO-SYNCED', percussion, const Color(0xFF2DD4BF), const Color(0xFF0F766E), false)),
                const SizedBox(width: 7),
                SizedBox(width: 54, child: _landscapeMasterFader()),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _compactTempoPanel()),
              const SizedBox(width: 6),
              Expanded(child: _compactTransitionPanel()),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Global key and audio status',
                onPressed: _showSettings,
                icon: const Icon(Icons.tune_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF17263A),
                  foregroundColor: const Color(0xFF82B5FF),
                  side: const BorderSide(color: Color(0xFF344B66)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0A1019),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('MIXER SETTINGS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              _compactGlobalKeyPanel(),
              const SizedBox(height: 8),
              _audioStatus(),
              const SizedBox(height: 8),
              _prototypeNotice(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _landscapeFaderGroup(String title, String subtitle, List<AudioLayer> layers, Color busColor, Color accent, bool isPad) {
    final busVolume = isPad ? _padBusVolume : _percussionBusVolume;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: const Color(0xFF0D131D), border: Border.all(color: const Color(0xFF26354A)), borderRadius: BorderRadius.circular(9)),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1, color: accent)),
              Text(subtitle, style: const TextStyle(fontSize: 8, color: Color(0xFF93A2B7))),
            ])),
            Text('3/3', style: const TextStyle(fontSize: 9, color: Color(0xFF93A2B7))),
          ]),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < layers.length; i++)
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _verticalLayerFader(layers[i], _layerColor(isPad, i)),
                  )),
                const SizedBox(width: 38),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 27,
            decoration: BoxDecoration(color: const Color(0xFF101722), border: Border.all(color: busColor.withValues(alpha: .65)), borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              const SizedBox(width: 4),
              Expanded(child: Text(isPad ? 'PAD BUS' : 'PERC BUS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: busColor))),
              SizedBox(width: 70, child: SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: busColor, thumbColor: busColor, trackHeight: 2), child: Slider(value: busVolume, onChanged: (v) => _updateBusVolume(isPad, v)))),
              SizedBox(width: 25, child: Text('${(busVolume * 100).round()}%', style: TextStyle(fontSize: 8, color: busColor))),
            ]),
          ),
        ],
      ),
    );
  }

  Color _layerColor(bool isPad, int index) {
    const padColors = [Color(0xFF60A5FA), Color(0xFFA78BFA), Color(0xFF22D3EE)];
    const percColors = [Color(0xFF2DD4BF), Color(0xFFFBBF24), Color(0xFFFB7185)];
    return isPad ? padColors[index] : percColors[index];
  }

  Widget _verticalLayerFader(AudioLayer layer, Color accent) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111A27), border: Border.all(color: accent.withValues(alpha: .4)), borderRadius: BorderRadius.circular(7)),
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
      child: Column(
        children: [
          Text(layer.name.replaceFirst('Percussion ', 'Perc '), textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, height: 1, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Container(width: 18, height: 18, decoration: BoxDecoration(color: accent.withValues(alpha: .15), borderRadius: BorderRadius.circular(5)), child: Icon(layer.kind == LayerKind.pad ? Icons.graphic_eq_rounded : Icons.waves_rounded, size: 11, color: accent)),
          const SizedBox(height: 2),
          SizedBox(height: 16, width: 26, child: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: () => _toggleLayer(layer),
            icon: Icon(layer.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 17),
            style: IconButton.styleFrom(backgroundColor: layer.isPlaying ? accent : const Color(0xFF26364A), foregroundColor: layer.isPlaying ? const Color(0xFF07111D) : accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
          )),
          Expanded(child: RotatedBox(quarterTurns: 3, child: SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5), activeTrackColor: accent, inactiveTrackColor: accent.withValues(alpha: .22), thumbColor: accent, overlayShape: SliderComponentShape.noOverlay),
            child: Slider(value: layer.volume, onChanged: (v) => _updateLayerVolume(layer, v)),
          ))),
          Text('${(layer.volume * 100).round()}%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: accent)),
        ],
      ),
    );
  }

  Widget _landscapeMasterFader() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111923), border: Border.all(color: const Color(0x88EAB308)), borderRadius: BorderRadius.circular(9)),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 3),
      child: Column(children: [
        const Text('MASTER', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFFFBBF24))),
        const SizedBox(height: 5),
        Text('${(_masterVolume * 100).round()}%', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFBBF24))),
        Expanded(child: RotatedBox(quarterTurns: 3, child: SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: const Color(0xFFFBBF24), thumbColor: const Color(0xFFFBBF24), trackHeight: 3),
          child: Slider(value: _masterVolume, onChanged: _updateMasterVolume),
        ))),
        const Icon(Icons.tune_rounded, size: 14, color: Color(0xFFFBBF24)),
      ]),
    );
  }

  double _padBusVolume = 1.0;
  double _percussionBusVolume = 1.0;

  void _updateBusVolume(bool isPad, double value) {
    setState(() {
      if (isPad) {
        _padBusVolume = value;
      } else {
        _percussionBusVolume = value;
      }
    });
    if (_audioReady) { for (final layer in _layers) { _players[layer.name]!.setVolume(_effectiveVolume(layer)); } }
  }

  // ignore: unused_element
  Widget _landscapeLayerColumn({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<AudioLayer> layers,
    bool shrinkWrap = false,
  }) {
    final content = Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                    Text(subtitle, style: const TextStyle(fontSize: 9, color: Color(0xFF93A2B7), letterSpacing: 1)),
                  ],
                ),
              ),
              Text('${layers.length}/3', style: const TextStyle(fontSize: 10, color: Color(0xFF93A2B7))),
            ],
          ),
        ),
        const SizedBox(height: 5),
        ...layers.map((layer) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _compactLayerCard(layer),
            )),
      ],
    );
    return shrinkWrap ? content : SingleChildScrollView(child: content);
  }

  Widget _compactLayerCard(AudioLayer layer) {
    final isPad = layer.kind == LayerKind.pad;
    final accent = isPad ? const Color(0xFF82B5FF) : const Color(0xFF73D6C0);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.10),
            const Color(0xFF151D2A),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      padding: const EdgeInsets.fromLTRB(9, 7, 5, 5),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(isPad ? Icons.graphic_eq_rounded : Icons.waves_rounded, color: accent, size: 16),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(layer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                    Text(layer.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Color(0xFF93A2B7))),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(width: 31, height: 31),
                padding: EdgeInsets.zero,
                tooltip: layer.isPlaying ? 'Stop preview state' : 'Start preview state',
                onPressed: () => _toggleLayer(layer),
                style: IconButton.styleFrom(
                  foregroundColor: layer.isPlaying ? const Color(0xFF071018) : accent,
                  backgroundColor: layer.isPlaying ? accent : const Color(0xFF202B3B),
                ),
                icon: Icon(layer.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.volume_down_rounded, size: 14, color: accent),
              Expanded(
                child: SizedBox(
                  height: 24,
                  child: Slider(
                    value: layer.volume,
                    onChanged: (value) => _updateLayerVolume(layer, value),
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text('${(layer.volume * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(fontSize: 9, color: Color(0xFFB7C4D6))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactTempoPanel() {
    return Card(
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C3556), Color(0xFF151D2A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 7),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, color: Color(0xFF82B5FF), size: 17),
                const SizedBox(width: 6),
                const Expanded(child: Text('TEMPO', style: TextStyle(fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800))),
                Text('BPM', style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.60))),
              ],
            ),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _bpm = (_bpm - 1).clamp(30, 240).toInt()),
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                ),
                Expanded(child: Center(child: Text('$_bpm', style: const TextStyle(fontSize: 35, height: 1, fontWeight: FontWeight.w300, letterSpacing: -1.5)))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() => _bpm = (_bpm + 1).clamp(30, 240).toInt()),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                ),
              ],
            ),
            SizedBox(
              height: 24,
              child: Slider(
                value: _bpm.toDouble(),
                min: 30,
                max: 240,
                divisions: 210,
                label: '$_bpm BPM',
                onChanged: (value) => setState(() => _bpm = value.round()),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: _tapTempo,
                icon: const Icon(Icons.touch_app_rounded, size: 15),
                label: const Text('TAP TEMPO', style: TextStyle(fontSize: 10, letterSpacing: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactGlobalKeyPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.music_note_rounded, color: Color(0xFF73D6C0), size: 17),
                SizedBox(width: 6),
                Expanded(child: Text('GLOBAL KEY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
                Text('24', style: TextStyle(fontSize: 9, color: Color(0xFF93A2B7))),
              ],
            ),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              initialValue: _globalKey,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                border: OutlineInputBorder(),
              ),
              items: _availableKeys.map((key) => DropdownMenuItem<String>(value: key, child: Text(key, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (key) {
                if (key != null) setState(() => _globalKey = key);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _compactTransitionPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Color(0xFF73D6C0), size: 16),
                SizedBox(width: 5),
                Expanded(child: Text('TEMPO TRANSITION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
              ],
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 5)),
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 10)),
              ),
              segments: const [
                ButtonSegment(value: '¼ bar', label: Text('¼')),
                ButtonSegment(value: '½ bar', label: Text('½')),
                ButtonSegment(value: '1 bar', label: Text('1')),
              ],
              selected: {_fadeLength},
              onSelectionChanged: (selection) => setState(() => _fadeLength = selection.first),
              showSelectedIcon: false,
            ),
            SwitchListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: EdgeInsets.zero,
              value: _transitionTogether,
              onChanged: (value) => setState(() => _transitionTogether = value),
              title: const Text('Sync percussion', style: TextStyle(fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _compactMasterPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 3),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, color: Color(0xFF82B5FF), size: 16),
            const SizedBox(width: 5),
            const Expanded(child: Text('MASTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1))),
            SizedBox(
              width: 80,
              height: 26,
              child: Slider(value: _masterVolume, onChanged: (value) => setState(() => _masterVolume = value)),
            ),
            SizedBox(width: 27, child: Text('${(_masterVolume * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(fontSize: 9, color: Color(0xFFB7C4D6)))),
          ],
        ),
      ),
    );
  }

  Widget _audioStatus() {
    final message = _audioError ?? (_audioLoading ? 'Preparing real pad audio…' : _audioReady ? 'Audio ready • all six layers connected' : 'Audio is not ready yet');
    final color = _audioError != null ? const Color(0xFFFF8A80) : _audioReady ? const Color(0xFF73D6C0) : const Color(0xFFFFC66D);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Icon(_audioReady ? Icons.graphic_eq_rounded : Icons.info_outline_rounded, color: color), const SizedBox(width: 9), Expanded(child: Text(message, style: TextStyle(fontSize: 11, color: color))) ])));
  }

  Widget _prototypeNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF172B46),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2D5688)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, color: Color(0xFF82B5FF), size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'AUDIO PROTOTYPE\nAll six layers now have generated playback. Sound design and tempo-transition refinements are next.',
              style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFFD3E4FF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tempoPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed_rounded, color: Color(0xFF82B5FF)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('TEMPO', style: TextStyle(fontSize: 12, letterSpacing: 1.8, fontWeight: FontWeight.w700)),
                ),
                Text('$_bpm BPM', style: const TextStyle(fontSize: 13, color: Color(0xFFB6C5D9))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: () => setState(() => _bpm = (_bpm - 1).clamp(30, 240).toInt()),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '$_bpm',
                      style: const TextStyle(fontSize: 52, height: 1, fontWeight: FontWeight.w300, letterSpacing: -2),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(() => _bpm = (_bpm + 1).clamp(30, 240).toInt()),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            Slider(
              value: _bpm.toDouble(),
              min: 30,
              max: 240,
              divisions: 210,
              label: '$_bpm BPM',
              onChanged: (value) => setState(() => _bpm = value.round()),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _tapTempo,
                icon: const Icon(Icons.touch_app_rounded),
                label: const Text('TAP TEMPO'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _globalKeyPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.music_note_rounded, color: Color(0xFF82B5FF)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'GLOBAL KEY',
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '24 KEYS',
                  style: TextStyle(fontSize: 10, color: Color(0xFF93A2B7)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _globalKey,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Key for all layers',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _availableKeys
                  .map((key) => DropdownMenuItem<String>(
                        value: key,
                        child: Text(key),
                      ))
                  .toList(),
              onChanged: (key) {
                if (key != null) setState(() => _globalKey = key);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose any of the 12 major or 12 minor keys. This global setting is ready in the interface; changing the actual sound pitch will be connected when audio playback is implemented.',
              style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF93A2B7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, IconData icon) {
    final kind = title == 'PADS' ? LayerKind.pad : LayerKind.percussion;
    final count = _layers.where((layer) => layer.kind == kind).length;
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF82B5FF)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, letterSpacing: 1.8, fontWeight: FontWeight.w800)),
              Text(subtitle, style: const TextStyle(fontSize: 10, letterSpacing: 1.1, color: Color(0xFF8998AD))),
            ],
          ),
        ),
        Text('$count/3', style: const TextStyle(fontSize: 11, color: Color(0xFF8998AD))),
      ],
    );
  }

  Widget _layerCard(AudioLayer layer) {
    final isPad = layer.kind == LayerKind.pad;
    final accent = isPad ? const Color(0xFF82B5FF) : const Color(0xFF73D6C0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(isPad ? Icons.graphic_eq_rounded : Icons.waves_rounded, color: accent),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(layer.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(layer.subtitle, style: const TextStyle(color: Color(0xFF93A2B7), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: layer.isPlaying ? 'Stop preview state' : 'Start preview state',
                  onPressed: () => _toggleLayer(layer),
                  icon: Icon(layer.isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: layer.isPlaying ? const Color(0xFF0B1018) : accent,
                    backgroundColor: layer.isPlaying ? accent : const Color(0xFF202B3B),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(Icons.volume_down_rounded, size: 17, color: accent),
                Expanded(
                  child: Slider(
                    value: layer.volume,
                    onChanged: (value) => _updateLayerVolume(layer, value),
                  ),
                ),
                SizedBox(
                  width: 37,
                  child: Text(
                    '${(layer.volume * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB7C4D6)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _transitionPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: Color(0xFF73D6C0)),
                SizedBox(width: 8),
                Expanded(child: Text('SMOOTH TEMPO TRANSITION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1))),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Fade-out duration', style: TextStyle(fontSize: 12, color: Color(0xFF9EADC1))),
            const SizedBox(height: 7),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '¼ bar', label: Text('¼ bar')),
                ButtonSegment(value: '½ bar', label: Text('½ bar')),
                ButtonSegment(value: '1 bar', label: Text('1 bar')),
              ],
              selected: {_fadeLength},
              onSelectionChanged: (selection) => setState(() => _fadeLength = selection.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _transitionTogether,
              onChanged: (value) => setState(() => _transitionTogether = value),
              title: const Text('Transition percussion together', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Keep active loops rhythmically aligned', style: TextStyle(fontSize: 11)),
            ),
            const Text(
              'Planned behaviour: fade down → align to the new tempo → fade back in. Pads continue sustaining.',
              style: TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF93A2B7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _masterPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Color(0xFF82B5FF)),
                const SizedBox(width: 8),
                const Expanded(child: Text('MASTER VOLUME', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
                Text('${(_masterVolume * 100).round()}%', style: const TextStyle(color: Color(0xFFB7C4D6), fontSize: 12)),
              ],
            ),
            Slider(
              value: _masterVolume,
              onChanged: _updateMasterVolume,
            ),
          ],
        ),
      ),
    );
  }

  void _showNotice(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Worship Loop preview'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }
}
