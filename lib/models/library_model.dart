import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../services/music_library.dart';
import 'play_history_model.dart';
import 'song.dart';

enum SortMode { name, recent, mostPlayed, duration }

/// Datos de un artista para la lista de biblioteca.
class ArtistData {
  final String name;
  final int songCount;
  final int? sampleSongId;
  final int? sampleAlbumId;
  const ArtistData({required this.name, required this.songCount, this.sampleSongId, this.sampleAlbumId});
}

/// Datos de un álbum para la lista de biblioteca.
class AlbumData {
  final String name;
  final int songCount;
  final int? albumId;
  const AlbumData({required this.name, required this.songCount, this.albumId});
}

/// Estado de la biblioteca local: canciones escaneadas y búsqueda.
class LibraryModel extends ChangeNotifier {
  final MusicLibrary _service = MusicLibrary();

  List<LocalSong> _songs = [];
  final Map<int, Uint8List?> _artworkCache = {};
  final Map<int, Uint8List?> _songArtworkCache = {};
  final Set<int> _hiddenIds = {};
  String _query = '';
  SortMode _sortMode = SortMode.recent;
  PlayHistoryModel? _playHistory;
  bool _loading = false;
  String? _error;
  Box? _settingsBox;
  List<LocalSong>? _cachedSongs;
  String? _cachedQuery;
  SortMode? _cachedSort;
  List<ArtistData>? _cachedArtists;
  List<AlbumData>? _cachedAlbums;

  bool get loading => _loading;
  String? get error => _error;
  Set<int> get hiddenIds => Set.unmodifiable(_hiddenIds);

  void init(Box settingsBox) {
    _settingsBox = settingsBox;
    final saved = settingsBox.get('hiddenSongIds', defaultValue: <int>[]);
    _hiddenIds.addAll(List<int>.from(saved));
  }

  void hideSong(int id) {
    _hiddenIds.add(id);
    _saveHidden();
    _invalidateCache();
    _notify();
  }

  void unhideSong(int id) {
    _hiddenIds.remove(id);
    _saveHidden();
    _invalidateCache();
    _notify();
  }

  void _saveHidden() {
    _settingsBox?.put('hiddenSongIds', _hiddenIds.toList());
  }
  SortMode get sortMode => _sortMode;

  /// Artistas únicos con conteo de canciones y referencia para artwork.
  List<ArtistData> get artists {
    if (_cachedArtists != null) return _cachedArtists!;
    final map = <String, ArtistData>{};
    for (final s in songs) {
      final name = s.artist.isEmpty ? 'Artista desconocido' : s.artist;
      final existing = map[name];
      if (existing != null) {
        map[name] = ArtistData(name: name, songCount: existing.songCount + 1, sampleSongId: existing.sampleSongId, sampleAlbumId: existing.sampleAlbumId);
      } else {
        map[name] = ArtistData(name: name, songCount: 1, sampleSongId: s.id, sampleAlbumId: s.albumId);
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    _cachedArtists = list;
    return list;
  }

  /// Álbumes únicos con conteo de canciones y albumId para artwork.
  List<AlbumData> get albums {
    if (_cachedAlbums != null) return _cachedAlbums!;
    final map = <String, AlbumData>{};
    for (final s in songs) {
      final name = s.album.isEmpty ? 'Álbum desconocido' : s.album;
      final existing = map[name];
      if (existing != null) {
        map[name] = AlbumData(name: name, songCount: existing.songCount + 1, albumId: existing.albumId);
      } else {
        map[name] = AlbumData(name: name, songCount: 1, albumId: s.albumId);
      }
    }
    final list = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    _cachedAlbums = list;
    return list;
  }

  /// Canciones de un artista específico.
  List<LocalSong> songsByArtist(String artist) =>
      songs.where((s) => (s.artist.isEmpty ? 'Artista desconocido' : s.artist) == artist).toList();

  /// Canciones de un álbum específico.
  List<LocalSong> songsByAlbum(String album) =>
      songs.where((s) => (s.album.isEmpty ? 'Álbum desconocido' : s.album) == album).toList();

  /// Canciones filtradas por el buscador y ocultas.
  List<LocalSong> get songs {
    if (_cachedSongs != null && _cachedQuery == _query && _cachedSort == _sortMode) {
      return _cachedSongs!;
    }
    final q = _query.toLowerCase().trim();
    final list = q.isEmpty ? List<LocalSong>.from(_songs) : _songs.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();
    list.removeWhere((s) => _hiddenIds.contains(s.id));
    _applySorting(list);
    _cachedSongs = list;
    _cachedQuery = _query;
    _cachedSort = _sortMode;
    return list;
  }

  List<LocalSong> get allSongs => _songs.where((s) => !_hiddenIds.contains(s.id)).toList();

  List<LocalSong> get hiddenSongs => _songs.where((s) => _hiddenIds.contains(s.id)).toList();

  void attachPlayHistory(PlayHistoryModel history) {
    _playHistory = history;
  }

  void setSortMode(SortMode mode) {
    _sortMode = mode;
    _invalidateCache();
    _notify();
  }

  void _applySorting(List<LocalSong> list) {
    switch (_sortMode) {
      case SortMode.name:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortMode.recent:
        list.sort((a, b) => b.id.compareTo(a.id));
      case SortMode.mostPlayed:
        if (_playHistory != null) {
          list.sort((a, b) {
            final cA = _playHistory!.getPlayCount(a.id);
            final cB = _playHistory!.getPlayCount(b.id);
            if (cA != cB) return cB.compareTo(cA);
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          });
        }
      case SortMode.duration:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
    }
  }

  void _invalidateCache() {
    _cachedSongs = null;
    _cachedArtists = null;
    _cachedAlbums = null;
  }

  /// Carga la biblioteca desde el dispositivo.
  /// Reintenta hasta 2 veces si falla (problemas comunes en Xiaomi/MIUI).
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _notify();
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final ok = await _service.requestPermission().timeout(
              const Duration(seconds: 5),
              onTimeout: () => false,
            );
        if (!ok) {
          _error = 'Necesito permiso para leer tu música.';
          break;
        }
        _songs = await _service.fetchSongs();
        _invalidateCache();
        if (_songs.isNotEmpty) break;
        // Si no devolvió canciones, esperar un poco y reintentar (Xiaomi lento)
        if (attempt == 0) await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        _error = 'No pude cargar la música: $e';
      }
    }
    _loading = false;
    _notify();
  }

  void setQuery(String q) {
    _query = q;
    _invalidateCache();
    _notify();
  }

  /// Obtiene (y cachea) la carátula de un álbum.
  Future<Uint8List?> artworkFor(int? albumId) async {
    if (albumId == null) return null;
    if (_artworkCache.containsKey(albumId)) return _artworkCache[albumId];
    final bytes = await _service.fetchArtwork(albumId);
    _artworkCache[albumId] = bytes;
    return bytes;
  }

  /// Obtiene (y cachea) la carátula de una canción específica (por ID de audio).
  /// Si no hay carátula, intenta la del álbum como fallback.
  Future<Uint8List?> songArtworkFor(int songId, {int? albumId}) async {
    if (_songArtworkCache.containsKey(songId)) return _songArtworkCache[songId];
    final bytes = await _service.fetchSongArtwork(songId);
    if (bytes != null) {
      _songArtworkCache[songId] = bytes;
      return bytes;
    }
    // Fallback a carátula del álbum
    return artworkFor(albumId);
  }

  void _notify() => notifyListeners();
}