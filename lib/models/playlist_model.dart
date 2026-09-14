import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'song.dart';

/// Una playlist personalizada con nombre, portada y lista de canciones.
class Playlist {
  final String id;
  final String name;
  final Uint8List? coverImage;
  final List<String> songIds;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    this.coverImage,
    List<String>? songIds,
    DateTime? createdAt,
  })  : songIds = songIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get count => songIds.length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'coverImage': coverImage != null
            ? base64Encode(coverImage!)
            : null,
        'songIds': songIds,
        'createdAt': createdAt.toIso8601String(),
      };

  static Playlist fromMap(Map<String, dynamic> map) => Playlist(
        id: map['id'] as String,
        name: map['name'] as String,
        coverImage: map['coverImage'] != null
            ? Uint8List.fromList(base64Decode(map['coverImage'] as String))
            : null,
        songIds: List<String>.from(map['songIds'] ?? []),
        createdAt: DateTime.parse(map['createdAt'] as String),
      );
}

/// Modelo de playlists persistentes en Hive.
class PlaylistModel extends ChangeNotifier {
  late Box _box;
  final Map<String, Playlist> _playlists = {};

  List<Playlist> get all => _playlists.values.toList();

  Future<void> init(Box box) async {
    _box = box;
    final raw = _box.get('playlists', defaultValue: <dynamic>[]) as List;
    for (final item in raw) {
      if (item is Map) {
        final p = Playlist.fromMap(Map<String, dynamic>.from(item));
        _playlists[p.id] = p;
      }
    }
    notifyListeners();
  }

  Future<void> create({
    required String name,
    Uint8List? coverImage,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _playlists[id] = Playlist(
      id: id,
      name: name,
      coverImage: coverImage,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    _playlists.remove(id);
    await _persist();
    notifyListeners();
  }

  Future<void> rename(String id, String newName) async {
    final p = _playlists[id];
    if (p != null) {
      _playlists[id] = Playlist(
        id: p.id,
        name: newName,
        coverImage: p.coverImage,
        songIds: p.songIds,
        createdAt: p.createdAt,
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> addSong(String playlistId, LocalSong song) async {
    final p = _playlists[playlistId];
    if (p != null && !p.songIds.contains(song.id.toString())) {
      final newCover = p.coverImage;
      _playlists[playlistId] = Playlist(
        id: p.id,
        name: p.name,
        coverImage: newCover,
        songIds: [...p.songIds, song.id.toString()],
        createdAt: p.createdAt,
      );
      await _persist();
      notifyListeners();
    }
  }

  /// Agrega múltiples canciones a una playlist de una vez.
  Future<void> addSongs(String playlistId, List<LocalSong> songs) async {
    final p = _playlists[playlistId];
    if (p == null) return;
    final existing = Set<String>.from(p.songIds);
    final newIds = songs
        .map((s) => s.id.toString())
        .where((id) => !existing.contains(id))
        .toList();
    if (newIds.isEmpty) return;
    _playlists[playlistId] = Playlist(
      id: p.id,
      name: p.name,
      coverImage: p.coverImage,
      songIds: [...p.songIds, ...newIds],
      createdAt: p.createdAt,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> removeSong(String playlistId, int songId) async {
    final p = _playlists[playlistId];
    if (p != null) {
      _playlists[playlistId] = Playlist(
        id: p.id,
        name: p.name,
        coverImage: p.coverImage,
        songIds: p.songIds.where((sid) => sid != songId.toString()).toList(),
        createdAt: p.createdAt,
      );
      await _persist();
      notifyListeners();
    }
  }

  Playlist? getById(String id) => _playlists[id];

  Future<void> setCover(String playlistId, Uint8List cover) async {
    final p = _playlists[playlistId];
    if (p != null) {
      _playlists[playlistId] = Playlist(
        id: p.id,
        name: p.name,
        coverImage: cover,
        songIds: p.songIds,
        createdAt: p.createdAt,
      );
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    await _box.put(
      'playlists',
      _playlists.values.map((p) => p.toMap()).toList(),
    );
  }
}