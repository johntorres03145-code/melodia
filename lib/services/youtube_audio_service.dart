import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Servicio que obtiene URLs de audio de YouTube.
/// Clientes optimizados contra SABR: androidVr primero, luego audioOnly.
class YouTubeAudioService {
  final YoutubeExplode _yt = YoutubeExplode();

  /// Clientes InnerTube ordenados por resistencia a SABR.
  /// androidVr (Oculus) es el más estable actualmente.
  static final _clients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.androidSdkless,
    YoutubeApiClient.mweb,
    YoutubeApiClient.safari,
    YoutubeApiClient.tv,
  ];

  /// Busca la mejor URL de audio con fallback multi-cliente.
  Future<String?> _findWorkingUrl(String videoId) async {
    for (final client in _clients) {
      try {
        final clientName = client.apiUrl.split('/').last;
        debugPrint('YouTubeAudioService: intentando $clientName');
        final manifest = await _yt.videos.streamsClient
            .getManifest(videoId, ytClients: [client])
            .timeout(const Duration(seconds: 15));

        // ── 1. Audio-only primero (más resistente a SABR) ──
        final audioStreams = manifest.audioOnly;
        if (audioStreams.isNotEmpty) {
          final m4a = audioStreams
              .where((s) => s.container == StreamContainer.mp4 || s.tag == 140)
              .toList();
          final candidates = m4a.isNotEmpty ? m4a : audioStreams.sortByBitrate();
          final url = candidates.last.url.toString();
          debugPrint('YouTubeAudioService: audioOnly tag=${candidates.last.tag} via $clientName');
          return url;
        }

        // ── 2. Fallback: muxed tag 18 (360p con audio+video) ──
        final muxedStreams = manifest.muxed;
        if (muxedStreams.isNotEmpty) {
          final tag18 = muxedStreams.where((s) => s.tag == 18).toList();
          if (tag18.isNotEmpty) {
            debugPrint('YouTubeAudioService: muxed tag18 via $clientName');
            return tag18.first.url.toString();
          }
          debugPrint('YouTubeAudioService: muxed fallback tag=${muxedStreams.first.tag} via $clientName');
          return muxedStreams.first.url.toString();
        }
      } catch (e) {
        debugPrint('YouTubeAudioService: cliente falló: $e');
      }
    }

    debugPrint('YouTubeAudioService: TODOS los clientes fallaron para $videoId');
    return null;
  }

  /// Obtiene la URL del audio de YouTube con reintentos rápidos.
  Future<String?> getAudioUrl(String videoId) async {
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        debugPrint('YouTubeAudioService: intento $attempt para $videoId');
        final url = await _findWorkingUrl(videoId);
        if (url == null) return null;
        debugPrint('YouTubeAudioService: URL OK');
        return url;
      } catch (e) {
        debugPrint('YouTubeAudioService: intento $attempt falló: $e');
        if (attempt < 2) {
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
