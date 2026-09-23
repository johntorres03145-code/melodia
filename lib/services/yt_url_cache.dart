import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Cache persistente de URLs de audio de YouTube.
/// Guarda URLs con timestamp para saber si expiraron (~6 horas).
class YtUrlCache {
  static const String _boxName = 'yt_audio_urls';
  static const Duration _ttl = Duration(hours: 1);

  late Box<Map> _box;

  Future<void> init() async {
    _box = await Hive.openBox<Map>(_boxName);
  }

  String? get(String videoId) {
    final data = _box.get(videoId);
    if (data == null) return null;
    final ts = data['ts'] as int?;
    if (ts == null) return null;
    final age = DateTime.now().millisecondsSinceEpoch - ts;
    if (age > _ttl.inMilliseconds) {
      _box.delete(videoId);
      return null;
    }
    return data['url'] as String?;
  }

  void put(String videoId, String url) {
    _box.put(videoId, {
      'url': url,
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    debugPrint('YtUrlCache: saved $videoId');
  }

  Future<void> close() async {
    await _box.close();
  }
}
