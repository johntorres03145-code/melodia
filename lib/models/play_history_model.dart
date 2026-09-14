import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'song.dart';

class PlayEntry {
  final int songId;
  final int playCount;
  final DateTime lastPlayed;

  PlayEntry({
    required this.songId,
    this.playCount = 1,
    DateTime? lastPlayed,
  }) : lastPlayed = lastPlayed ?? DateTime.now();

  PlayEntry copyWith({int? playCount, DateTime? lastPlayed}) {
    return PlayEntry(
      songId: songId,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
    );
  }

  Map<String, dynamic> toMap() => {
        'songId': songId,
        'playCount': playCount,
        'lastPlayed': lastPlayed.toIso8601String(),
      };

  static PlayEntry fromMap(Map<String, dynamic> map) => PlayEntry(
        songId: map['songId'] as int,
        playCount: map['playCount'] as int? ?? 1,
        lastPlayed: DateTime.parse(map['lastPlayed'] as String),
      );
}

class PlayHistoryModel extends ChangeNotifier {
  late Box _box;
  final Map<int, PlayEntry> _entries = {};

  List<PlayEntry> get all => _entries.values.toList();

  int getPlayCount(int songId) => _entries[songId]?.playCount ?? 0;

  Future<void> init(Box box) async {
    _box = box;
    final raw = _box.get('playHistory', defaultValue: <dynamic>[]) as List;
    for (final item in raw) {
      if (item is Map) {
        final e = PlayEntry.fromMap(Map<String, dynamic>.from(item));
        _entries[e.songId] = e;
      }
    }
    notifyListeners();
  }

  void recordPlay(int songId) {
    final existing = _entries[songId];
    _entries[songId] = existing != null
        ? existing.copyWith(
            playCount: existing.playCount + 1,
            lastPlayed: DateTime.now(),
          )
        : PlayEntry(songId: songId);
    _persist();
    notifyListeners();
  }

  List<LocalSong> getTopPlayed(List<LocalSong> allSongs, {int limit = 10}) {
    final sorted = allSongs.toList()
      ..sort((a, b) {
        final cA = _entries[a.id]?.playCount ?? 0;
        final cB = _entries[b.id]?.playCount ?? 0;
        if (cA != cB) return cB.compareTo(cA);
        return (_entries[b.id]?.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(_entries[a.id]?.lastPlayed ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
    return sorted.take(limit).toList();
  }

  /// Canciones reproducidas recientemente, ordenadas por última reproducción.
  List<LocalSong> getRecentlyPlayed(List<LocalSong> allSongs, {int limit = 10}) {
    final entries = _entries.values.toList()
      ..sort((a, b) => b.lastPlayed.compareTo(a.lastPlayed));
    final ids = entries.take(limit).map((e) => e.songId).toSet();
    return allSongs.where((s) => ids.contains(s.id)).toList();
  }

  /// Top artistas agrupados por total de reproducciones.
  List<ArtistStats> getTopArtistas(List<LocalSong> allSongs, {int limit = 10}) {
    final Map<String, int> artistPlays = {};
    final Map<String, int> artistSongs = {};
    final Map<String, DateTime> artistLastPlayed = {};

    for (final entry in _entries.values) {
      final song = allSongs.where((s) => s.id == entry.songId).firstOrNull;
      if (song == null) continue;
      final artist = song.artist.isEmpty ? 'Desconocido' : song.artist;
      artistPlays[artist] = (artistPlays[artist] ?? 0) + entry.playCount;
      artistSongs[artist] = (artistSongs[artist] ?? 0) + 1;
      if (artistLastPlayed[artist] == null ||
          entry.lastPlayed.isAfter(artistLastPlayed[artist]!)) {
        artistLastPlayed[artist] = entry.lastPlayed;
      }
    }

    final stats = artistPlays.entries.map((e) => ArtistStats(
      name: e.key,
      totalPlays: e.value,
      songCount: artistSongs[e.key] ?? 0,
      lastPlayed: artistLastPlayed[e.key] ?? DateTime.now(),
    )).toList()
      ..sort((a, b) => b.totalPlays.compareTo(a.totalPlays));

    return stats.take(limit).toList();
  }

  Future<void> _persist() async {
    await _box.put(
      'playHistory',
      _entries.values.map((e) => e.toMap()).toList(),
    );
  }
}

/// Estadísticas de un artista.
class ArtistStats {
  final String name;
  final int totalPlays;
  final int songCount;
  final DateTime lastPlayed;

  const ArtistStats({
    required this.name,
    required this.totalPlays,
    required this.songCount,
    required this.lastPlayed,
  });
}