// lib/models/song_model.dart

class SongModel {
  final String id;
  String name;
  String filePath;
  Duration? duration;
  Duration startTrim;
  Duration endTrim;
  double volume;
  int order;
  String? color;

  SongModel({
    required this.id,
    required this.name,
    required this.filePath,
    this.duration,
    this.startTrim = Duration.zero,
    Duration? endTrim,
    this.volume = 1.0,
    this.order = 0,
    this.color,
  }) : endTrim = endTrim ?? const Duration(seconds: 30);

  Duration get trimmedDuration {
    if (endTrim > startTrim) return endTrim - startTrim;
    return Duration.zero;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'filePath': filePath,
    'duration': duration?.inMilliseconds,
    'startTrim': startTrim.inMilliseconds,
    'endTrim': endTrim.inMilliseconds,
    'volume': volume,
    'order': order,
    'color': color,
  };

  factory SongModel.fromJson(Map<String, dynamic> json) => SongModel(
    id: json['id'],
    name: json['name'],
    filePath: json['filePath'],
    duration: json['duration'] != null
        ? Duration(milliseconds: json['duration'])
        : null,
    startTrim: Duration(milliseconds: json['startTrim'] ?? 0),
    endTrim: Duration(
        milliseconds: json['endTrim'] ?? const Duration(seconds: 30).inMilliseconds),
    volume: (json['volume'] ?? 1.0).toDouble(),
    order: json['order'] ?? 0,
    color: json['color'],
  );

  SongModel copyWith({
    String? name,
    String? filePath,
    Duration? duration,
    Duration? startTrim,
    Duration? endTrim,
    double? volume,
    int? order,
    String? color,
  }) =>
      SongModel(
        id: id,
        name: name ?? this.name,
        filePath: filePath ?? this.filePath,
        duration: duration ?? this.duration,
        startTrim: startTrim ?? this.startTrim,
        endTrim: endTrim ?? this.endTrim,
        volume: volume ?? this.volume,
        order: order ?? this.order,
        color: color ?? this.color,
      );
}

class ParodyProject {
  final String id;
  String name;
  List<SongModel> songs;
  DateTime createdAt;
  DateTime updatedAt;
  String? outputPath;

  ParodyProject({
    required this.id,
    required this.name,
    List<SongModel>? songs,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.outputPath,
  })  : songs = songs ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Duration get totalDuration =>
      songs.fold(Duration.zero, (sum, s) => sum + s.trimmedDuration);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'songs': songs.map((s) => s.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'outputPath': outputPath,
  };

  factory ParodyProject.fromJson(Map<String, dynamic> json) => ParodyProject(
    id: json['id'],
    name: json['name'],
    songs: (json['songs'] as List? ?? [])
        .map((s) => SongModel.fromJson(s))
        .toList(),
    createdAt: DateTime.parse(json['createdAt']),
    updatedAt: DateTime.parse(json['updatedAt']),
    outputPath: json['outputPath'],
  );
}