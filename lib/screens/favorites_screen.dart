import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/favorites_model.dart';
import '../models/player_model.dart';
import '../widgets/song_tile_row.dart';

/// Favoritos: colección personal de canciones elegidas por el usuario.
class FavoritesScreen extends StatelessWidget {
  final VoidCallback? onOpenLibrary;
  const FavoritesScreen({super.key, this.onOpenLibrary});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesModel>();
    final player = context.read<PlayerModel>();
    final theme = context.watch<ThemeProvider>();
    final songs = favorites.songs;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Favorites',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: MelodiaColors.textColor(theme.isDarkMode),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 14,
                      color: theme.effectiveAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      songs.isEmpty
                          ? 'Toca el corazón en cualquier canción'
                          : '${songs.length} canciones',
                      style: const TextStyle(fontSize: 13, color: MelodiaColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Acciones ──
          if (songs.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
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

          // ── Lista ──
          const SizedBox(height: 8),
          Expanded(
            child: songs.isEmpty
                ? _EmptyFavorites(onOpenLibrary: onOpenLibrary)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: songs.length,
                    itemBuilder: (context, i) {
                      final song = songs[i];
                      return SongTileRow(
                        song: song,
                        onTap: () => player.playQueue(songs, i),
                        showFavorite: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Botón de acción compacto (llen outline).
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

/// Estado vacío: aún no hay favoritos.
class _EmptyFavorites extends StatelessWidget {
  final VoidCallback? onOpenLibrary;
  const _EmptyFavorites({this.onOpenLibrary});

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
              Icons.favorite_outline_rounded,
              size: 56,
              color: theme.effectiveAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes favoritos',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: MelodiaColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Guarda las canciones que quieras\nvolver a escuchar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: MelodiaColors.textInactive),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onOpenLibrary,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.effectiveAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Explorar música',
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
