
// lib/screens/outputs_screen.dart

import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';
import '../services/storage_service.dart';
import '../services/haptic_service.dart';

class OutputScreen extends StatefulWidget {
  final StorageService storageService;

  const OutputScreen({super.key, required this.storageService});

  @override
  State<OutputScreen> createState() => _OutputScreenState();
}

class _OutputScreenState extends State<OutputScreen> {
  List<File>_files = [];
  bool _loading = true;
  String _debugInfo ='';

  final AudioPlayer _player = AudioPlayer();

  String? _playingPath;
  bool _isPlaying = false;

  int _storageUsed = 0;

  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  bool _seeking = false;

  @override
  void initState() {
    super.initState();
    _load();

    _player.onPlayerStateChanged.listen((s) {
      if (mounted) {
        setState(() => _isPlaying = s == PlayerState.playing);
      }
    });

    _player.onPositionChanged.listen((p) {
      if (mounted && !_seeking) {
        setState(() => _pos = p);
      }
    });

    _player.onDurationChanged.listen((d) {
      if (mounted) {
        setState(() => _dur = d);
      }
    });

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingPath = null;
          _isPlaying = false;
          _pos = Duration.zero;
          _dur = Duration.zero;
        });
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await widget.storageService.listOutputFiles();
    final storage = await widget.storageService.getStorageUsed();
    setState(() {
      _files = files;
      _storageUsed = storage;
      _loading = false;
    });
  }

  // ── Playback ──────────────────────────────────────────────────────────────────

  Future<void> _play(String path) async {
    if (_playingPath == path && _isPlaying) {
      await _player.pause();
      return;
    }
    if (_playingPath == path && !_isPlaying) {
      await _player.resume();
      return;
    }
    await HapticService.play();
    setState(() {
      _playingPath = path;
      _pos = Duration.zero;
      _dur = Duration.zero;
    });
    await _player.play(DeviceFileSource(path));
  }

  Future<void> _stop() async {
    await HapticService.stop();
    await _player.stop();
    setState(() {
      _playingPath = null;
      _isPlaying = false;
      _pos = Duration.zero;
      _dur = Duration.zero;
    });
  }

  Future<void> _seekTo(double ms) async {
    await HapticService.seek();
    final pos = Duration(milliseconds: ms.toInt());
    await _player.seek(pos);
    setState(() => _pos = pos);
  }

  // ── Save to Phone ─────────────────────────────────────────────────────────────

  Future<void> _saveToPhone(File file) async {
    await HapticService.medium();

    // Request storage permission on Android < 13

    if (Platform.isAndroid) {
      PermissionStatus status;

      if (await Permission.audio.isGranted) {
        status = PermissionStatus.granted;
      } else {
        status = await Permission.audio.request();
      }

      if (!status.isGranted) {
        _showSnack('❌ Permission denied', error: true);
        return;
      }
    }

    setState(() => _loading = true);

    try {
      final bytes = await file.readAsBytes();
      final fileName = file.path.split('/').last;

      // SaverGallery saves to phone's Downloads folder (visible in file manager)
      final result = await SaverGallery.saveFile(
        // fileservice: 'mp3',
        fileName: fileName.replaceAll('.mp3', ''),
        filePath: file.path,
        androidRelativePath: 'Music/MusicCutter',
        skipIfExists: false,
      );

      if (result.isSuccess) {
        await HapticService.success();
        _showSnack(' Saved to Music/MusicCutter folder', success: true);
      } else {
        await HapticService.error();
        _showSnack(' Failed to save file', error: true);
      }
    } catch (e) {
      await HapticService.error();
      _showSnack('Error: $e', error: true);
    }

    setState(() => _loading = false);
  }

  // ── Share ─────────────────────────────────────────────────────────────────────

  Future<void> _shareFile(File file) async {
    await HapticService.medium();

    try {
      final xFile = XFile(
        file.path,
        mimeType: 'audio/mpeg',
        name: file.path.split('/').last,
      );

      // Opens system share sheet — WhatsApp, Telegram, Gmail, Bluetooth etc
      await Share.shareXFiles(
        [xFile],
        subject: 'Music Cutter — ${file.path.split('/').last}',
        text: 'Check out this audio I created with Music Cutter!',
      );
    } catch (e) {
      await HapticService.error();
      _showSnack(' Share failed: $e', error: true);
    }
  }

  // ── Share Multiple ────────────────────────────────────────────────────────────

  Future<void> _shareMultiple(List<File> files) async {
    await HapticService.medium();

    try {
      final xFiles = files
          .map((f) => XFile(
        f.path,
        mimeType: 'audio/mpeg',
        name: f.path.split('/').last,
      ))
          .toList();

      await Share.shareXFiles(
        xFiles,
        subject: 'Music Cutter — ${files.length} audio files',
        text: 'Check out these audios I created with Music Cutter!',
      );
    } catch (e) {
      _showSnack('❌ Share failed: $e', error: true);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────────

  Future<void> _delete(File f) async {
    await HapticService.warning();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
          SizedBox(width: 8),
          Text('Delete File?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(f.path.split('/').last,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(widget.storageService.formatBytes(f.statSync().size),
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 8),
          const Text('This file will be permanently removed from app storage.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await HapticService.projectDeleted();
    if (_playingPath == f.path) await _stop();
    await f.delete();
    _load();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSnack(String msg,
      {bool success = false, bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: success
          ? const Color(0xFF2E7D32)
          : error
          ? Colors.redAccent
          : const Color(0xFF2A2A3E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: const Color(0xFF6C63FF),
      child: Column(children: [
        // Storage info banner
        _storageBanner(),

        // Now playing card
        if (_playingPath != null) _nowPlayingCard(),

        // File list or empty state
        if (_files.isEmpty)
          Expanded(child: _emptyState())
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
              itemCount: _files.length,
              itemBuilder: (_, i) => _fileCard(_files [i]),
            ),
          ),
      ]),
    );
  }

  // ── Storage banner ────────────────────────────────────────────────────────────

  Widget _storageBanner() => Container(
    margin: const EdgeInsets.all(14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1C30),
      borderRadius: BorderRadius.circular(14),
      border:
      Border.all(color: const Color(0xFF6C63FF).withOpacity(0.25)),
    ),
    child: Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.storage,
            color: Color(0xFF6C63FF), size: 22),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('App Storage',
                  style:
                  TextStyle(color: Colors.white54, fontSize: 11)),
              Text(widget.storageService.formatBytes(_storageUsed),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${_files.length} file${_files.length != 1 ? 's' : ''}',
            style: const TextStyle(
                color: Colors.white54, fontSize: 13)),
        if (_files.isNotEmpty)
          GestureDetector(
            onTap: () => _shareMultiple(_files),
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.share, color: Color(0xFF6C63FF), size: 12),
                SizedBox(width: 4),
                Text('Share All',
                    style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
      ]),
    ]),
  );

  // ── Now playing card ──────────────────────────────────────────────────────────

  Widget _nowPlayingCard() {
    final name = _playingPath!.split('/').last;
    final totalMs = _dur.inMilliseconds.toDouble();
    final posMs = _pos.inMilliseconds.toDouble();

    // totalMs > 0 ? (posMs / totalMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF6C63FF).withOpacity(0.18),
          const Color(0xFFFF6584).withOpacity(0.18),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.45),
            width: 1.3),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.15),
              blurRadius: 14)
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFFFF6584)]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.music_note,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
              // Close
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close,
                    color: Colors.white38, size: 20),
                onPressed: _stop,
              ),
            ]),

            const SizedBox(height: 12),

            // Seek slider
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF6C63FF),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFF6C63FF),
                overlayColor:
                const Color(0xFF6C63FF).withOpacity(0.2),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8),
                overlayShape:
                const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: posMs.clamp(0, totalMs > 0 ? totalMs : 1),
                min: 0,
                max: totalMs > 0 ? totalMs : 1,
                onChangeStart: (_) =>
                    setState(() => _seeking = true),
                onChanged: (v) => setState(() =>
                _pos = Duration(milliseconds: v.toInt())),
                onChangeEnd: (v) {
                  setState(() => _seeking = false);
                  _seekTo(v);
                },
              ),
            ),

            // Time labels
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(_pos),
                      style: const TextStyle(
                          color: Color(0xFF6C63FF),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace')),
                  Text(_fmt(_dur),
                      style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          fontFamily: 'monospace')),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Controls
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              // Rewind 10s
              IconButton(
                icon: const Icon(Icons.replay_10,
                    color: Colors.white54, size: 28),
                onPressed: () {
                  final np = _pos - const Duration(seconds: 10);
                  _seekTo(np.isNegative
                      ? 0
                      : np.inMilliseconds.toDouble());
                },
              ),
              const SizedBox(width: 8),

              // Play / Pause big button
              GestureDetector(
                onTap: () => _play(_playingPath!),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [
                      Color(0xFF6C63FF),
                      Color(0xFFFF6584)
                    ]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:
                          const Color(0xFF6C63FF).withOpacity(0.4),
                          blurRadius: 12)
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Forward 10s
              IconButton(
                icon: const Icon(Icons.forward_10,
                    color: Colors.white54, size: 28),
                onPressed: () {
                  final np = _pos + const Duration(seconds: 10);
                  final maxMs = _dur.inMilliseconds.toDouble();
                  _seekTo(np.inMilliseconds > maxMs
                      ? maxMs
                      : np.inMilliseconds.toDouble());
                },
              ),
            ]),

            const SizedBox(height: 8),

            // ✅ Save & Share row for currently playing file
            _actionRow(File(_playingPath!)),
          ]),
    );
  }

  // ── File card ─────────────────────────────────────────────────────────────────

  Widget _fileCard(File f) {
    final name = f.path.split('/').last;
    final size = widget.storageService.formatBytes(f.statSync().size);
    final modified = f.statSync().modified;
    final isActive = _playingPath == f.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFF6C63FF).withOpacity(0.7)
              : Colors.white.withOpacity(0.05),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: isActive
            ? [
          BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.15),
              blurRadius: 14)
        ]
            : null,
      ),
      child: Column(children: [
        // Main row
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            // File icon / equalizer
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: isActive
                        ? [
                      const Color(0xFF6C63FF),
                      const Color(0xFFFF6584)
                    ]
                        : [
                      const Color(0xFF252545),
                      const Color(0xFF1C1C30)
                    ]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isActive && _isPlaying
                    ? Icons.graphic_eq
                    : Icons.audio_file,
                color: isActive ? Colors.white : const Color(0xFF6C63FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : Colors.white70,
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.w500),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(children: [
                      _miniChip(Icons.storage, size),
                      const SizedBox(width: 6),
                      _miniChip(Icons.access_time,
                          _timeAgo(modified)),
                    ]),
                  ]),
            ),

            // Play button
            IconButton(
              icon: Icon(
                isActive && _isPlaying
                    ? Icons.pause_circle
                    : Icons.play_circle,
                color: isActive
                    ? const Color(0xFF6C63FF)
                    : Colors.white38,
                size: 34,
              ),
              onPressed: () => _play(f.path),
            ),
          ]),
        ),

        // ✅ Action buttons row — Save + Share + Delete
        Container(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: _actionRow(f),
        ),
      ]),
    );
  }

  // ── Action row — Save to Phone + Share + Delete ───────────────────────────────

  Widget _actionRow(File f) => Row(children: [
    // ✅ Save to Phone

    Expanded(
      child: ElevatedButton.icon(
        onPressed: () => _saveToPhone(f),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.download, size: 15),
        label: const Text('Save',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ),
    const SizedBox(width: 8),


    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _shareFile(f),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF38EF7D)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: const Icon(Icons.share, color: Color(0xFF38EF7D), size: 15),
        label: const Text('Share',
            style: TextStyle(
                color: Color(0xFF38EF7D),
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    ),
    const SizedBox(width: 8),

    // Delete

    OutlinedButton(
      onPressed: () => _delete(f),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.redAccent),
        padding: const EdgeInsets.all(10),
        minimumSize: const Size(44, 44),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: const Icon(Icons.delete_outline,
          color: Colors.redAccent, size: 18),
    ),
  ]);

  // ── Empty state ───────────────────────────────────────────────────────────────


  Widget _emptyState() => Center(
    child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF6C63FF).withOpacity(0.12),
                const Color(0xFFFF6584).withOpacity(0.12),
              ]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.audio_file,
                size: 60, color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 20),
          const Text('No exports yet',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Merge songs in a project to\ncreate MP3 files here',
            style: TextStyle(color: Colors.white38, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // ✅ Debug info card — shows the output folder path
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white10),
            ),
            child: Column(children: [
              const Row(children: [
                Icon(Icons.info_outline, color: Colors.white38, size: 14),
                SizedBox(width: 6),
                Text('Storage Path',
                    style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text(
                _debugInfo,
                style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    fontFamily: 'monospace'),
              ),
            ]),
          ),
        ]),
  );
  // ── Small widgets ─────────────────────────────────────────────────────────────

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) =>
      filled
          ? ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, size: 15),
        label: Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold)),
      )
          : OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.6)),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        icon: Icon(icon, color: color, size: 15),
        label: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      );

  Widget _actionIconBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) =>
      OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.all(10),
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: Icon(icon, color: color, size: 18),
      );

  Widget _miniChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 11, color: Colors.white30),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 11)),
    ],
  );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}