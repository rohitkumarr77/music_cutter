// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/song_model.dart';
import '../services/storage_service.dart';
import '../services/permission_service.dart';
import 'editor_screen.dart';
import 'output_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _SortMode { recent, oldest, name, songs, duration }

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storage = StorageService();
  final PermissionService _permission = PermissionService();

  late TabController _tabs;

  List<ParodyProject> _projects = [];
  List<ParodyProject> _filtered = [];

  bool _loading = true;

  // Search & Sort
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.recent;
  bool _searchVisible = false;

  // Selection
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _permission.requestAllPermissions().then((_) => _load());

    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.toLowerCase();
        _applyFilter();
      });
    });
  }

  // ── LOAD ─────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _storage.loadProjects();
    _projects = list;
    _applyFilter();
    setState(() => _loading = false);
  }

  void _applyFilter() {
    var list = [..._projects];

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((p) => p.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    switch (_sortMode) {
      case _SortMode.recent:
        break;
      case _SortMode.oldest:
        break;
      case _SortMode.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortMode.songs:
        list.sort((a, b) => b.songs.length.compareTo(a.songs.length));
        break;
      case _SortMode.duration:
        list.sort((a, b) =>
            b.totalDuration.inSeconds.compareTo(a.totalDuration.inSeconds));
        break;
    }

    _filtered = list;
  }

  // ── CREATE ───────────────────────────────────────

  Future<void> _createProject() async {
    final name = await _showNameDialog();
    if (name == null || name.isEmpty) return;

    final project = ParodyProject(
      id: const Uuid().v4(),
      name: name,
    );

    await _storage.saveProject(project);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(project: project),
      ),
    );

    _load();
  }

  // ── DELETE ───────────────────────────────────────

  Future<void> _deleteProject(ParodyProject p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C30),
        title: const Text('Delete Project?',
            style: TextStyle(color: Colors.white)),
        content: Text(p.name,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white38))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'))
        ],
      ),
    );

    if (ok != true) return;

    await _storage.deleteProject(p.id);
    await _storage.deleteProjectFiles(p.id);
    _load();
  }

  // ── MULTI DELETE ────────────────────────────────

  Future<void> _deleteSelected() async {
    for (final id in _selected) {
      await _storage.deleteProject(id);
      await _storage.deleteProjectFiles(id);
    }

    setState(() {
      _selected.clear();
      _selectMode = false;
    });

    _load();
  }

  // ── UI ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: _appBar(),
      body: TabBarView(
        controller: _tabs,
        children: [
          _projectsTab(),
          OutputScreen(storageService: _storage),
        ],
      ),
      floatingActionButton:
      _tabs.index == 0 ? _fab() : null,
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: const Color(0xFF15152A),
      title: _searchVisible
          ? _searchBar()
          : const Text('Music Cutter',
          style: TextStyle(color: Colors.white)),
      actions: [
        if (_projects.isNotEmpty)
          IconButton(
            icon: Icon(
              _selectMode ? Icons.close : Icons.checklist,
              color: Colors.white54,
            ),
            onPressed: () {
              setState(() {
                _selectMode = !_selectMode;
                _selected.clear();
              });
            },
          ),
        if (!_selectMode)
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white54),
            onPressed: () {
              setState(() {
                _searchVisible = !_searchVisible;
                if (!_searchVisible) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                  _applyFilter();
                }
              });
            },
          ),
        if (!_selectMode)
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort, color: Colors.white54),
            onSelected: (mode) {
              setState(() {
                _sortMode = mode;
                _applyFilter();
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _SortMode.name, child: Text('Name')),
              PopupMenuItem(value: _SortMode.songs, child: Text('Songs')),
              PopupMenuItem(value: _SortMode.duration, child: Text('Duration')),
            ],
          ),
        if (_selectMode && _selected.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: _deleteSelected,
          ),
      ],
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(icon: Icon(Icons.folder), text: 'Projects'),
          Tab(icon: Icon(Icons.audio_file), text: 'Outputs'),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchCtrl,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: 'Search...',
        hintStyle: TextStyle(color: Colors.white38),
        border: InputBorder.none,
      ),
    );
  }

  Widget _projectsTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_projects.isEmpty) return _empty();

    return Column(
      children: [
        _stats(),
        if (_selectMode) _selectionBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _filtered.length,
            itemBuilder: (_, i) => _card(_filtered[i]),
          ),
        ),
      ],
    );
  }

  Widget _stats() {
    final totalSongs =
    _projects.fold<int>(0, (s, p) => s + p.songs.length);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        '${_projects.length} Projects • $totalSongs Songs',
        style: const TextStyle(color: Colors.white54),
      ),
    );
  }

  Widget _selectionBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        '${_selected.length} selected',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _card(ParodyProject p) {
    final isSelected = _selected.contains(p.id);

    return Card(
      color: const Color(0xFF1C1C30),
      child: ListTile(
        onTap: () async {
          if (_selectMode) {
            setState(() {
              isSelected
                  ? _selected.remove(p.id)
                  : _selected.add(p.id);
            });
            return;
          }

          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EditorScreen(project: p)),
          );

          _load();
        },
        onLongPress: () {
          setState(() {
            _selectMode = true;
            _selected.add(p.id);
          });
        },
        title: Text(p.name,
            style: const TextStyle(color: Colors.white)),
        subtitle: Text('${p.songs.length} songs',
            style: const TextStyle(color: Colors.white54)),
        trailing: !_selectMode
            ? IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => _deleteProject(p),
        )
            : Checkbox(
          value: isSelected,
          onChanged: (_) {
            setState(() {
              isSelected
                  ? _selected.remove(p.id)
                  : _selected.add(p.id);
            });
          },
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note,
              size: 60, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('No projects',
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _createProject,
            child: const Text('Create Project'),
          )
        ],
      ),
    );
  }

  Widget _fab() {
    return FloatingActionButton(
      onPressed: _createProject,
      child: const Icon(Icons.add),
    );
  }

  Future<String?> _showNameDialog() {
    final ctrl = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title:
        const Text('Project Name', style: TextStyle(color: Colors.white)),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Create'))
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}