import 'package:flutter/material.dart';

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
        cardTheme: const CardThemeData(
          color: Color(0xFF151D2A),
          elevation: 0,
          margin: EdgeInsets.zero,
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _prototypeNotice(),
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
                'Audio playback is not connected yet. This preview lets us review the mixer layout and controls before implementing the audio engine.',
              ),
              icon: const Icon(Icons.info_outline_rounded),
              label: const Text('What works in this preview?'),
            ),
          ],
        ),
      ),
    );
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
              'INTERACTIVE UI PREVIEW\nControls are for layout testing. Audio playback is not connected yet.',
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
              value: _globalKey,
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
                  onPressed: () => setState(() => layer.isPlaying = !layer.isPlaying),
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
                    onChanged: (value) => setState(() => layer.volume = value),
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
              onChanged: (value) => setState(() => _masterVolume = value),
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
