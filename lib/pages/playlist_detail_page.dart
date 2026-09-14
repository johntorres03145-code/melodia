import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/library_model.dart';
import '../models/player_model.dart';
import '../models/playlist_model.dart';
import '../models/song.dart';
import '../services/image_picker_service.dart';
import '../widgets/artwork_thumb.dart';
import '../widgets/mini_player.dart';

/// Detalle de una playlist: su portada, nombre y canciones.
class PlaylistDetailPage extends StatelessWidget {
  final String playlistId;
  const PlaylistDetailPage({super.key, required this.playlistId});

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistModel>();
    final library = context.watch<LibraryModel>();
    final player = context.read<PlayerModel>();
    final playlist = playlists.getById(playlistId);
    final theme = context.watch<ThemeProvider>();

    if (playlist == null) {
      return const Scaffold(body: Center(child: Text('Playlist no disponible')));
    }

    final songs = library.allSongs
        .where((s) => playlist.songIds.contains(s.id.toString()))
        .toList();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(
        title: Text(
          playlist.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.isDarkMode
                ? MelodiaColors.whiteSoft
                : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Añadir canciones',
            onPressed: () => _addSongs(context, playlists, playlist),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editName(context, playlists, playlist),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, playlists, playlist),
          ),
        ],
      ),
      body: Column(
        children: [
          _header(context, playlist, songs.length),
          if (songs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ActionChip(
                    label: 'Reproducir todo',
                    icon: Icons.play_arrow_rounded,
                    filled: true,
                    accentColor: theme.effectiveAccent,
                    onTap: () => player.playQueue(songs, 0),
                  ),
                  const SizedBox(width: 12),
                  _ActionChip(
                    label: 'Aleatorio',
                    icon: Icons.shuffle,
                    filled: false,
                    accentColor: theme.effectiveAccent,
                    onTap: () {
                      final shuffled = List.of(songs)..shuffle();
                      player.playQueue(shuffled, 0);
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${songs.length} canciones',
                style: const TextStyle(
                  fontSize: 13,
                  color: MelodiaColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _songList(context, songs, playlists, playlist, player)),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Playlist playlist, int count) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _changeCover(context, playlist),
            child: _cover(playlist, 96),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: MelodiaColors.textColor(theme.isDarkMode),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count canciones',
                  style: const TextStyle(
                      fontSize: 13, color: MelodiaColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover(Playlist playlist, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: MelodiaColors.linearGradientMain,
      ),
      clipBehavior: Clip.antiAlias,
      child: playlist.coverImage != null
          ? Image.memory(playlist.coverImage!, fit: BoxFit.cover)
          : const Icon(Icons.queue_music,
              size: 28, color: Colors.white70),
    );
  }

  Future<void> _changeCover(BuildContext context, Playlist playlist) async {
    final service = ImagePickerService();
    final bytes = await service.pickImage();
    if (bytes == null) return;
    if (!context.mounted) return;
    context.read<PlaylistModel>().setCover(playlist.id, bytes);
  }

  Future<void> _editName(
      BuildContext context, PlaylistModel playlists, Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      await playlists.rename(playlist.id, newName.trim());
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, PlaylistModel playlists, Playlist playlist) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar playlist'),
        content: Text('¿Eliminar "${playlist.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await playlists.delete(playlist.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _addSongs(BuildContext context, PlaylistModel playlists, Playlist playlist) async {
    final library = context.read<LibraryModel>();
    final available = library.allSongs
        .where((s) => !playlist.songIds.contains(s.id.toString()))
        .toList();
    if (available.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todas las canciones ya están en la playlist')),
      );
      return;
    }
    final selected = await showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MelodiaColors.surfaceBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SongPickerSheet(songs: available),
    );
    if (selected == null || selected.isEmpty) return;
    for (final songId in selected) {
      final song = available.firstWhere((s) => s.id == songId);
      await playlists.addSong(playlist.id, song);
    }
  }

  Widget _songList(BuildContext context, List<LocalSong> songs,
      PlaylistModel playlists, Playlist playlist, PlayerModel player) {
    if (songs.isEmpty) {
      return Center(
        child: Text(
          'Esta playlist está vacía.\nAñade canciones desde tu biblioteca.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, color: MelodiaColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: songs.length,
      itemBuilder: (context, i) {
        final song = songs[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: ArtworkThumb(song: song),
          onTap: () => player.playQueue(songs, i),
          title: Text(song.title,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            song.artist.isEmpty ? 'Artista desconocido' : song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: MelodiaColors.textInactive,
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (value) {
              if (value == 'remove') {
                playlists.removeSong(playlist.id, song.id);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text('Quitar de la playlist', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Botón de acción compacto (fill / outline).
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.filled,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: accentColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet para seleccionar canciones de la biblioteca.
class _SongPickerSheet extends StatefulWidget {
  final List<LocalSong> songs;
  const _SongPickerSheet({required this.songs});

  @override
  State<_SongPickerSheet> createState() => _SongPickerSheetState();
}

class _SongPickerSheetState extends State<_SongPickerSheet> {
  final Set<int> _selected = {};
  String _query = '';

  List<LocalSong> get _filteredSongs {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return widget.songs;
    return widget.songs.where((s) =>
      s.title.toLowerCase().contains(q) ||
      s.artist.toLowerCase().contains(q) ||
      s.album.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final filtered = _filteredSongs;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Añadir canciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: MelodiaColors.textColor(theme.isDarkMode),
                      ),
                    ),
                  ),
                  Text(
                    '${_selected.length} seleccionadas',
                    style: const TextStyle(
                        fontSize: 13, color: MelodiaColors.textSecondary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Buscar canción, artista o álbum…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => setState(() => _query = ''),
                        )
                      : null,
                  isDense: true,
                  fillColor: MelodiaColors.surfaceRaised,
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Sin resultados',
                          style: TextStyle(color: MelodiaColors.textSecondary)),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final song = filtered[i];
                        final isSelected = _selected.contains(song.id);
                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(song.id);
                              } else {
                                _selected.remove(song.id);
                              }
                            });
                          },
                          title: Text(song.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            song.artist.isEmpty ? 'Artista desconocido' : song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: ArtworkThumb(song: song),
                          activeColor: theme.effectiveAccent,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(ctx).pop(_selected.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.effectiveAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('Añadir ${_selected.length} canción(es)'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
