import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/favorites_model.dart';
import '../models/library_model.dart';
import '../models/play_history_model.dart';
import '../models/player_model.dart';
import '../models/song.dart';
import '../widgets/song_tile_row.dart';

/// Favoritos: pantalla artística con hero, collage, stats y lista.
class FavoritesScreen extends StatelessWidget {
  final VoidCallback? onOpenLibrary;
  const FavoritesScreen({super.key, this.onOpenLibrary});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesModel>();
    final player = context.read<PlayerModel>();
    final theme = context.watch<ThemeProvider>();
    final history = context.watch<PlayHistoryModel>();
    final library = context.read<LibraryModel>();
    final songs = favorites.songs;

    // Top 4 más reproducidos para el collage
    final topFav = songs.isNotEmpty
        ? history.getTopPlayed(songs, limit: 4)
        : <LocalSong>[];

    // Stats
    final artistSet = songs.map((s) => s.artist.isEmpty ? 'Desconocido' : s.artist).toSet();
    final totalMin = songs.fold<int>(0, (acc, s) => acc + (s.durationMs ~/ 60000));

    return SafeArea(
      child: songs.isEmpty
          ? _EmptyFavorites(onOpenLibrary: onOpenLibrary)
          : ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 80),
              children: [
                // ── Hero header ──
                _HeroHeader(
                  songCount: songs.length,
                  accent: theme.effectiveAccent,
                ),

                // ── Collage 2×2 ──
                if (topFav.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Tus favoritas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MelodiaColors.textColor(theme.isDarkMode),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CoverCollage(
                    songs: topFav,
                    allFavSongs: songs,
                    player: player,
                    library: library,
                    theme: theme,
                  ),
                ],

                // ── Stats ──
                const SizedBox(height: 18),
                _StatsRow(
                  songCount: songs.length,
                  artistCount: artistSet.length,
                  minutes: totalMin,
                ),

                // ── Play all ──
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: () => player.playQueue(songs, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: MelodiaColors.linearGradientMain,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shuffle, size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Reproducir todo',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Lista ──
                const SizedBox(height: 14),
                ...List.generate(songs.length, (i) {
                  final song = songs[i];
                  return SongTileRow(
                    song: song,
                    onTap: () => player.playQueue(songs, i),
                    showFavorite: true,
                  );
                }),
              ],
            ),
    );
  }
}

// ═══════════════════ HERO HEADER ═══════════════════

class _HeroHeader extends StatefulWidget {
  final int songCount;
  final Color accent;
  const _HeroHeader({required this.songCount, required this.accent});

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader> {
  late final String _quote;

  @override
  void initState() {
    super.initState();
    _quote = _quotes[Random().nextInt(_quotes.length)];
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              MelodiaColors.electricViolet,
              MelodiaColors.magenta,
              MelodiaColors.midnight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(Icons.favorite, size: 38, color: Colors.white),
            const SizedBox(height: 8),
            const Text(
              'Favoritos',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              quote,
              style: const TextStyle(
                fontFamily: 'Playfair Display',
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                color: Color(0xCCFFFFFF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.songCount} ${widget.songCount == 1 ? 'canción' : 'canciones'}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xAAFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _quotes = [
  '"La música dice lo que nosotros no podemos."',
  '"Cada canción es un pedazo de alguien."',
  '"La música sana el alma."',
  '"Lo que toca el corazón, nunca se olvida."',
  '"Las canciones favoritas son el soundtrack de nuestra vida."',
];

// ═══════════════════ COVER COLLAGE ═══════════════════

class _CoverCollage extends StatelessWidget {
  final List<LocalSong> songs;
  final List<LocalSong> allFavSongs;
  final PlayerModel player;
  final LibraryModel library;
  final ThemeProvider theme;
  const _CoverCollage({
    required this.songs,
    required this.allFavSongs,
    required this.player,
    required this.library,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemCount: songs.length,
        itemBuilder: (context, i) {
          final song = songs[i];
          final isCurrent = player.current?.id == song.id && player.hasQueue;
          return GestureDetector(
            onTap: () {
              final idx = allFavSongs.indexWhere((s) => s.id == song.id);
              if (idx >= 0) player.playQueue(allFavSongs, idx);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: MelodiaColors.linearGradientMain,
                boxShadow: MelodiaColors.ambientGlow(
                  theme.effectiveAccent,
                  alpha: isCurrent ? 0.25 : 0.10,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Artwork
                  FutureBuilder<dynamic>(
                    future: library.songArtworkFor(song.id, albumId: song.albumId),
                    builder: (context, snap) {
                      if (snap.hasData && snap.data != null) {
                        return Image.memory(snap.data, fit: BoxFit.cover);
                      }
                      return Icon(
                        Icons.music_note,
                        size: 40,
                        color: theme.isDarkMode ? Colors.white24 : Colors.black26,
                      );
                    },
                  ),
                  // Overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  // Play button
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCurrent ? Colors.white : theme.effectiveAccent,
                      ),
                      child: Icon(
                        isCurrent ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 22,
                        color: isCurrent ? theme.effectiveAccent : Colors.white,
                      ),
                    ),
                  ),
                  // Playing indicator
                  if (isCurrent)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.equalizer, size: 12, color: theme.effectiveAccent),
                            const SizedBox(width: 4),
                            const Text(
                              'Ahora',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Title + artist
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          song.artist.isEmpty ? 'Desconocido' : song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFD4D4DC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════ STATS ROW ═══════════════════

class _StatsRow extends StatelessWidget {
  final int songCount;
  final int artistCount;
  final int minutes;
  const _StatsRow({
    required this.songCount,
    required this.artistCount,
    required this.minutes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final chips = [
      (Icons.music_note, '$songCount canciones'),
      (Icons.people_outline, '$artistCount artistas'),
      (Icons.access_time, '$minutes min'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: chips.map((c) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(c.$1, size: 13, color: theme.effectiveAccent),
                const SizedBox(width: 5),
                Text(
                  c.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MelodiaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════ EMPTY STATE ═══════════════════

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
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
              ),
              child: Icon(
                Icons.favorite_outline_rounded,
                size: 48,
                color: theme.effectiveAccent.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes favoritos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: MelodiaColors.textColor(theme.isDarkMode),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca el corazón en cualquier canción\npara añadirla aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: MelodiaColors.textInactive),
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
