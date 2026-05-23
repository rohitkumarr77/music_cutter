// lib/services/audio_service.dart

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../models/song_model.dart';

String _quotedPath(String path) {
  if (path.contains("'")) {
    return "'${path.replaceAll("'", r"'\''")}'";
  }
  return "'$path'";
}


class AudioService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;



  // ── Playback ─────────────────────────────────────────────────────────────────

  Future<void> play(String filePath, {Duration? startAt}) async {
    await _player.stop();
    await _player.play(DeviceFileSource(filePath));
    if (startAt != null && startAt.inMilliseconds > 0) {
      await _player.seek(startAt);
    }
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.resume();
  Future<void> stop() async => _player.stop();
  Future<void> seek(Duration position) async => _player.seek(position);

  Future<Duration?> getDuration(String filePath) async {
    final temp = AudioPlayer();
    try {
      await temp.setSourceDeviceFile(filePath);
      return temp.getDuration();
    } catch (_) {
      return Duration.zero;
    } finally {
      await temp.dispose();
    }
  }

  // ── FFmpeg: trim → MP3 ──────────────────────────────────────────────────────

  /// Trims [start]..[end] from [inputPath] and encodes to MP3 at [outputPath].
  Future<String?> trimAudio({
    required String inputPath,
    required Duration start,
    required Duration end,
    required String outputPath,
    double volume = 1.0,
  }) async {
    final durMs = (end - start).inMilliseconds;
    if (durMs <= 0) return null;

    final startSec = (start.inMilliseconds / 1000.0).toStringAsFixed(3);
    final durationSec = (durMs / 1000.0).toStringAsFixed(3);

    final vol = volume.clamp(0.0, 4.0);
    final filter = vol != 1.0 ? ' -filter:a volume=${vol.toStringAsFixed(3)}' : '';

    final cmd =
        '-y -i ${_quotedPath(inputPath)} -ss $startSec -t $durationSec$filter '
        '-vn -acodec libmp3lame -q:a 2 ${_quotedPath(outputPath)}';

    final session = await FFmpegKit.execute(cmd);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) return null;
    final out = File(outputPath);
    return await out.exists() ? outputPath : null;
  }

  /// One-off export for the single-file Music Cutter flow ([lib/main.dart]).
  Future<String?> exportTrimmedMp3({
    required String inputPath,
    required Duration start,
    required Duration end,
    required String outputPath,
  }) =>
      trimAudio(
        inputPath: inputPath,
        start: start,
        end: end,
        outputPath: outputPath,
        volume: 1.0,
      );

  // ── Merge project segments ───────────────────────────────────────────────────

  Future<String?> mergeAudioFiles({
    required List<SongModel> songs,
    required String outputPath,
  }) async {
    if (songs.isEmpty) return null;

    final tempDir = await getTemporaryDirectory();
    final tempFiles = <String>[];
    final listName = 'concat_${DateTime.now().microsecondsSinceEpoch}.txt';

    try {
      for (var i = 0; i < songs.length; i++) {
        final song = songs[i];
        final tempOut = '${tempDir.path}/merge_seg_$i.mp3';
        final result = await trimAudio(
          inputPath: song.filePath,
          start: song.startTrim,
          end: song.endTrim,
          outputPath: tempOut,
          volume: song.volume,
        );
        if (result == null) {
          for (final f in tempFiles) {
            try {
              await File(f).delete();
            } catch (_) {}
          }
          return null;
        }
        tempFiles.add(result);
      }

      if (tempFiles.length == 1) {
        await File(tempFiles.first).copy(outputPath);
        await File(tempFiles.first).delete();
        return await File(outputPath).exists() ? outputPath : null;
      }

      final listFile = File('${tempDir.path}/$listName');
      final buf = StringBuffer();
      for (final f in tempFiles) {
        buf.writeln('file ${_quotedPath(f)}');
      }
      await listFile.writeAsString(buf.toString());

      final cmd = '-y -f concat -safe 0 -i ${_quotedPath(listFile.path)} '
          '-vn -acodec libmp3lame -q:a 2 ${_quotedPath(outputPath)}';

      final session = await FFmpegKit.execute(cmd);
      final code = await session.getReturnCode();

      for (final f in tempFiles) {
        try {
          await File(f).delete();
        } catch (_) {}
      }
      try {
        await listFile.delete();
      } catch (_) {}

      if (!ReturnCode.isSuccess(code)) return null;
      return await File(outputPath).exists() ? outputPath : null;
    } catch (e) {
      // ignore: avoid_print
      print('Merge error: $e');
      for (final f in tempFiles) {
        try {
          await File(f).delete();
        } catch (_) {}
      }
      return null;
    }
  }

  // ── Audio info (simple: player) ────────────────────────────────────────────

  Future<Map<String, dynamic>> getAudioInfo(String filePath) async {
    final duration = await getDuration(filePath) ?? Duration.zero;
    return {'duration': duration};
  }

  void dispose() {
    _player.dispose();
  }
}
