// lib/widgets/song_tile.dart

import 'package:flutter/material.dart';

import '../models/song_model.dart';

class SongTile extends StatefulWidget {
  final SongModel song;
  final int index;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onTrim;
  final VoidCallback onRemove;
  final ValueChanged<double> onVolumeChange;
  final VoidCallback? onDuplicate;
  final ValueChanged<String>? onRename;

  const SongTile({
    super.key,
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.onPlay,
    required this.onTrim,
    required this.onRemove,
    required this.onVolumeChange,
    this.onDuplicate,
    this.onRename,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _barCtrl;
  final _renameCtrl = TextEditingController();

  static const _palettes = [
    [Color(0xFF6C63FF), Color(0xFF9B59F5)],
    [Color(0xFFFF6584), Color(0xFFFF9A70)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFF7971E), Color(0xFFFFD200)],
    [Color(0xFF43C6AC), Color(0xFF3A1C71)],
    [Color(0xFFEE0979), Color(0xFFFF6A00)],
    [Color(0xFF4776E6), Color(0xFF8E54E9)],
    [Color(0xFF00B4DB), Color(0xFF0083B0)],
  ];

  List<Color> get _c => _palettes[widget.index % _palettes.length];

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
          '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  double get _trimPercent {
    if (widget.song.duration?.inMilliseconds == 0) return 0;
    return (widget.song.trimmedDuration.inMilliseconds /
        widget.song.duration!.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String get _volLabel {
    final v = widget.song.volume;
    if (v == 0) return 'Muted';
    if (v < 0.5) return 'Low';
    if (v <= 1.0) return 'Normal';
    return 'Boosted';
  }

  Color get _volColor {
    final v = widget.song.volume;
    if (v == 0) return Colors.white24;
    if (v < 0.5) return Colors.blueAccent;
    if (v <= 1.0) return _c[0];
    return Colors.orangeAccent;
  }

  // ── Rename dialog ─────────────────────────────────────────────────────────────

  Future<void> _showRename() async {
    _renameCtrl.text = widget.song.name;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Rename Song',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _renameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF2A2A3E),
            hintText: 'Song name...',
            hintStyle: const TextStyle(color: Colors.white30),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: _c[0], width: 2)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _c[0]),
            onPressed: () =>
                Navigator.pop(ctx, _renameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && widget.onRename != null) {
      widget.onRename!(name);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isPlaying
              ? _c[0].withOpacity(0.8)
              : Colors.white.withOpacity(0.06),
          width: widget.isPlaying ? 1.8 : 1,
        ),
        boxShadow: widget.isPlaying
            ? [
          BoxShadow(
              color: _c[0].withOpacity(0.25),
              blurRadius: 18,
              spreadRadius: 1)
        ]
            : [
          BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Main row ──────────────────────────────────────────────────
          _mainRow(),
          // ── Trim progress bar ─────────────────────────────────────────
          _trimBar(),
          // ── Expanded panel ────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _expandedPanel(),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  // ── Main row ──────────────────────────────────────────────────────────────────

  Widget _mainRow() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 12, 6, 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(Icons.drag_handle,
              color: Colors.white.withOpacity(0.2), size: 22),
        ),

        // Badge
        _badge(),
        const SizedBox(width: 12),

        // Song info
        Expanded(child: _songInfo()),
        const SizedBox(width: 4),

        // Buttons
        _buttons(),
      ],
    ),
  );

  // ── Badge ─────────────────────────────────────────────────────────────────────

  Widget _badge() => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      gradient: LinearGradient(
          colors: _c,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
            color: _c[0].withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3))
      ],
    ),
    child: widget.isPlaying ? _animBars() : _numLabel(),
  );

  Widget _numLabel() => Center(
    child: Text('${widget.index + 1}',
        style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17)),
  );

  Widget _animBars() => AnimatedBuilder(
    animation: _barCtrl,
    builder: (_, __) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final bases = [0.3, 0.75, 0.5, 0.85];
        final h = bases[i] +
            (_barCtrl.value + i * 0.25) % 1.0 * (1 - bases[i]);
        return Container(
          width: 3,
          height: 16 * h,
          margin: const EdgeInsets.symmetric(horizontal: 1.2),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2)),
        );
      }),
    ),
  );

  // ── Song info ─────────────────────────────────────────────────────────────────

  Widget _songInfo() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Name — long press to rename
      GestureDetector(
        onLongPress:
        widget.onRename != null ? _showRename : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.song.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (widget.isPlaying) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _c[0].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('PLAYING',
                    style: TextStyle(
                        color: _c[0],
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 5),
      // Pills — Wrap prevents overflow
      Wrap(
        spacing: 5,
        runSpacing: 4,
        children: [
          _pill(Icons.content_cut,
              '${_fmt(widget.song.startTrim)}→${_fmt(widget.song.endTrim)}',
              _c[0]),
          _pill(Icons.timer_outlined,
              _fmt(widget.song.trimmedDuration), Colors.white54),
          _pill(Icons.volume_up_rounded, _volLabel, _volColor),
        ],
      ),
    ],
  );

  // ── Action buttons ────────────────────────────────────────────────────────────

  Widget _buttons() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Play circle button
      GestureDetector(
        onTap: () {
          // HapticFeedback.lightImpact();
          widget.onPlay();
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _c[0].withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: _c[0].withOpacity(0.4)),
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause : Icons.play_arrow,
            color: _c[0],
            size: 20,
          ),
        ),
      ),
      // Expand toggle
      IconButton(
        icon: Icon(
          _expanded
              ? Icons.keyboard_arrow_up
              : Icons.keyboard_arrow_down,
          color: Colors.white38,
          size: 22,
        ),
        onPressed: () {
          // HapticFeedback.selectionClick();
          setState(() => _expanded = !_expanded);
        },
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
      ),
      // More menu
      PopupMenuButton<String>(
        color: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_vert,
            color: Colors.white38, size: 20),
        onSelected: (v) {
          switch (v) {
            case 'trim':
              widget.onTrim();
              break;
            case 'rename':
              _showRename();
              break;
            case 'duplicate':
              widget.onDuplicate?.call();
              break;
            case 'delete':
              widget.onRemove();
              break;
          }
        },
        itemBuilder: (_) => [
          _menuItem(
              'trim', Icons.content_cut, 'Edit Trim', _c[0]),
          if (widget.onRename != null)
            _menuItem('rename',
                Icons.drive_file_rename_outline, 'Rename',
                Colors.white70),
          if (widget.onDuplicate != null)
            _menuItem('duplicate', Icons.copy, 'Duplicate',
                Colors.white70),
          const PopupMenuDivider(),
          _menuItem('delete', Icons.delete_outline, 'Remove',
              Colors.redAccent),
        ],
      ),
    ],
  );

  PopupMenuItem<String> _menuItem(
      String val, IconData icon, String label, Color color) =>
      PopupMenuItem(
        value: val,
        height: 42,
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  // ── Trim progress bar ─────────────────────────────────────────────────────────

  Widget _trimBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Trim: ${(_trimPercent * 100).toInt()}% used',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 0.3)),
            Text(
                '${_fmt(widget.song.startTrim)} — ${_fmt(widget.song.endTrim)}',
                style: TextStyle(
                    color: _c[0].withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            Container(
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            LayoutBuilder(builder: (ctx, box) {
              final total =
                  widget.song.duration?.inMilliseconds;
              if (total == 0) return const SizedBox();
              final sr =
                  widget.song.startTrim.inMilliseconds / total!;
              final er =
                  widget.song.endTrim.inMilliseconds / total;
              final left =
              (sr * box.maxWidth).clamp(0.0, box.maxWidth);
              final w = ((er - sr) * box.maxWidth)
                  .clamp(0.0, box.maxWidth - left);
              return Positioned(
                left: left,
                child: Container(
                  height: 5,
                  width: w,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _c),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: _c[0].withOpacity(0.4),
                          blurRadius: 4)
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    ),
  );

  // ── Expanded panel ────────────────────────────────────────────────────────────

  Widget _expandedPanel() => Container(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(color: Colors.white.withOpacity(0.07), height: 1),
        const SizedBox(height: 12),

        // Volume header
        Row(children: [
          Icon(
            widget.song.volume == 0
                ? Icons.volume_off
                : widget.song.volume < 0.5
                ? Icons.volume_down
                : Icons.volume_up,
            color: _volColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text('Volume',
              style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _volColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${(widget.song.volume * 100).toInt()}%  •  $_volLabel',
              style: TextStyle(
                  color: _volColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ]),
        const SizedBox(height: 4),

        // Volume slider
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _volColor,
            inactiveTrackColor: Colors.white10,
            thumbColor: _volColor,
            overlayColor: _volColor.withOpacity(0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9),
          ),
          child: Slider(
            value: widget.song.volume.clamp(0.0, 1.5),
            min: 0,
            max: 1.5,
            divisions: 30,
            onChanged: widget.onVolumeChange,
          ),
        ),

        // Volume preset buttons
        Row(children: [
          _volPreset('Mute', 0.0),
          const SizedBox(width: 6),
          _volPreset('50%', 0.5),
          const SizedBox(width: 6),
          _volPreset('100%', 1.0),
          const SizedBox(width: 6),
          _volPreset('150%', 1.5),
        ]),

        const SizedBox(height: 14),
        Divider(color: Colors.white.withOpacity(0.07), height: 1),
        const SizedBox(height: 12),

        // Song info
        const Text('Song Info',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        // _infoRow(Icons.music_note, 'Full Duration',
        //     _fmt(widget.song.duration)),
        const SizedBox(height: 6),
        _infoRow(Icons.content_cut, 'Trimmed Duration',
            _fmt(widget.song.trimmedDuration)),
        const SizedBox(height: 6),
        _infoRow(Icons.skip_next, 'Start Point',
            _fmt(widget.song.startTrim)),
        const SizedBox(height: 6),
        _infoRow(Icons.skip_previous, 'End Point',
            _fmt(widget.song.endTrim)),

        const SizedBox(height: 14),

        // Quick action buttons
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onTrim,
              style: ElevatedButton.styleFrom(
                backgroundColor: _c[0],
                padding:
                const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon:
              const Icon(Icons.content_cut, size: 15),
              label: const Text('Edit Trim',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          if (widget.onDuplicate != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onDuplicate,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                      color: Colors.white24),
                  padding: const EdgeInsets.symmetric(
                      vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.copy,
                    color: Colors.white54, size: 15),
                label: const Text('Copy',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onRemove,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Colors.redAccent),
                padding:
                const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 15),
              label: const Text('Remove',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ],
    ),
  );

  // ── Small helpers ─────────────────────────────────────────────────────────────

  Widget _pill(IconData icon, String label, Color color) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border:
      Border.all(color: color.withOpacity(0.2), width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _volPreset(String label, double value) {
    final active = (widget.song.volume - value).abs() < 0.01;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          // HapticFeedback.selectionClick();
          widget.onVolumeChange(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? _c[0].withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? _c[0].withOpacity(0.6)
                  : Colors.transparent,
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: active ? _c[0] : Colors.white38,
                  fontSize: 11,
                  fontWeight: active
                      ? FontWeight.bold
                      : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 14, color: Colors.white30),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: Colors.white38, fontSize: 12)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              color: _c[0],
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
    ],
  );

  @override
  void dispose() {
    _barCtrl.dispose();
    _renameCtrl.dispose();
    super.dispose();
  }
}