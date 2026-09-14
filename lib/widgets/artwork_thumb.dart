import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/library_model.dart';
import '../models/song.dart';

/// Portada de una canción con caché. Muestra un icono si no hay carátula.
class ArtworkThumb extends StatelessWidget {
  final LocalSong song;
  final double size;

  const ArtworkThumb({super.key, required this.song, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<dynamic>(
        future: context.read<LibraryModel>().songArtworkFor(song.id, albumId: song.albumId),
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
          return Image.memory(
            snap.data,
            width: size,
            height: size,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          );
          }
          return Container(
            width: size,
            height: size,
            color: Colors.white10,
            child: const Icon(Icons.music_note, color: Colors.white38),
          );
        },
      ),
    );
  }
}