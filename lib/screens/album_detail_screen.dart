import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/library_model.dart';
import '../models/player_model.dart';
import '../models/song.dart';
import '../widgets/mini_player.dart';
import '../widgets/song_tile_row.dart';

/// Pantalla de detalle de álbum: portada + lista de canciones.
class AlbumDetailScreen extends StatelessWidget {
  final String albumName;
  final List<LocalSong> songs;
  final int? albumId;
  const AlbumDetailScreen({super.key, required this.albumName, required this.songs, this.albumId});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.read<LibraryModel>();
    final player = context.read<PlayerModel>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      bottomNavigationBar: const MiniPlayer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: theme.backgroundColor,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: MelodiaColors.textColor(theme.isDarkMode)),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: albumId != null
                  ? FutureBuilder<dynamic>(
                      future: library.artworkFor(albumId),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data != null) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(snap.data, fit: BoxFit.cover),
                              const DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black54],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(gradient: MelodiaColors.linearGradientMain),
                          child: const Center(child: Icon(Icons.library_music, size: 80, color: Colors.white38)),
                        );
                      },
                    )
                  : Container(
                      decoration: BoxDecoration(gradient: MelodiaColors.linearGradientMain),
                      child: const Center(child: Icon(Icons.library_music, size: 80, color: Colors.white38)),
                    ),
            ),
            title: Text(
              albumName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                '${songs.length} canciones',
                style: const TextStyle(fontSize: 13, color: MelodiaColors.textSecondary),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final song = songs[i];
                return SongTileRow(
                  song: song,
                  onTap: () => player.playQueue(songs, i),
                );
              },
              childCount: songs.length,
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}
