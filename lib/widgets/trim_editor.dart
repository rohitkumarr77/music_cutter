// lib/widgets/trim_editor.dart

import 'package:flutter/material.dart';
import '../models/song_model.dart';
import '../services/audio_service.dart';

class TrimEditor extends StatefulWidget {
  final SongModel song;
  final AudioService audioService;

  const TrimEditor({super.key, required this.song, required this.audioService});

  @override
  State<TrimEditor> createState() => _TrimEditorState();
}

class _TrimEditorState extends State<TrimEditor> {
  late Duration _start;
  late Duration _end;
  late Duration _totalDuration;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _start = widget.song.startTrim;
    _end = widget.song.endTrim;
    _totalDuration = widget.song.duration ?? const Duration(minutes: 3);

    // Clamp values
    if (_end > _totalDuration) _end = _totalDuration;
    if (_start > _end) _start = Duration.zero;
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _totalMs => _totalDuration.inMilliseconds.toDouble().clamp(1, double.infinity);

  void _previewTrim() async {
    if (_isPlaying) {
      await widget.audioService.stop();
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    await widget.audioService.play(widget.song.filePath, startAt: _start);

    // Auto-stop at end trim
    final trimMs = (_end - _start).inMilliseconds;
    Future.delayed(Duration(milliseconds: trimMs), () async {
      if (mounted && _isPlaying) {
        await widget.audioService.stop();
        setState(() => _isPlaying = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trimDuration = _end - _start;
    final startRatio = _start.inMilliseconds / _totalMs;
    final endRatio = _end.inMilliseconds / _totalMs;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // padding: EdgeInsets.only(
      //   bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      // ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.of(context).padding.bottom,),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.content_cut, color: Color(0xFF6C63FF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.song.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _previewTrim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFFFF6584)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isPlaying ? Icons.stop : Icons.play_arrow,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isPlaying ? 'Stop' : 'Preview',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Visual waveform bar
                _buildWaveformBar(startRatio, endRatio),
                const SizedBox(height: 8),

                // Time labels
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(Duration.zero),
                        style: const TextStyle(color: Colors.white24, fontSize: 11)),
                    Text(_fmt(_totalDuration),
                        style: const TextStyle(color: Colors.white24, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 24),

                // Start trim
                _buildSliderRow(
                  label: 'Start',
                  icon: Icons.skip_next,
                  value: _start.inMilliseconds.toDouble(),
                  min: 0,
                  max: _end.inMilliseconds.toDouble() - 1000,
                  color: const Color(0xFF6C63FF),
                  displayValue: _fmt(_start),
                  onChanged: (v) => setState(
                          () => _start = Duration(milliseconds: v.toInt())),
                ),
                const SizedBox(height: 16),

                // End trim
                _buildSliderRow(
                  label: 'End',
                  icon: Icons.skip_previous,
                  value: _end.inMilliseconds.toDouble(),
                  min: _start.inMilliseconds.toDouble() + 1000,
                  max: _totalMs,
                  color: const Color(0xFFFF6584),
                  displayValue: _fmt(_end),
                  onChanged: (v) =>
                      setState(() => _end = Duration(milliseconds: v.toInt())),
                ),
                const SizedBox(height: 20),

                // Duration info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoItem('Start', _fmt(_start), const Color(0xFF6C63FF)),
                      _divider(),
                      _infoItem('Duration', _fmt(trimDuration), Colors.white),
                      _divider(),
                      _infoItem('End', _fmt(_end), const Color(0xFFFF6584)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.white54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          widget.audioService.stop();
                          Navigator.pop(
                            context,
                            widget.song.copyWith(
                              startTrim: _start,
                              endTrim: _end,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 18),
                            SizedBox(width: 6),
                            Text('Apply Trim'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveformBar(double startRatio, double endRatio) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Fake waveform bars
            Row(
              children: List.generate(60, (i) {
                final heights = [0.3, 0.6, 0.9, 0.5, 0.7, 0.4, 0.8, 0.3, 0.6, 0.9];
                final h = heights[i % heights.length];
                final ratio = i / 60.0;
                final inRange = ratio >= startRatio && ratio <= endRatio;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5, vertical: 4),
                    decoration: BoxDecoration(
                      color: inRange
                          ? const Color(0xFF6C63FF).withOpacity(0.7)
                          : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    height: 50 * h,
                  ),
                );
              }),
            ),
            // Start handle
            Positioned(
              left: startRatio * (MediaQuery.of(context).size.width - 40),
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: const Color(0xFF6C63FF),
              ),
            ),
            // End handle
            Positioned(
              left: endRatio * (MediaQuery.of(context).size.width - 40),
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: const Color(0xFFFF6584),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required Color color,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Icon(icon, color: color, size: 16),
              Text(label, style: TextStyle(color: color, fontSize: 10)),
            ],
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: Colors.white12,
              thumbColor: color,
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 48,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _divider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.white12,
    );
  }
}