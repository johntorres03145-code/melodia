import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'song.dart';

/// Favoritos persistentes en Hive.
class FavoritesModel extends ChangeNotifier {
  late Box _box;
  final Map<int, LocalSong> _favorites = {};

  List<LocalSong> get songs => _favorites.values.toList();

  Future<void> init(Box box) async {
    _box = box;
    final raw = _box.get('favorites', defaultValue: <dynamic>[]) as List;
    for (final item in raw) {
      if (item is Map) {
        final song = LocalSong.fromMap(Map<String, dynamic>.from(item));
        _favorites[song.id] = song;
      }
    }
    notifyListeners();
  }

  bool isFavorite(int id) => _favorites.containsKey(id);

  Future<void> toggle(LocalSong song) async {
    if (_favorites.containsKey(song.id)) {
      _favorites.remove(song.id);
    } else {
      _favorites[song.id] = song;
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _box.put(
      'favorites',
      _favorites.values.map((s) => s.toMap()).toList(),
    );
  }
}
