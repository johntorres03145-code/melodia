import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Una línea de letra sincronizada.
class LyricLine {
  final Duration timestamp;
  final String text;
  const LyricLine({required this.timestamp, required this.text});
}

/// Servicio que obtiene letras sincronizadas de LRCLIB (gratis, sin API key).
class LyricsService {
  /// Busca la letra de una canción por artista y título.
  /// Devuelve null si no hay letra disponible.
  Future<List<LyricLine>?> fetchLyrics(String artist, String title) async {
    if (artist.isEmpty || title.isEmpty) return null;
    try {
      final uri = Uri.parse('https://lrclib.net/api/get').replace(
        queryParameters: {
          'artist_name': artist,
          'track_name': title,
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final syncedLyrics = data['syncedLyrics'] as String?;
      if (syncedLyrics == null || syncedLyrics.isEmpty) return null;
      return _parseLRC(syncedLyrics);
    } catch (e) {
      debugPrint('LyricsService error: $e');
      return null;
    }
  }

  /// Parsea una letra LRC sincronizada a lista de [LyricLine].
  /// Formato: [mm:ss.xx] texto
  List<LyricLine> _parseLRC(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]\s*(.*)');
    for (final raw in lrc.split('\n')) {
      final match = regex.firstMatch(raw);
      if (match == null) continue;
      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final ms = int.parse(match.group(3)!.padRight(3, '0'));
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;
      lines.add(LyricLine(
        timestamp: Duration(minutes: min, seconds: sec, milliseconds: ms),
        text: text,
      ));
    }
    return lines;
  }
}
