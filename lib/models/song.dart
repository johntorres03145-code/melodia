/// Canción almacenada localmente en el dispositivo.
class LocalSong {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String path; // URI/path del archivo de audio
  final int durationMs;
  final int? albumId; // para pedir la carátula con on_audio_query

  const LocalSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.durationMs,
    this.albumId,
  });

  Duration get duration => Duration(milliseconds: durationMs);
  String get key => '$artist - $title';

  /// Convierte la canción a un mapa plano (para guardar en Hive).
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'path': path,
        'durationMs': durationMs,
        'albumId': albumId,
      };

  /// Reconstruye una canción desde su mapa.
  static LocalSong fromMap(Map<String, dynamic> map) => LocalSong(
        id: map['id'] as int,
        title: map['title'] as String,
        artist: (map['artist'] as String?) ?? '',
        album: (map['album'] as String?) ?? '',
        path: map['path'] as String,
        durationMs: (map['durationMs'] as int?) ?? 0,
        albumId: map['albumId'] as int?,
      );

  String get formattedDuration {
    final d = duration;
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  bool operator ==(Object other) => other is LocalSong && other.id == id;

  @override
  int get hashCode => id.hashCode;
}