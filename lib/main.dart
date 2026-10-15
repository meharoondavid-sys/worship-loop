import 'dart:async';

import 'package:flutter/material.dart';

import 'audio_controller.dart';
import 'audio_engine.dart';
import 'custom_audio_library.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) => Material(
        color: const Color(0xFF0A0D12),
        child: SafeArea(
          child: SizedBox.expand(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                'Worship Loop could not render this screen.\\n\\n'
                '${details.exceptionAsString()}',
                style: const TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(const WorshipLoopApp());
}

class WorshipLoopApp extends StatelessWidget {
  const WorshipLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF0A0D12);
    const surface = Color(0xFF151B24);
    const accent = Color(0xFF83B8FF);

    return MaterialApp(
      title: 'Worship Loop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: Color(0xFFFFBF47),
          surface: surface,
          error: Color(0xFFFF5D67),
          onPrimary: Color(0xFF06101F),
          onSecondary: Color(0xFF201400),
          onSurface: Color(0xFFF3F6FA),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFFB7C1D0)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(65, 65),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
      home: const MixerScreen(),
    );
  }
}

class MixerScreen extends StatefulWidget {
  const MixerScreen({super.key});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  late final AudioEngine _engine;
  late final AudioController _controller;
  final CustomAudioLibrary _audioLibrary = CustomAudioLibrary();

  static const _amber = Color(0xFFFFBF47);
  static const _blue = Color(0xFF65A9FF);
  static const _surface = Color(0xFF151B24);
  static const _border = Color(0xFF293343);

  static const List<String> _keys = [
    'C Major', 'C# Major', 'D Major', 'Eb Major', 'E Major', 'F Major',
    'F# Major', 'G Major', 'Ab Major', 'A Major', 'Bb Major', 'B Major',
    'C Minor', 'C# Minor', 'D Minor', 'Eb Minor', 'E Minor', 'F Minor',
    'F# Minor', 'G Minor', 'Ab Minor', 'A Minor', 'Bb Minor', 'B Minor',
  ];

  final Map<AudioTrack, bool> _playing = {
    for (final track in AudioTrack.values) track: false,
  };
  String _selectedKey = 'C Major';
  double? _bpm;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _engine = AudioEngine();
    _controller = AudioController(
      _engine,
      sourcePercussionBpm: 100,
    );
    unawaited(_restoreCustomAudio());
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _restoreCustomAudio() async {
    try {
      await _audioLibrary.restore(_engine);
      if (mounted) setState(() {});
    } catch (error) {
      _showMessage('Some saved audio could not be restored: $error');
    }
  }

  Future<void> _importAudio(AudioTrack track) async {
    try {
      final path = await _audioLibrary.importForTrack(_engine, track);
      if (path == null) return;
      if (mounted) {
        setState(() => _playing[track] = false);
        _showMessage('Loaded ${_audioLibrary.nameFor(track)} into ${_trackName(track)}');
      }
    } catch (error) {
      _showMessage('Audio import failed: $error');
    }
  }

  Future<void> _toggleTrack(AudioTrack track) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_playing[track] == true) {
        await _engine.pauseTrack(track);
      } else {
        await _engine.playTrack(track);
      }
      if (mounted) setState(() => _playing[track] = !(_playing[track] ?? false));
    } catch (error) {
      _showMessage('Could not change track: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tapTempo() async {
    try {
      final bpm = await _controller.tapTempo();
      if (!mounted) return;
      setState(() => _bpm = bpm ?? _bpm);
      if (bpm != null) _showMessage('Tempo set to ${bpm.round()} BPM');
    } catch (error) {
      _showMessage('Tap tempo unavailable: $error');
    }
  }

  Future<void> _stopAll() async {
    try {
      await _engine.stopAll();
      if (mounted) {
        setState(() {
          for (final track in AudioTrack.values) {
            _playing[track] = false;
          }
        });
      }
    } catch (error) {
      _showMessage('Unable to stop all tracks: $error');
    }
  }

  Future<void> _selectKey(String? key) async {
    if (key == null) return;
    try {
      await _controller.selectKey(key);
      if (mounted) setState(() => _selectedKey = key);
    } on StateError {
      if (mounted) setState(() => _selectedKey = key);
      _showMessage(
        'Key selected for the session. Load prepared pad audio for $key to '
        'enable the crossfade.',
      );
    } catch (error) {
      _showMessage('Could not change key: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 16, wide ? 28 : 16, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 22),
                      _buildKeyAndStop(wide),
                      const SizedBox(height: 24),
                      _buildTempoPanel(wide),
                      const SizedBox(height: 28),
                      _buildSectionHeading('AMBIENT PADS', 'SUSTAINED ATMOSPHERE', _amber),
                      const SizedBox(height: 12),
                      _buildTrackGrid(
                        [AudioTrack.pad1, AudioTrack.pad2, AudioTrack.pad3],
                        wide,
                      ),
                      const SizedBox(height: 28),
                      _buildSectionHeading('PERCUSSION', 'RHYTHM & MOVEMENT', _blue),
                      const SizedBox(height: 12),
                      _buildTrackGrid(
                        [
                          AudioTrack.percussion1,
                          AudioTrack.percussion2,
                          AudioTrack.percussion3,
                        ],
                        wide,
                      ),
                      const SizedBox(height: 22),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1C2A3B),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF334A66)),
          ),
          child: const Icon(Icons.graphic_eq_rounded, color: _blue, size: 28),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WORSHIP LOOP',
                  style: TextStyle(fontSize: 12, letterSpacing: 2.2,
                      color: Color(0xFF9CAEC4), fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('Stage Mixer', style: TextStyle(fontSize: 26,
                  fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF15251F),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFF2C5946)),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, size: 7, color: Color(0xFF65D6A0)),
              SizedBox(width: 6),
              Text('READY', style: TextStyle(fontSize: 11,
                  letterSpacing: 1, color: Color(0xFF9AE4BD),
                  fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKeyAndStop(bool wide) {
    final keySelector = Semantics(
      label: 'Musical key selection',
      hint: 'Choose the key for the worship set',
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            const Icon(Icons.music_note_rounded, color: _amber, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GLOBAL KEY', style: TextStyle(
                    fontSize: 11, letterSpacing: 1.5,
                    color: Color(0xFF9CAEC4), fontWeight: FontWeight.w800)),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedKey,
                      isExpanded: true,
                      menuMaxHeight: 420,
                      icon: const Icon(Icons.expand_more_rounded),
                      style: const TextStyle(fontSize: 20,
                          color: Colors.white, fontWeight: FontWeight.w800),
                      items: _keys.map((key) => DropdownMenuItem(
                        value: key,
                        child: Text(key),
                      )).toList(),
                      onChanged: _selectKey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final stopButton = Semantics(
      button: true,
      label: 'Stop all audio',
      hint: 'Immediately stop all pad and percussion loops',
      child: SizedBox(
        width: wide ? 210 : double.infinity,
        height: 76,
        child: FilledButton.icon(
          onPressed: _stopAll,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB82D3B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          icon: const Icon(Icons.stop_circle_outlined, size: 28),
          label: const Text('STOP ALL', style: TextStyle(fontSize: 17, letterSpacing: 1.1)),
        ),
      ),
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: keySelector),
          const SizedBox(width: 14),
          stopButton,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [keySelector, const SizedBox(height: 12), stopButton],
    );
  }

  Widget _buildTempoPanel(bool wide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF182332), Color(0xFF121923)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A3C52)),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: _tempoReadout()),
                const SizedBox(width: 18),
                SizedBox(width: 230, child: _tapButton()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _tempoReadout(),
                const SizedBox(height: 14),
                _tapButton(),
              ],
            ),
    );
  }

  Widget _tempoReadout() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF24354A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.speed_rounded, color: _blue, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TEMPO', style: TextStyle(fontSize: 11,
                  letterSpacing: 1.5, color: Color(0xFF9CAEC4),
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(_bpm == null ? 'Tap to set BPM' : '${_bpm!.round()} BPM',
                  style: const TextStyle(fontSize: 25,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tapButton() {
    return Semantics(
      button: true,
      label: 'Tap tempo',
      hint: 'Tap at the song beat. Five taps calculate the tempo.',
      child: SizedBox(
        width: double.infinity,
        height: 70,
        child: FilledButton.icon(
          onPressed: _tapTempo,
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            foregroundColor: const Color(0xFF071321),
          ),
          icon: const Icon(Icons.touch_app_rounded, size: 25),
          label: const Text('TAP TEMPO'),
        ),
      ),
    );
  }

  Widget _buildSectionHeading(String title, String subtitle, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15,
                  letterSpacing: 1.6, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 10,
                  letterSpacing: 1.1, color: Color(0xFF8290A3),
                  fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Text('3 CHANNELS', style: TextStyle(fontSize: 10,
            letterSpacing: 1, color: color, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _buildTrackGrid(List<AudioTrack> tracks, bool wide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = wide ? 3 : 2;
        final itemWidth = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tracks.map((track) => SizedBox(
            width: itemWidth,
            child: _trackCard(track),
          )).toList(),
        );
      },
    );
  }

  Widget _trackCard(AudioTrack track) {
    final isPad = track.name.startsWith('pad');
    final activeColor = isPad ? _amber : _blue;
    final isPlaying = _playing[track] ?? false;
    final label = _trackName(track);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPlaying
            ? activeColor.withValues(alpha: 0.12)
            : _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPlaying ? activeColor.withValues(alpha: 0.85) : _border,
          width: isPlaying ? 1.5 : 1,
        ),
        boxShadow: isPlaying
            ? [BoxShadow(color: activeColor.withValues(alpha: 0.13), blurRadius: 18)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(isPad ? Icons.waves_rounded : Icons.graphic_eq_rounded,
                  color: isPlaying ? activeColor : const Color(0xFF7D8A9C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              if (isPlaying)
                Icon(Icons.circle, size: 8, color: activeColor),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            toggled: isPlaying,
            label: '$label loop',
            value: isPlaying ? 'Playing' : 'Stopped',
            hint: isPlaying ? 'Double tap to stop this loop' : 'Double tap to play this loop',
            child: SizedBox(
              width: double.infinity,
              height: 72,
              child: FilledButton(
                onPressed: _busy ? null : () => _toggleTrack(track),
                style: FilledButton.styleFrom(
                  backgroundColor: isPlaying ? activeColor : const Color(0xFF232C38),
                  foregroundColor: isPlaying ? const Color(0xFF071321) : Colors.white,
                  disabledBackgroundColor: const Color(0xFF232C38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 28),
                    const SizedBox(width: 7),
                    Text(isPlaying ? 'PLAYING' : 'START',
                        style: const TextStyle(fontSize: 12, letterSpacing: 0.8)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _audioLibrary.nameFor(track) ?? 'No custom audio',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF9CAEC4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            button: true,
            label: 'Import audio for $label',
            hint: 'Choose a WAV or MP3 file from this device',
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _importAudio(track),
                style: OutlinedButton.styleFrom(
                  foregroundColor: activeColor,
                  side: BorderSide(color: activeColor.withValues(alpha: 0.55)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.audio_file_rounded, size: 19),
                label: const Text('IMPORT AUDIO'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPlaying ? 'ACTIVE IN MIX' : 'READY',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 9, letterSpacing: 1.2,
                color: isPlaying ? activeColor : const Color(0xFF7D8A9C),
                fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.hearing_rounded, size: 16, color: Color(0xFF718096)),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            'Designed for quick, confident control on stage',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF718096)),
          ),
        ),
      ],
    );
  }

  String _trackName(AudioTrack track) {
    switch (track) {
      case AudioTrack.pad1: return 'Pad 1';
      case AudioTrack.pad2: return 'Pad 2';
      case AudioTrack.pad3: return 'Pad 3';
      case AudioTrack.percussion1: return 'Percussion 1';
      case AudioTrack.percussion2: return 'Percussion 2';
      case AudioTrack.percussion3: return 'Percussion 3';
    }
  }
}
