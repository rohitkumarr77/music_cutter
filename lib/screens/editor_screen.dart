
// lib/screens/editor_screen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:file_picker/file_picker.dart';
import 'package:music_cutter/services/haptic_service.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import '../models/song_model.dart';
import '../services/storage_service.dart';
import '../services/audio_service.dart';
import '../services/permission_service.dart';
import '../widgets/song_tile.dart';
import '../widgets/trim_editor.dart';
import '../widgets/export_dialog.dart';

class EditorScreen extends StatefulWidget {
  final ParodyProject project;
  const EditorScreen({super.key, required this.project});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with WidgetsBindingObserver {
  late ParodyProject _project;
  final StorageService _storage = StorageService();
  final AudioService _audio = AudioService();
  final PermissionService _permission = PermissionService();

  String? _playingSongId;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _songDuration = Duration.zero;

  // Merge state
  bool _isMerging = false;
  double _mergeProgress = 0;
  String _mergeStatus = '';
  String? _mergedFilePath;
  bool _isPlayingMerged = false;

  // Mini player seek
  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _project = widget.project;

    // Restore merged path if it exists on disk
    if (_project.outputPath != null &&
        File(_project.outputPath!).existsSync()) {
      _mergedFilePath = _project.outputPath;
    }

    _audio.player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audio.player.onPositionChanged.listen((pos) {
      if (mounted && !_seeking) setState(() => _position = pos);
    });
    _audio.player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _songDuration = dur);
    });
    _audio.player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _isPlayingMerged = false;
          _position = Duration.zero;
        });
      }
    });
  }

  // ── Lifecycle — save on background ───────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _saveProject();
    }
  }

  // ── Pick & add multiple songs ─────────────────────────────────────────────────

  Future<void> _pickSongs() async {
    final hasPermission = await _permission.requestStoragePermission();
    if (!hasPermission) {
      _showPermissionDenied();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() {
      _isMerging = true;
      _mergeProgress = 0;
      _mergeStatus = 'Copying ${result.files.length} song(s)...';
    });

    int done = 0;
    for (final file in result.files) {
      if (file.path == null) continue;

      final copiedPath =
      await _storage.copyAudioToApp(file.path!, _project.id);
      final info = await _audio.getAudioInfo(copiedPath);
      final duration = info['duration'] as Duration;

      final song = SongModel(
        id: const Uuid().v4(),
        name: file.name.replaceAll(
            RegExp(r'\.(mp3|m4a|wav|aac|ogg|flac)$',
                caseSensitive: false),
            ''),
        filePath: copiedPath,
        duration: duration,
        startTrim: Duration.zero,
        endTrim: duration > Duration.zero
            ? duration
            : const Duration(seconds: 30),
        order: _project.songs.length,
      );

      _project.songs.add(song);
      done++;

      // Save after each song — partial progress never lost
      await _saveProject();

      setState(() {
        _mergeProgress = done / result.files.length;
        _mergeStatus = 'Added $done / ${result.files.length}';
      });
    }

    setState(() {
      _isMerging = false;
      _mergeStatus = '';
    });

    if (_project.songs.length >= 2) {
      _showMergeBanner();
    }
  }

  // ── Show merge suggestion banner ──────────────────────────────────────────────

  void _showMergeBanner() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2A2A3E),
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        content: const Row(
          children: [
            Icon(Icons.merge_type, color: Color(0xFF6C63FF)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap "Merge All" to combine songs into one file!',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'MERGE',
          textColor: const Color(0xFF6C63FF),
          onPressed: _mergeAllSongs,
        ),
      ),
    );
  }

  // ── Merge all songs into one file ─────────────────────────────────────────────

  Future<void> _mergeAllSongs() async {
    if (_project.songs.isEmpty) {
      _showSnack('Add at least one song first');
      return;
    }
    if (_project.songs.length == 1) {
      _showSnack('Add more songs to merge');
      return;
    }

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => ExportDialog(projectName: _project.name),
    );
    if (name == null) return;

    await _audio.stop();
    setState(() {
      _isMerging = true;
      _mergeProgress = 0;
      _mergeStatus = 'Merging ${_project.songs.length} songs...';
      _mergedFilePath = null;
    });

    final timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted && _mergeProgress < 0.88) {
        setState(() => _mergeProgress += 0.015);
      }
    });

    final outputDir = await _storage.getOutputDir();
    final outputPath = '${outputDir.path}/$name.mp3';

    final result = await _audio.mergeAudioFiles(
      songs: _project.songs,
      outputPath: outputPath,
    );

    timer.cancel();

    setState(() {
      _isMerging = false;
      _mergeProgress = 1.0;
      _mergeStatus = '';
      if (result != null) {
        _mergedFilePath = result;
        _project.outputPath = result;
      }
    });

    // Save merged path so it survives restart
    await _saveProject();

    if (result != null) {
      HapticService.medium();
      _showSnack('✅ Merged: $name.mp3', success: true);
    } else {
      _showSnack('❌ Merge failed. Check song files.');
    }
  }

  // ── Duplicate a song ──────────────────────────────────────────────────────────

  Future<void> _duplicateSong(SongModel song) async {
    final newSong = SongModel(
      id: '${song.id}_copy_${DateTime.now().millisecondsSinceEpoch}',
      name: '${song.name} (copy)',
      filePath: song.filePath,
      duration: song.duration,
      startTrim: song.startTrim,
      endTrim: song.endTrim,
      volume: song.volume,
      order: _project.songs.length,
    );
    setState(() => _project.songs.add(newSong));
    await _saveProject();
    _showSnack('Duplicated: ${song.name}', success: true);
  }

  // ── Play merged file ──────────────────────────────────────────────────────────

  Future<void> _playMergedFile() async {
    if (_mergedFilePath == null) return;
    if (_isPlayingMerged && _isPlaying) {
      await _audio.pause();
    } else {
      setState(() {
        _playingSongId = null;
        _isPlayingMerged = true;
        _position = Duration.zero;
      });
      await _audio.play(_mergedFilePath!);
    }
  }

  // ── Individual song playback ──────────────────────────────────────────────────

  Future<void> _playSong(SongModel song) async {
    if (_playingSongId == song.id && _isPlaying) {
      await _audio.pause();
    } else {
      setState(() {
        _playingSongId = song.id;
        _isPlayingMerged = false;
        _position = Duration.zero;
      });
      await _audio.play(song.filePath, startAt: song.startTrim);
    }
  }

  Future<void> _removeSong(SongModel song) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Remove Song?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('"${song.name}" will be removed from this project.',
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _project.songs.remove(song));
    if (_playingSongId == song.id) await _audio.stop();
    await _saveProject();
  }

  Future<void> _saveProject() async {
    await _storage.saveProject(_project);
    if (mounted) setState(() {});
  }

  void _openTrimEditor(SongModel song) async {
    final updated = await showModalBottomSheet<SongModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrimEditor(song: song, audioService: _audio),
    );
    if (updated != null) {
      final idx = _project.songs.indexWhere((s) => s.id == song.id);
      if (idx >= 0) {
        setState(() => _project.songs[idx] = updated);
        await _saveProject();
      }
    }
  }

  void _renameSong(SongModel song, String newName) {
    final idx = _project.songs.indexWhere((s) => s.id == song.id);
    if (idx >= 0) {
      setState(() =>
      _project.songs[idx] = song.copyWith(name: newName));
      _saveProject();
    }
  }

  // ── Seek in mini player ───────────────────────────────────────────────────────

  Future<void> _seekTo(double ms) async {
    final pos = Duration(milliseconds: ms.toInt());
    await _audio.seek(pos);
    setState(() => _position = pos);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  void _showPermissionDenied() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Permission Required',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Storage permission is needed to access audio files.\nPlease grant it in Settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF)),
            onPressed: () {
              Navigator.pop(ctx);
              ph.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: success
          ? const Color(0xFF2E7D32)
          : const Color(0xFF2A2A3E),
      behavior: SnackBarBehavior.floating,
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            await _saveProject();
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text(_project.name,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_project.songs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _totalDurationChip(),
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildToolbar(),
              if (_mergedFilePath != null &&
                  File(_mergedFilePath!).existsSync())
                _buildMergedCard(),
              Expanded(child: _buildSongList()),
              if (_playingSongId != null || _isPlayingMerged)
                _buildMiniPlayer(),
            ],
          ),
          if (_isMerging) _buildMergeOverlay(),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF1A1A2E),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pickSongs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add Songs',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          if (_project.songs.length >= 2) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _mergeAllSongs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6584),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.merge_type),
                label: const Text('Merge All',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Merged file card ──────────────────────────────────────────────────────────

  Widget _buildMergedCard() {
    final fileName = _mergedFilePath!.split('/').last;
    final file = File(_mergedFilePath!);
    final size =
    file.existsSync() ? _storage.formatBytes(file.statSync().size) : '';
    final isActive = _isPlayingMerged && _isPlaying;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6584).withOpacity(0.15),
            const Color(0xFF6C63FF).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFFF6584).withOpacity(0.5), width: 1.3),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF6584).withOpacity(0.1),
              blurRadius: 12)
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _playMergedFile,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF6584), Color(0xFF6C63FF)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFFF6584).withOpacity(0.3),
                      blurRadius: 8)
                ],
              ),
              child: Icon(
                isActive ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Merged File Ready',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 3),
                Text(fileName,
                    style:
                    const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                if (size.isNotEmpty)
                  Text(size,
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh,
                color: Color(0xFFFF6584), size: 20),
            tooltip: 'Re-merge',
            onPressed: _mergeAllSongs,
          ),
        ],
      ),
    );
  }

  // ── Song list ─────────────────────────────────────────────────────────────────

  Widget _buildSongList() {
    if (_project.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_music,
                size: 70,
                color: const Color(0xFF6C63FF).withOpacity(0.4)),
            const SizedBox(height: 16),
            const Text('No songs added',
                style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Tap "Add Songs" to pick multiple audio files',
                style: TextStyle(color: Colors.white24, fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickSongs,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Add Multiple Songs',
                  style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                '${_project.songs.length} Song${_project.songs.length > 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
              const Spacer(),
              const Text('Hold & drag to reorder',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
            onReorder: (oldIdx, newIdx) {
              if (newIdx > oldIdx) newIdx--;
              setState(() {
                final item = _project.songs.removeAt(oldIdx);
                _project.songs.insert(newIdx, item);
                for (int i = 0; i < _project.songs.length; i++) {
                  _project.songs[i] =
                      _project.songs[i].copyWith(order: i);
                }
              });
              _saveProject();
            },
            itemCount: _project.songs.length,
            itemBuilder: (ctx, i) {
              final song = _project.songs[i];
              return SongTile(
                key: ValueKey(song.id),
                song: song,
                index: i,
                isPlaying: _playingSongId == song.id && _isPlaying,
                onPlay: () => _playSong(song),
                onTrim: () => _openTrimEditor(song),
                onRemove: () => _removeSong(song),
                onVolumeChange: (v) {
                  setState(() =>
                  _project.songs[i] = song.copyWith(volume: v));
                  _saveProject();
                },
                onDuplicate: () => _duplicateSong(song),
                onRename: (name) => _renameSong(song, name),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Mini player with seek bar ─────────────────────────────────────────────────

  Widget _buildMiniPlayer() {
    final String label = _isPlayingMerged
        ? (_mergedFilePath?.split('/').last ?? 'Merged File')
        : (_project.songs
        .firstWhere((s) => s.id == _playingSongId,
        orElse: () => _project.songs.first)
        .name);

    final totalMs = _songDuration.inMilliseconds.toDouble();
    final posMs = _position.inMilliseconds.toDouble();

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).padding.bottom,),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        border: Border(
            top: BorderSide(
                color: const Color(0xFF6C63FF).withOpacity(0.3))),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Song name + controls row
          // seek bar



          Row(

            children: [
              Container(


                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isPlayingMerged
                        ? [
                      const Color(0xFFFF6584),
                      const Color(0xFF6C63FF)
                    ]
                        : [
                      const Color(0xFF6C63FF),
                      const Color(0xFFFF6584)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),

                child: const Icon(Icons.music_note,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    Text(
                      '${_fmt(_position)} / ${_fmt(_songDuration)}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
              // Rewind 10s
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.replay_10,
                    color: Colors.white38, size: 26),
                onPressed: () {
                  final np = _position - const Duration(seconds: 10);
                  _seekTo(np.isNegative ? 0 : np.inMilliseconds.toDouble());
                },
              ),
              const SizedBox(width: 4),
              // Play / Pause
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: const Color(0xFF6C63FF),
                  size: 38,
                ),
                onPressed: () =>
                _isPlaying ? _audio.pause() : _audio.resume(),
              ),
              const SizedBox(width: 4),
              // Forward 10s
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.forward_10,
                    color: Colors.white38, size: 26),
                onPressed: () {
                  final np = _position + const Duration(seconds: 10);
                  final maxMs = _songDuration.inMilliseconds.toDouble();
                  _seekTo(np.inMilliseconds > maxMs
                      ? maxMs
                      : np.inMilliseconds.toDouble());
                },
              ),
              const SizedBox(width: 4),
              // Stop
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.stop_circle,
                    color: Colors.white24, size: 28),
                onPressed: () {
                  _audio.stop();
                  setState(() {
                    _playingSongId = null;
                    _isPlayingMerged = false;
                    _position = Duration.zero;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 5),

          SliderTheme(

            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _isPlayingMerged
                  ? const Color(0xFFFF6584)
                  : const Color(0xFF6C63FF),
              inactiveTrackColor: Colors.white10,
              thumbColor: _isPlayingMerged
                  ? const Color(0xFFFF6584)
                  : const Color(0xFF6C63FF),
              overlayColor: const Color(0xFF6C63FF).withOpacity(0.15),
              trackHeight: 3,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape:
              const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: posMs.clamp(0, totalMs > 0 ? totalMs : 1),
              min: 0,
              max: totalMs > 0 ? totalMs : 1,
              onChangeStart: (_) => setState(() => _seeking = true),
              onChanged: (v) => setState(
                      () => _position = Duration(milliseconds: v.toInt())),
              onChangeEnd: (v) {
                setState(() => _seeking = false);
                _seekTo(v);
              },
            ),
          ),

        ],
      ),
    );
  }

  // ── Merge overlay ─────────────────────────────────────────────────────────────

  Widget _buildMergeOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.merge_type,
                  color: Color(0xFF6C63FF), size: 48),
              const SizedBox(height: 14),
              Text(
                _mergeStatus,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _mergeProgress,
                  backgroundColor: Colors.white12,
                  valueColor:
                  const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(_mergeProgress * 100).toInt()}%',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Total duration chip ───────────────────────────────────────────────────────

  Widget _totalDurationChip() {
    final total = _project.totalDuration;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, size: 14, color: Color(0xFF6C63FF)),
          const SizedBox(width: 4),
          Text(_fmt(total),
              style: const TextStyle(
                  color: Color(0xFF6C63FF), fontSize: 12)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audio.dispose();
    super.dispose();
  }
}
