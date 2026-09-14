import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/favorites_model.dart';
import '../models/library_model.dart';
import '../models/player_model.dart';
import '../models/song.dart';
import 'artwork_thumb.dart';

/// Fila de una canción: portada, título, artista, duración, corazón y menú.
class SongTileRow extends StatelessWidget {
  final LocalSong song;
  final VoidCallback? onTap;
  final bool showFavorite;

  const SongTileRow({
    super.key,
    required this.song,
    this.onTap,
    this.showFavorite = true,
  });

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesModel>();
    final isFav = favorites.isFavorite(song.id);

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: ArtworkThumb(song: song),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artist.isEmpty ? 'Artista desconocido' : song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showFavorite)
            IconButton(
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? context.read<ThemeProvider>().effectiveAccent : MelodiaColors.textInactive,
                size: 20,
              ),
              onPressed: () => favorites.toggle(song),
            ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: MelodiaColors.textInactive,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (value) => _onMenuAction(context, value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'play',
                child: _MenuTile(icon: Icons.play_arrow_rounded, title: 'Reproducir ahora'),
              ),
              const PopupMenuItem(
                value: 'queue',
                child: _MenuTile(icon: Icons.queue_music, title: 'Agregar a la cola'),
              ),
              PopupMenuItem(
                value: 'favorite',
                child: _MenuTile(
                  icon: isFav ? Icons.favorite : Icons.favorite_border,
                  title: isFav ? 'Quitar de favoritos' : 'Agregar a favoritos',
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: _MenuTile(icon: Icons.share, title: 'Compartir'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'hide',
                child: _MenuTile(icon: Icons.visibility_off, title: 'Ocultar canción'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _onMenuAction(BuildContext context, String value) {
    final player = context.read<PlayerModel>();
    final favorites = context.read<FavoritesModel>();
    final library = context.read<LibraryModel>();

    switch (value) {
      case 'play':
        player.playQueue([song], 0);
      case 'queue':
        player.addToQueue(song);
      case 'favorite':
        favorites.toggle(song);
      case 'share':
        break;
      case 'hide':
        library.hideSong(song.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canción ocultada: ${song.title}'),
            action: SnackBarAction(
              label: 'Deshacer',
              textColor: context.read<ThemeProvider>().effectiveAccent,
              onPressed: () => library.unhideSong(song.id),
            ),
            duration: const Duration(minutes: 5),
          ),
        );
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _MenuTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MelodiaColors.textSecondary),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
