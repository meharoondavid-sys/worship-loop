import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'audio_controller.dart';
import 'audio_engine.dart';
import 'custom_audio_library.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) => Material(
        color: AppColors.background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: SelectableText(
              'Worship Loop could not render this screen.\n\n'
              '${details.exceptionAsString()}',
              style: const TextStyle(
                color: AppColors.padAccent,
                fontSize: 14,
                height: 1.4,
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
    return MaterialApp(
      title: 'Worship Loop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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
  AudioEngine? _engine;
  AudioController? _controller;
  final CustomAudioLibrary _audioLibrary = CustomAudioLibrary();

  static const List<String> _keys = [
    'C Major', 'C# Major', 'D Major', 'Eb Major', 'E Major', 'F Major',
    'F# Major', 'G Major', 'Ab Major', 'A Major', 'Bb Major', 'B Major',
    'C Minor', 'C# Minor', 'D Minor', 'Eb Minor', 'E Minor', 'F Minor',
    'F# Minor', 'G Minor', 'Ab Minor', 'A Minor', 'Bb Minor', 'B Minor',
  ];

  final Map<AudioTrack, bool> _playing = {
    for (final track in AudioTrack.values) track: false,
  };

  final Map<AudioTrack, double> _volumes = {
    for (final track in AudioTrack.values) track: 0.85,
  };

  String _selectedKey = 'C Major';
  double? _bpm;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Render the mixer before touching native audio plugins. Plugin startup
    // must not block the first visible frame on Android or iOS.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_initializeAudio());
    });
  }

  Future<void> _initializeAudio() async {
    try {
      final engine = AudioEngine();
      final controller = AudioController(engine, sourcePercussionBpm: 100);

      if (!mounted) {
        await controller.dispose();
        await engine.dispose();
        return;
      }

      _engine = engine;
      _controller = controller;

      for (final track in AudioTrack.values) {
        final currentVol = engine.volumeFor(track);
        _volumes[track] = currentVol;
      }

      await _restoreCustomAudio();
    } catch (error) {
      _showMessage('Audio startup issue: $error');
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    final engine = _engine;
    if (controller != null) unawaited(controller.dispose());
    if (engine != null) unawaited(engine.dispose());
    super.dispose();
  }

  Future<void> _restoreCustomAudio() async {
    try {
      final engine = _engine;
      if (engine == null) return;
      await _audioLibrary.restore(engine);
      if (mounted) setState(() {});
    } catch (error) {
      _showMessage('Some saved audio could not be restored: $error');
    }
  }

  Future<void> _importAudio(AudioTrack track) async {
    try {
      final engine = _engine;
      if (engine == null) {
        _showMessage('Audio is still starting. Please try again in a moment.');
        return;
      }

      final path = await _audioLibrary.importForTrack(engine, track);
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

    final engine = _engine;
    if (engine == null) {
      _showMessage('Audio is still starting. Please try again in a moment.');
      return;
    }

    setState(() => _busy = true);

    try {
      if (_playing[track] == true) {
        await engine.pauseTrack(track);
      } else {
        await engine.playTrack(track);
      }

      if (mounted) setState(() => _playing[track] = !(_playing[track] ?? false));
    } catch (error) {
      _showMessage('Could not change track: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setTrackVolume(AudioTrack track, double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    setState(() => _volumes[track] = clamped);
    try {
      await _engine?.setTrackVolume(track, clamped);
    } catch (error) {
      _showMessage('Could not set volume: $error');
    }
  }

  Future<void> _tapTempo() async {
    try {
      final controller = _controller;
      if (controller == null) {
        _showMessage('Audio is still starting. Please try again in a moment.');
        return;
      }

      final bpm = await controller.tapTempo();
      if (!mounted) return;

      setState(() => _bpm = bpm ?? _bpm);
      if (bpm != null) _showMessage('Tempo set to ${bpm.round()} BPM');
    } catch (error) {
      _showMessage('Tap tempo unavailable: $error');
    }
  }

  Future<void> _stopAll() async {
    try {
      final engine = _engine;
      if (engine == null) {
        _showMessage('Audio is still starting. Please try again in a moment.');
        return;
      }

      await engine.stopAll();

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
      final controller = _controller;
      if (controller == null) {
        setState(() => _selectedKey = key);
        _showMessage('Key selected for the session. Audio is still starting.');
        return;
      }

      await controller.selectKey(key);
      if (mounted) setState(() => _selectedKey = key);
    } on StateError {
      if (mounted) setState(() => _selectedKey = key);
      _showMessage(
        'Key selected for the session. Load prepared pad audio for $key to enable the crossfade.',
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth >= 760;

            if (isLandscape) {
              return _buildLandscapeConsole(constraints);
            } else {
              return _buildPortraitConsole(constraints);
            }
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // LANDSCAPE CONSOLE (Primary Live-Performance Layout)
  // Shows all 6 channel strips simultaneously side-by-side with zero clutter.
  // ===========================================================================
  Widget _buildLandscapeConsole(BoxConstraints constraints) {
    const padTracks = [AudioTrack.pad1, AudioTrack.pad2, AudioTrack.pad3];
    const percTracks = [
      AudioTrack.percussion1,
      AudioTrack.percussion2,
      AudioTrack.percussion3,
    ];
    final isCompactHeight = constraints.maxHeight < 550;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: isCompactHeight ? AppSpacing.xs : AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCompactHeader(isLandscape: true, isCompactHeight: isCompactHeight),
          SizedBox(height: isCompactHeight ? 4 : AppSpacing.sm),
          _buildLandscapeControlStrip(isCompactHeight: isCompactHeight),
          SizedBox(height: isCompactHeight ? 4 : AppSpacing.sm),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // PADS BAY (Warm Amber)
                Expanded(
                  child: _buildBayContainer(
                    title: 'AMBIENT PADS',
                    subtitle: 'SUSTAINED ATMOSPHERE',
                    accentColor: AppColors.padAccent,
                    tracks: padTracks,
                    isLandscape: true,
                    isCompactHeight: isCompactHeight,
                  ),
                ),
                // CONSOLE DIVIDER RAIL
                Container(
                  width: 1,
                  margin: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: isCompactHeight ? 4 : 8,
                  ),
                  color: AppColors.divider,
                ),
                // PERCUSSION BAY (Cool Blue)
                Expanded(
                  child: _buildBayContainer(
                    title: 'PERCUSSION',
                    subtitle: 'RHYTHM & MOVEMENT',
                    accentColor: AppColors.percussionAccent,
                    tracks: percTracks,
                    isLandscape: true,
                    isCompactHeight: isCompactHeight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PORTRAIT CONSOLE (Mobile Responsive Layout)
  // Clean scrollable view with distinct sections and touch-optimized cards.
  // ===========================================================================
  Widget _buildPortraitConsole(BoxConstraints constraints) {
    const padTracks = [AudioTrack.pad1, AudioTrack.pad2, AudioTrack.pad3];
    const percTracks = [
      AudioTrack.percussion1,
      AudioTrack.percussion2,
      AudioTrack.percussion3,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCompactHeader(isLandscape: false),
              const SizedBox(height: AppSpacing.md),
              _buildPortraitKeyAndStop(),
              const SizedBox(height: AppSpacing.md),
              _buildPortraitTempoPanel(),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionHeader(
                title: 'AMBIENT PADS',
                subtitle: 'SUSTAINED ATMOSPHERE',
                accentColor: AppColors.padAccent,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPortraitTrackGrid(padTracks, constraints.maxWidth),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionHeader(
                title: 'PERCUSSION',
                subtitle: 'RHYTHM & MOVEMENT',
                accentColor: AppColors.percussionAccent,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildPortraitTrackGrid(percTracks, constraints.maxWidth),
              const SizedBox(height: AppSpacing.xl),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HEADER COMPONENTS
  // ===========================================================================
  Widget _buildCompactHeader({
    required bool isLandscape,
    bool isCompactHeight = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? AppSpacing.md : AppSpacing.sm,
        vertical: isLandscape ? (isCompactHeight ? 2 : 4) : AppSpacing.xs,
      ),
      child: Row(
        children: [
          Container(
            width: isLandscape ? (isCompactHeight ? 30 : 36) : 40,
            height: isLandscape ? (isCompactHeight ? 30 : 36) : 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppShapes.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.percussionAccent,
              size: isCompactHeight ? 16 : 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('WORSHIP LOOP', style: AppTypography.appTitle),
                Text(
                  'Stage Mixer',
                  style: isLandscape
                      ? AppTypography.stageHeadline.copyWith(
                          fontSize: isCompactHeight ? 15 : 18,
                        )
                      : AppTypography.stageHeadline.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
          // Live status badge
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompactHeight ? 8 : 10,
              vertical: isCompactHeight ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: AppColors.statusReadyBg,
              borderRadius: BorderRadius.circular(AppShapes.radiusPill),
              border: Border.all(color: AppColors.statusReadyBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 7, color: AppColors.statusReady),
                const SizedBox(width: 6),
                Text(
                  'READY',
                  style: AppTypography.statusBadge.copyWith(color: AppColors.statusReady),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GLOBAL PERFORMANCE CONTROLS (Landscape Integrated Strip)
  // ===========================================================================
  Widget _buildLandscapeControlStrip({bool isCompactHeight = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: isCompactHeight ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Key selector widget
          Expanded(
            flex: 4,
            child: Semantics(
              label: 'Musical key selection',
              hint: 'Choose the key for the worship set',
              child: Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: AppColors.padAccent, size: 20),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'GLOBAL KEY',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedKey,
                          isDense: true,
                          menuMaxHeight: 360,
                          dropdownColor: AppColors.surfaceElevated,
                          icon: const Icon(
                            Icons.expand_more_rounded,
                            color: AppColors.textSecondary,
                            size: 18,
                          ),
                          style: TextStyle(
                            fontSize: isCompactHeight ? 12 : 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          items: _keys
                              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                          onChanged: _selectKey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: isCompactHeight ? 24 : 32,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // Tempo readout & Tap
          Expanded(
            flex: 4,
            child: Row(
              children: [
                const Icon(Icons.speed_rounded, color: AppColors.percussionAccent, size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TEMPO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      _bpm == null ? '100 BPM' : '${_bpm!.round()} BPM',
                      style: TextStyle(
                        fontSize: isCompactHeight ? 12 : 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Tap tempo',
                    child: SizedBox(
                      height: isCompactHeight ? 32 : 38,
                      child: FilledButton.icon(
                        onPressed: _tapTempo,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.surfaceElevated,
                          foregroundColor: AppColors.percussionAccent,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppShapes.radiusSm),
                          ),
                        ),
                        icon: const Icon(Icons.touch_app_rounded, size: 16),
                        label: const Text(
                          'TAP TEMPO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: isCompactHeight ? 24 : 32,
            color: AppColors.border,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          // Emergency STOP ALL button
          Semantics(
            button: true,
            label: 'Stop all audio',
            hint: 'Immediately stop all pad and percussion loops',
            child: SizedBox(
              height: isCompactHeight ? 34 : 40,
              child: FilledButton.icon(
                onPressed: _stopAll,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  foregroundColor: AppColors.textOnDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppShapes.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.stop_circle_outlined, size: 18),
                label: const Text(
                  'STOP ALL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // GLOBAL PERFORMANCE CONTROLS (Portrait Layout)
  // ===========================================================================
  Widget _buildPortraitKeyAndStop() {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Musical key selection',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppShapes.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note_rounded, color: AppColors.padAccent, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GLOBAL KEY', style: AppTypography.controlLabel),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedKey,
                            isExpanded: true,
                            dropdownColor: AppColors.surfaceElevated,
                            style: AppTypography.musicalKey.copyWith(fontSize: 16),
                            items: _keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                            onChanged: _selectKey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Stop all audio',
          child: SizedBox(
            height: 64,
            child: FilledButton.icon(
              onPressed: _stopAll,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: AppColors.textOnDark,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.radiusMd)),
              ),
              icon: const Icon(Icons.stop_circle_outlined, size: 20),
              label: const Text('STOP ALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortraitTempoPanel() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppShapes.radiusSm),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.speed_rounded, color: AppColors.percussionAccent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TEMPO', style: AppTypography.controlLabel),
                Text(
                  _bpm == null ? 'Tap to set BPM' : '${_bpm!.round()} BPM',
                  style: AppTypography.bpmValue.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Tap tempo',
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _tapTempo,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.percussionAccent,
                  foregroundColor: AppColors.textOnAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.radiusMd)),
                ),
                icon: const Icon(Icons.touch_app_rounded, size: 20),
                label: const Text('TAP TEMPO', style: AppTypography.buttonSmallLabel),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONSOLE SECTION HEADINGS & BAY CONTAINERS
  // ===========================================================================
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(AppShapes.radiusSm),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.sectionHeader.copyWith(fontSize: 13)),
              Text(subtitle, style: AppTypography.sectionSubtitle),
            ],
          ),
        ),
        Text('3 CHANNELS', style: AppTypography.statusBadge.copyWith(color: accentColor)),
      ],
    );
  }

  Widget _buildBayContainer({
    required String title,
    required String subtitle,
    required Color accentColor,
    required List<AudioTrack> tracks,
    required bool isLandscape,
    bool isCompactHeight = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompactHeight ? 6 : AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppShapes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bay Header
          Row(
            children: [
              Container(
                width: 3,
                height: isCompactHeight ? 14 : 18,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: isCompactHeight ? 10 : 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompactHeight ? 8 : 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Text(
                '3 CH',
                style: TextStyle(
                  fontSize: isCompactHeight ? 8 : 9,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompactHeight ? 4 : AppSpacing.sm),
          // 3 Channel Strips side-by-side
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: tracks.map((track) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _buildChannelStrip(
                      track: track,
                      isLandscape: true,
                      isCompactHeight: isCompactHeight,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortraitTrackGrid(List<AudioTrack> tracks, double availableWidth) {
    // 3 columns on standard screens, 2 on very narrow screens
    final columns = availableWidth >= 480 ? 3 : (availableWidth >= 320 ? 3 : 1);
    final itemWidth = (availableWidth - (columns - 1) * 8 - 24) / columns;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tracks.map((track) {
        return SizedBox(
          width: itemWidth,
          child: _buildChannelStrip(
            track: track,
            isLandscape: false,
            isCompactHeight: false,
          ),
        );
      }).toList(),
    );
  }

  // ===========================================================================
  // UNIFIED CHANNEL STRIP (PHASE 3 POLISHED)
  // Structured with DAW-standard visual hierarchy:
  // 1. Channel number/identifier badge (e.g. 01, 02...)
  // 2. Channel name (Pad 1, Percussion 1...)
  // 3. Short descriptive subtitle (Deep / Ambient...)
  // 4. Playback status indicator (Stage LED dot + state label)
  // 5. Large tactile play/stop control (>= 48x48 touch target)
  // 6. Volume fader with accent track
  // 7. Current volume value (numeric % readout)
  // 8. Audio source name / status with graceful ellipsis truncation
  // 9. Import-audio action
  // ===========================================================================
  Widget _buildChannelStrip({
    required AudioTrack track,
    required bool isLandscape,
    bool isCompactHeight = false,
  }) {
    final isPad = track.name.startsWith('pad');
    final activeColor = isPad ? AppColors.padAccent : AppColors.percussionAccent;
    final activeSurface = isPad ? AppColors.padSurfaceActive : AppColors.percSurfaceActive;
    final isPlaying = _playing[track] ?? false;
    final name = _trackName(track);
    final subtitle = _trackSubtitle(track);
    final trackNum = _trackNumber(track);
    final volume = _volumes[track] ?? 0.85;
    final customName = _audioLibrary.nameFor(track);
    final hasCustomAudio = customName != null;
    final audioSourceLabel = customName ?? 'Default Audio';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? (isCompactHeight ? 5 : 7) : AppSpacing.sm,
        vertical: isLandscape ? (isCompactHeight ? 5 : 8) : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isPlaying ? activeSurface : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppShapes.radiusMd),
        border: Border.all(
          color: isPlaying ? activeColor : AppColors.border,
          width: isPlaying ? 1.5 : 1.0,
        ),
        boxShadow: isPlaying
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.12),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1 & 2 & 4. Channel number, Channel name & Playback status indicator
          Row(
            children: [
              // 1. Channel number badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isPlaying ? activeColor.withValues(alpha: 0.18) : AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isPlaying ? activeColor.withValues(alpha: 0.5) : AppColors.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  trackNum,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    fontFamily: 'monospace',
                    color: isPlaying ? activeColor : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // 2. Channel name
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 4. Playback status indicator (Stage LED)
              Semantics(
                label: isPlaying ? 'Status: Active in mix' : 'Status: Ready',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPlaying ? activeColor : const Color(0xFF333E50),
                        boxShadow: isPlaying
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.7),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isPlaying ? 'ON' : 'IDLE',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isPlaying ? activeColor : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // 3. Short descriptive subtitle
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: isPlaying ? AppColors.textSecondary : AppColors.textMuted,
            ),
          ),
          SizedBox(height: isCompactHeight ? 4 : 6),

          // 5. Large Play/Stop Trigger Control (min 48x48)
          Semantics(
            button: true,
            toggled: isPlaying,
            label: '$name playback control',
            value: isPlaying ? 'Playing' : 'Stopped',
            hint: isPlaying ? 'Tap to stop $name' : 'Tap to start $name',
            child: _buildPlayButton(
              track: track,
              isPlaying: isPlaying,
              activeColor: activeColor,
              onTap: () => _toggleTrack(track),
              isLandscape: isLandscape,
              isCompactHeight: isCompactHeight,
            ),
          ),
          SizedBox(height: isCompactHeight ? 4 : 6),

          // 6 & 7. Volume Fader & Current volume value
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'LEVEL',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.textSecondary,
                ),
              ),
              // 7. Numeric readout
              Text(
                '${(volume * 100).round()}%',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  color: isPlaying ? activeColor : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.5,
              activeTrackColor: activeColor,
              inactiveTrackColor: AppColors.surfaceSubtle,
              thumbColor: isPlaying ? activeColor : AppColors.textSecondary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Semantics(
              label: '$name fader',
              value: '${(volume * 100).round()} percent',
              child: Slider(
                value: volume,
                min: 0.0,
                max: 1.0,
                onChanged: (val) => _setTrackVolume(track, val),
              ),
            ),
          ),
          SizedBox(height: isCompactHeight ? 2 : 4),

          // 8. Audio source name or status (Ellipsis truncation)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppShapes.radiusSm),
              border: Border.all(
                color: hasCustomAudio ? activeColor.withValues(alpha: 0.4) : AppColors.borderSubtle,
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasCustomAudio ? Icons.library_music_rounded : Icons.audiotrack_rounded,
                  size: 10,
                  color: hasCustomAudio ? activeColor : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    audioSourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: hasCustomAudio ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isCompactHeight ? 3 : 5),

          // 9. Import-audio action
          Semantics(
            button: true,
            label: 'Import audio for $name',
            hint: 'Choose a custom WAV or MP3 file for $name',
            child: SizedBox(
              height: isCompactHeight ? 26 : 30,
              child: OutlinedButton.icon(
                onPressed: () => _importAudio(track),
                style: OutlinedButton.styleFrom(
                  foregroundColor: activeColor,
                  backgroundColor: AppColors.surfaceSubtle.withValues(alpha: 0.5),
                  side: BorderSide(color: activeColor.withValues(alpha: 0.35), width: 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppShapes.radiusSm)),
                ),
                icon: const Icon(Icons.file_upload_outlined, size: 12),
                label: Text(
                  hasCustomAudio ? 'REPLACE AUDIO' : 'IMPORT AUDIO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton({
    required AudioTrack track,
    required bool isPlaying,
    required Color activeColor,
    required VoidCallback onTap,
    required bool isLandscape,
    required bool isCompactHeight,
  }) {
    final isPad = track.name.startsWith('pad');
    final buttonHeight = isLandscape ? (isCompactHeight ? 48.0 : 64.0) : 52.0;

    return SizedBox(
      height: buttonHeight,
      child: FilledButton(
        onPressed: _busy ? null : onTap,
        style: FilledButton.styleFrom(
          backgroundColor: isPlaying ? activeColor : AppColors.inactiveButton,
          foregroundColor: isPlaying ? AppColors.textOnAccent : AppColors.textPrimary,
          disabledBackgroundColor: AppColors.inactiveTrack,
          elevation: isPlaying ? 2 : 0,
          shadowColor: activeColor.withValues(alpha: 0.5),
          padding: EdgeInsets.symmetric(
            horizontal: 6,
            vertical: isCompactHeight ? 4 : 6,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppShapes.radiusSm),
            side: BorderSide(
              color: isPlaying ? activeColor : AppColors.border,
              width: isPlaying ? 1.5 : 1.0,
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying
                  ? Icons.pause_rounded
                  : (isPad ? Icons.waves_rounded : Icons.play_arrow_rounded),
              size: isCompactHeight ? 20 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              isPlaying ? 'ACTIVE' : 'TRIGGER',
              maxLines: 1,
              style: TextStyle(
                fontSize: isCompactHeight ? 8.5 : 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: isPlaying ? AppColors.textOnAccent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.hearing_rounded, size: AppShapes.iconSm, color: AppColors.textMuted),
        SizedBox(width: 7),
        Flexible(
          child: Text(
            'Designed for quick, confident control on stage',
            textAlign: TextAlign.center,
            style: AppTypography.footer,
          ),
        ),
      ],
    );
  }

  String _trackNumber(AudioTrack track) {
    switch (track) {
      case AudioTrack.pad1: return '01';
      case AudioTrack.pad2: return '02';
      case AudioTrack.pad3: return '03';
      case AudioTrack.percussion1: return '04';
      case AudioTrack.percussion2: return '05';
      case AudioTrack.percussion3: return '06';
    }
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

  String _trackSubtitle(AudioTrack track) {
    switch (track) {
      case AudioTrack.pad1: return 'Deep / Ambient';
      case AudioTrack.pad2: return 'Warm / Synth';
      case AudioTrack.pad3: return 'Air / Shimmer';
      case AudioTrack.percussion1: return 'Click / Metronome';
      case AudioTrack.percussion2: return 'Acoustic Shaker / Tambourine';
      case AudioTrack.percussion3: return 'Full Percussion Loop';
    }
  }
}

