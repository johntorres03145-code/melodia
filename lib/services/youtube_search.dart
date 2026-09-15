import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resultado de búsqueda de YouTube (Data API v3).
class YouTubeVideo {
  final String videoId;
  final String title;
  final String channel;
  final String thumb;
  final int? duration;
  const YouTubeVideo({
    required this.videoId,
    required this.title,
    required this.channel,
    required this.thumb,
    this.duration,
  });

  String get embedUrl => 'https://www.youtube.com/embed/$videoId?autoplay=1';
  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';
}

/// Playlist/Mix de YouTube.
class YouTubePlaylist {
  final String playlistId;
  final String title;
  final String channel;
  final String thumb;
  final int videoCount;
  const YouTubePlaylist({
    required this.playlistId,
    required this.title,
    required this.channel,
    required this.thumb,
    required this.videoCount,
  });
}

/// Búsqueda en YouTube usando la Data API v3 (oficial).
class YouTubeSearch {
  final String apiKey;

  YouTubeSearch(this.apiKey);

  static const _endpoint = 'https://www.googleapis.com/youtube/v3/search';
  static const _playlistItemsEndpoint =
      'https://www.googleapis.com/youtube/v3/playlistItems';

  /// Busca videos.
  Future<List<YouTubeVideo>> search(String query, {int max = 20}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'part': 'snippet',
      'type': 'video',
      'videoEmbeddable': 'true',
      'maxResults': '$max',
      'q': query,
      'key': apiKey,
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('YouTube API ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    return items.map((e) {
      final item = e as Map<String, dynamic>;
      final snippet = (item['snippet'] as Map<String, dynamic>?) ?? {};
      final id = (item['id'] as Map<String, dynamic>?) ?? {};
      return YouTubeVideo(
        videoId: (id['videoId'] as String?) ?? '',
        title: (snippet['title'] as String?) ?? '',
        channel: (snippet['channelTitle'] as String?) ?? '',
        thumb: (((snippet['thumbnails'] as Map<String, dynamic>?)?['medium']
                    as Map<String, dynamic>?)?['url']
                as String?) ??
            '',
      );
    }).where((v) => v.videoId.isNotEmpty).toList();
  }

  /// Busca playlists/mixes.
  Future<List<YouTubePlaylist>> searchPlaylists(String query,
      {int max = 8}) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'part': 'snippet',
      'type': 'playlist',
      'maxResults': '$max',
      'q': query,
      'key': apiKey,
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    return items.map((e) {
      final item = e as Map<String, dynamic>;
      final snippet = (item['snippet'] as Map<String, dynamic>?) ?? {};
      final id = (item['id'] as Map<String, dynamic>?) ?? {};
      return YouTubePlaylist(
        playlistId: (id['playlistId'] as String?) ?? '',
        title: (snippet['title'] as String?) ?? '',
        channel: (snippet['channelTitle'] as String?) ?? '',
        thumb: (((snippet['thumbnails'] as Map<String, dynamic>?)?['medium']
                    as Map<String, dynamic>?)?['url']
                as String?) ??
            '',
        videoCount: 0,
      );
    }).where((p) => p.playlistId.isNotEmpty).toList();
  }

  /// Obtiene los videos de una playlist (máx 50).
  Future<List<YouTubeVideo>> fetchPlaylistVideos(String playlistId,
      {int max = 50}) async {
    final uri = Uri.parse(_playlistItemsEndpoint).replace(queryParameters: {
      'part': 'snippet',
      'playlistId': playlistId,
      'maxResults': '$max',
      'key': apiKey,
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    return items.map((e) {
      final item = e as Map<String, dynamic>;
      final snippet = (item['snippet'] as Map<String, dynamic>?) ?? {};
      final resourceId =
          (snippet['resourceId'] as Map<String, dynamic>?) ?? {};
      return YouTubeVideo(
        videoId: (resourceId['videoId'] as String?) ?? '',
        title: (snippet['title'] as String?) ?? '',
        channel: (snippet['channelTitle'] as String?) ?? '',
        thumb: (((snippet['thumbnails'] as Map<String, dynamic>?)?['medium']
                    as Map<String, dynamic>?)?['url']
                as String?) ??
            '',
      );
    }).where((v) => v.videoId.isNotEmpty).toList();
  }
}
