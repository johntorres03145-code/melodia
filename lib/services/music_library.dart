import 'dart:typed_data';

import 'package:on_audio_query_pluse/on_audio_query.dart';

import '../models/song.dart';

/// Servicio para escanear la música local del dispositivo.
class MusicLibrary {
  final OnAudioQuery _query = OnAudioQuery();

  /// Pide permiso de acceso a los archivos de audio (Android).
  Future<bool> requestPermission() {
    return _query.permissionsRequest();
  }

  /// Escanea todas las canciones del dispositivo.
  Future<List<LocalSong>> fetchSongs() async {
    final raw = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
    );
    return raw.map((s) {
      return LocalSong(
        id: s.id,
        title: s.title,
        artist: s.artist ?? '',
        album: s.album ?? '',
        path: s.data,
        durationMs: s.duration ?? 0,
        albumId: s.albumId,
      );
    }).toList();
  }

  /// Devuelve la carátula del álbum como bytes a alta resolución (o null si no hay).
  Future<Uint8List?> fetchArtwork(int? albumId) async {
    if (albumId == null) return null;
    try {
      return await _query.queryArtwork(
        albumId,
        ArtworkType.ALBUM,
        format: ArtworkFormat.JPEG,
        size: 800,
        quality: 100,
      );
    } catch (_) {
      return null;
    }
  }

  /// Devuelve la carátula de una canción específica (por ID de la canción).
  Future<Uint8List?> fetchSongArtwork(int songId) async {
    try {
      return await _query.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 800,
        quality: 100,
      );
    } catch (_) {
      return null;
    }
  }
}