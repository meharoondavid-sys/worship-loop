import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_engine.dart';

/// Imports and persists user audio in the app-private documents directory.
class CustomAudioLibrary {
  static const _preferencesKey = 'worship_loop.custom_audio_paths.v1';

  final Map<AudioTrack, String> _paths = {};

  Map<AudioTrack, String> get paths => Map.unmodifiable(_paths);

  String? pathFor(AudioTrack track) => _paths[track];

  String? nameFor(AudioTrack track) {
    final path = _paths[track];
    return path == null ? null : p.basename(path);
  }

  /// Restores saved mappings and prepares each existing file in its track.
  /// Missing files are removed from preferences rather than breaking startup.
  Future<void> restore(AudioEngine engine) async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_preferencesKey);
    if (stored == null) return;

    final decoded = jsonDecode(stored);
    if (decoded is! Map<String, dynamic>) {
      await preferences.remove(_preferencesKey);
      return;
    }

    var changed = false;
    for (final entry in decoded.entries) {
      final track = _trackFromName(entry.key);
      final path = entry.value;
      if (track == null || path is! String) {
        changed = true;
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        changed = true;
        continue;
      }
      try {
        await engine.loadFile(track, file.path);
        _paths[track] = file.path;
      } catch (_) {
        // Keep a valid file mapping even if a decoder cannot prepare it yet.
        _paths[track] = file.path;
      }
    }
    if (changed) await _save(preferences);
  }

  /// Opens the device picker, copies the selected WAV/MP3 into app-private
  /// storage, loads it into [track], and persists the mapping.
  Future<String?> importForTrack(AudioEngine engine, AudioTrack track) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav', 'mp3'],
      allowMultiple: false,
      withData: false,
    );
    if (selection == null || selection.files.isEmpty) return null;

    final picked = selection.files.single;
    final sourcePath = picked.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw StateError('The selected audio file could not be accessed.');
    }

    final extension = p.extension(picked.name).toLowerCase();
    if (extension != '.wav' && extension != '.mp3') {
      throw FormatException('Choose a WAV or MP3 audio file.');
    }

    final documents = await getApplicationDocumentsDirectory();
    final audioDirectory = Directory(p.join(documents.path, 'custom_audio'));
    await audioDirectory.create(recursive: true);

    final safeBaseName = p.basenameWithoutExtension(picked.name)
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final uniqueName =
        '${track.name}_${DateTime.now().microsecondsSinceEpoch}_$safeBaseName$extension';
    final destination = File(p.join(audioDirectory.path, uniqueName));
    await File(sourcePath).copy(destination.path);

    try {
      await engine.loadFile(track, destination.path);
      _paths[track] = destination.path;
      final preferences = await SharedPreferences.getInstance();
      await _save(preferences);
      return destination.path;
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<void> removeForTrack(AudioTrack track) async {
    final oldPath = _paths.remove(track);
    if (oldPath != null) {
      final file = File(oldPath);
      if (await file.exists()) await file.delete();
    }
    final preferences = await SharedPreferences.getInstance();
    await _save(preferences);
  }

  Future<void> _save(SharedPreferences preferences) async {
    final encoded = <String, String>{
      for (final entry in _paths.entries) entry.key.name: entry.value,
    };
    await preferences.setString(_preferencesKey, jsonEncode(encoded));
  }

  AudioTrack? _trackFromName(String name) {
    for (final track in AudioTrack.values) {
      if (track.name == name) return track;
    }
    return null;
  }
}
