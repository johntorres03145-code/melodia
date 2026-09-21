import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/library_model.dart';
import '../models/song.dart';

/// Portada de una canción con caché. Muestra un icono si no hay carátula.
class ArtworkThumb extends StatefulWidget {
  final LocalSong song;
  final double size;

  const ArtworkThumb({super.key, required this.song, this.size = 48});

  @override
  State<ArtworkThumb> createState() => _ArtworkThumbState();
}

class _ArtworkThumbState extends State<ArtworkThumb> {
  late Future<dynamic> _future;

  @override
  void initState() {
    super.initState();
    _loadArtwork();
  }

  @override
  void didUpdateWidget(covariant ArtworkThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _loadArtwork();
    }
  }

  void _loadArtwork() {
    _future = context.read<LibraryModel>().songArtworkFor(widget.song.id, albumId: widget.song.albumId);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<dynamic>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            return Image.memory(
              snap.data,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              gaplessPlayback: true,
            );
          }
          return Container(
            width: widget.size,
            height: widget.size,
            color: Colors.white10,
            child: const Icon(Icons.music_note, color: Colors.white38),
          );
        },
      ),
    );
  }
}
