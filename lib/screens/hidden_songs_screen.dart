import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/library_model.dart';
import '../models/player_model.dart';
import '../widgets/song_tile_row.dart';

/// Pantalla de gestión de canciones ocultas.
class HiddenSongsScreen extends StatelessWidget {
  const HiddenSongsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryModel>();
    final player = context.read<PlayerModel>();
    final hiddenSongs = library.hiddenSongs;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: MelodiaColors.textColor(theme.isDarkMode)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Canciones ocultas (${hiddenSongs.length})',
          style: TextStyle(
            color: MelodiaColors.textColor(theme.isDarkMode),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: hiddenSongs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility,
                        size: 56,
                        color: theme.effectiveAccent.withValues(alpha: 0.6)),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay canciones ocultas',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: MelodiaColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Mantené presionada una canción y elegí "Ocultar" para ocultarla de tu biblioteca.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: MelodiaColors.textInactive),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: hiddenSongs.length,
              itemBuilder: (context, i) {
                final song = hiddenSongs[i];
                return SongTileRow(
                  song: song,
                  onTap: () => player.playQueue(hiddenSongs, i),
                );
              },
            ),
    );
  }
}
