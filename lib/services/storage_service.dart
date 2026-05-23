
// lib/services/storage_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';

class StorageService {
  static const String _projectsKey = 'parody_projects_v2';

  // Singleton SharedPreferences instance for speed
  SharedPreferences? _prefs;
  Future<SharedPreferences> get _sharedPrefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── App Directories ───────────────────────────────────────────────────────────

  Future<Directory> getAppDir() async =>
      await getApplicationDocumentsDirectory();

  Future<Directory> getProjectsDir() async {
    final dir = Directory('${(await getAppDir()).path}/projects');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> getOutputDir() async {
    final dir = Directory('${(await getAppDir()).path}/output');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Project CRUD ──────────────────────────────────────────────────────────────

  /// Load all projects from SharedPreferences
  Future<List<ParodyProject>> loadProjects() async {
    try {
      final prefs = await _sharedPrefs;
      final jsonStr = prefs.getString(_projectsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> list = jsonDecode(jsonStr);
      final projects = list
          .map((e) => ParodyProject.fromJson(e as Map<String, dynamic>))
          .toList();
      // Sort newest first
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (e) {
      // If JSON is corrupted, return empty list instead of crashing
      print('loadProjects error: $e');
      return [];
    }
  }

  /// Load a single project by ID (always fresh from storage)
  Future<ParodyProject?> loadProject(String projectId) async {
    final projects = await loadProjects();
    try {
      return projects.firstWhere((p) => p.id == projectId);
    } catch (_) {
      return null;
    }
  }

  /// Save all projects atomically
  Future<bool> saveProjects(List<ParodyProject> projects) async {
    try {
      final prefs = await _sharedPrefs;
      final json = jsonEncode(projects.map((p) => p.toJson()).toList());
      return await prefs.setString(_projectsKey, json);
    } catch (e) {
      print('saveProjects error: $e');
      return false;
    }
  }

  /// Save or update a single project — always reloads list first to avoid overwrite
  Future<bool> saveProject(ParodyProject project) async {
    try {
      final projects = await loadProjects();
      final idx = projects.indexWhere((p) => p.id == project.id);
      project.updatedAt = DateTime.now();
      if (idx >= 0) {
        projects[idx] = project;
      } else {
        projects.add(project);
      }
      return await saveProjects(projects);
    } catch (e) {
      print('saveProject error: $e');
      return false;
    }
  }

  Future<void> deleteProject(String projectId) async {
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == projectId);
    await saveProjects(projects);
  }

  // ── File Helpers ──────────────────────────────────────────────────────────────

  /// Copy audio file to internal app storage.
  /// Uses a unique filename to prevent collisions.
  Future<String> copyAudioToApp(String sourcePath, String projectId) async {
    final projectsDir = await getProjectsDir();
    final projectDir = Directory('${projectsDir.path}/$projectId');
    if (!await projectDir.exists()) await projectDir.create(recursive: true);

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return sourcePath;

    // ✅ Add timestamp to avoid duplicate filename collisions
    final originalName = sourcePath.split('/').last;
    final ext = originalName.contains('.')
        ? originalName.split('.').last
        : 'mp3';
    final baseName = originalName.contains('.')
        ? originalName.substring(0, originalName.lastIndexOf('.'))
        : originalName;
    final uniqueName = '${baseName}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final destPath = '${projectDir.path}/$uniqueName';

    await sourceFile.copy(destPath);
    return destPath;
  }

  /// Verify all song file paths in a project still exist on disk.
  /// Returns project with only valid songs.
  Future<ParodyProject> validateProjectFiles(ParodyProject project) async {
    final validSongs = <SongModel>[];
    for (final song in project.songs) {
      if (await File(song.filePath).exists()) {
        validSongs.add(song);
      } else {
        print('Missing file for song ${song.name}: ${song.filePath}');
      }
    }
    if (validSongs.length != project.songs.length) {
      project.songs
        ..clear()
        ..addAll(validSongs);
      await saveProject(project);
    }
    return project;
  }

  Future<void> deleteProjectFiles(String projectId) async {
    final projectsDir = await getProjectsDir();
    final projectDir = Directory('${projectsDir.path}/$projectId');
    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }
  }


  Future<List<File>> listOutputFiles() async {
    final dir = await getOutputDir();

    final files = dir
        .listSync()
        .whereType<File>() // ✅ converts ONLY File
        .where((f) => f.path.endsWith('.mp3')) // optional filter
        .toList();

    return files;
  }

  Future<int> getStorageUsed() async {
    final appDir = await getAppDir();
    int total = 0;
    try {
      await for (final entity in appDir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          total += stat.size;
        }
      }
    } catch (_) {}
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }

  loadAll() async {}
}