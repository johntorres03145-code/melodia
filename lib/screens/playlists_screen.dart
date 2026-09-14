import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/playlist_model.dart';
import '../pages/playlist_detail_page.dart';
import '../services/image_picker_service.dart';

/// Pantalla dedicada para gestionar playlists.
class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final playlists = context.watch<PlaylistModel>();
    final list = playlists.all;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: MelodiaColors.textColor(theme.isDarkMode)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Playlists',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: MelodiaColors.textColor(theme.isDarkMode),
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.effectiveAccent, size: 26),
            tooltip: 'Nueva playlist',
            onPressed: () => _createPlaylist(context),
          ),
        ],
      ),
      body: list.isEmpty
          ? _EmptyPlaylists(onCreate: () => _createPlaylist(context))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final playlist = list[i];
                return _PlaylistTile(playlist: playlist);
              },
            ),
    );
  }

  Widget _playlistCover(Playlist playlist, double size) {
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
          : Center(
              child: Icon(Icons.queue_music,
                  size: size * 0.3, color: Colors.white70),
            ),
    );
  }

  Future<void> _createPlaylist(BuildContext context) async {
    final theme = context.read<ThemeProvider>();
    final controller = TextEditingController();
    Uint8List? pickedCover;

    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nueva playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Nombre de la playlist'),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final service = ImagePickerService();
                  final bytes = await service.pickImage();
                  if (bytes != null) setState(() => pickedCover = bytes);
                },
                child: Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: MelodiaColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: theme.effectiveAccent.withValues(alpha: 0.4)),
                  ),
                  child: pickedCover != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(pickedCover!,
                              fit: BoxFit.cover,
                              width: double.infinity),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_library_outlined,
                                  color: theme.effectiveAccent),
                              const SizedBox(height: 4),
                              const Text('Portada (opcional)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: MelodiaColors.textSecondary)),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    if (name != null && name.trim().isNotEmpty) {
      if (!context.mounted) return;
      final model = context.read<PlaylistModel>();
      await model.create(name: name.trim(), coverImage: pickedCover);
    }
  }
}

// ═══════════════════ PLAYLIST TILE ═══════════════════

class _PlaylistTile extends StatelessWidget {
  final Playlist playlist;
  const _PlaylistTile({required this.playlist});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PlaylistDetailPage(playlistId: playlist.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MelodiaColors.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _CoverThumb(playlist: playlist),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${playlist.count} canciones',
                    style: const TextStyle(
                      fontSize: 12,
                      color: MelodiaColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: MelodiaColors.textColor(theme.isDarkMode),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════ COVER THUMB ═══════════════════

class _CoverThumb extends StatelessWidget {
  final Playlist playlist;
  const _CoverThumb({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: MelodiaColors.linearGradientMain,
      ),
      clipBehavior: Clip.antiAlias,
      child: playlist.coverImage != null
          ? Image.memory(playlist.coverImage!, fit: BoxFit.cover)
          : const Center(
              child: Icon(Icons.queue_music, size: 22, color: Colors.white70),
            ),
    );
  }
}

// ═══════════════════ EMPTY STATE ═══════════════════

class _EmptyPlaylists extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyPlaylists({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 56,
              color: theme.effectiveAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tenés playlists',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: MelodiaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Creá una playlist para agrupar\ntus canciones favoritas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: MelodiaColors.textInactive),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.effectiveAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Crear primera playlist',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
