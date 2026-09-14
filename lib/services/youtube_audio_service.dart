import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Servicio que obtiene URLs de audio de YouTube.
/// Intenta muxed (tag 18) primero por confiabilidad; fallback a audio-only.
class YouTubeAudioService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Busca la mejor URL de audio disponible.
  Future<String?> _findWorkingUrl(String videoId) async {
    final manifest = await _yt.videos.streamsClient.getManifest(videoId);

    // ── 1. Intentar muxed (tag 18, 360p) — más confiable ──
    final muxedStreams = manifest.muxed;
    if (muxedStreams.isNotEmpty) {
      final tag18 = muxedStreams.where((s) => s.tag == 18).toList();
      if (tag18.isNotEmpty) {
        final url = tag18.first.url.toString();
        debugPrint('YouTubeAudioService: muxed tag 18 OK');
        return url;
      }
      // Si no hay tag 18, usar el primero disponible
      final url = muxedStreams.first.url.toString();
      debugPrint('YouTubeAudioService: muxed fallback tag=${muxedStreams.first.tag}');
      return url;
    }

    // ── 2. Fallback: audio-only (M4A/AAC tag 140) ──
    final audioStreams = manifest.audioOnly;
    if (audioStreams.isNotEmpty) {
      final m4a = audioStreams
          .where((s) => s.container == StreamContainer.mp4 || s.tag == 140)
          .toList();
      final candidates = m4a.isNotEmpty ? m4a : audioStreams.sortByBitrate();

      final url = candidates.last.url.toString();
      debugPrint('YouTubeAudioService: audio-only tag=${candidates.last.tag}');
      return url;
    }

    debugPrint('YouTubeAudioService: no se encontró stream para $videoId');
    return null;
  }

  /// Obtiene la URL del audio de YouTube con reintentos rápidos.
  Future<String?> getAudioUrl(String videoId) async {
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint('YouTubeAudioService: intento $attempt para $videoId');
        final url = await _findWorkingUrl(videoId);
        if (url == null) return null;
        debugPrint('YouTubeAudioService: URL OK');
        return url;
      } catch (e) {
        debugPrint('YouTubeAudioService: intento $attempt falló: $e');
        if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return null;
  }

  void dispose() {
    _yt.close();
  }
}
