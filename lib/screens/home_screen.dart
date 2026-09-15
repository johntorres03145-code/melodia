import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/library_model.dart';
import '../models/play_history_model.dart';
import '../models/player_model.dart';
import '../models/song.dart';
import '../utils/greeting.dart';
import '../widgets/melodia_logo.dart';
import '../widgets/song_tile_row.dart';
import 'stats_screen.dart';

/// Pantalla inicial: saludo + "Para ti" + "Explora" + "Recientemente".
class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenLibrary;
  const HomeScreen({super.key, this.onOpenProfile, this.onOpenLibrary});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _AlbumGroup {
  final String name;
  final String artist;
  final int? albumId;
  final List<LocalSong> songs;
  const _AlbumGroup({required this.name, required this.artist, this.albumId, required this.songs});
}

List<_AlbumGroup> _groupByAlbum(List<LocalSong> songs) {
  final map = <String, _AlbumGroup>{};
  for (final s in songs) {
    final key = '${s.albumId ?? s.album}|||${s.album}';
    final existing = map[key];
    if (existing != null) {
      existing.songs.add(s);
    } else {
      map[key] = _AlbumGroup(name: s.album, artist: s.artist, albumId: s.albumId, songs: [s]);
    }
  }
  return map.values.where((a) => a.songs.isNotEmpty).toList();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lib = context.read<LibraryModel>();
      if (lib.allSongs.isEmpty && !lib.loading) lib.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryModel>();
    final player = context.read<PlayerModel>();
    final history = context.watch<PlayHistoryModel>();
    final songs = library.allSongs;

    final pick = history.getTopPlayed(songs);
    final recent = history.getRecentlyPlayed(songs);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        children: [
          // ── Header ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  greetingByHour(DateTime.now()),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: MelodiaColors.textColor(theme.isDarkMode),
                      ),
                ),
              ),
              GestureDetector(
                onTap: widget.onOpenProfile,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: MelodiaColors.linearGradientMain,
                  ),
                  child: const Icon(Icons.person, size: 22, color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              MelodiaLogo(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
                color: theme.effectiveAccent,
              ),
              Text(
                ' · ${_subtitleByHour(DateTime.now())}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: theme.effectiveAccent,
                ),
              ),
            ],
          ),

          // ── Loading / Empty / Content ──
          if (library.loading && songs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (songs.isEmpty && library.error == null)
            const _EmptyHome()
          else if (songs.isEmpty && library.error != null)
            _HomeError(message: library.error!)
          else ...[
            const SizedBox(height: 28),
            // ── Para ti ──
            _SectionHeader(
              title: 'Para ti',
              action: 'Ver todo →',
              onTap: widget.onOpenLibrary,
            ),
            const SizedBox(height: 14),
            if (pick.isNotEmpty)
              _ForYouCarousel(songs: pick, player: player)
            else
              _EmptyCard(message: 'Escucha canciones para ver tus favoritas aquí'),

            const SizedBox(height: 32),
            // ── Explora ──
            _SectionHeader(title: 'Explora'),
            const SizedBox(height: 14),
            _AlbumGrid(songs: songs, player: player, theme: theme),

            // ── Recientemente ──
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 32),
              _SectionHeader(title: 'Recientemente'),
              const SizedBox(height: 14),
              _RecentlyPlayed(songs: recent, player: player),
            ],

            // ── Estadísticas ──
            if (history.all.isNotEmpty) ...[
              const SizedBox(height: 32),
              _SectionHeader(
                title: 'Tus estadísticas',
                action: 'Ver todo',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatsScreen()),
                  );
                },
              ),
              const SizedBox(height: 14),
              _StatsPreview(history: history, songs: songs, theme: theme),
            ],
          ],
        ],
      ),
    );
  }

  String _subtitleByHour(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 12) return 'ESCUCHÁ LO QUE AMAS';
    if (hour >= 12 && hour < 19) return 'TOMATE TU TIEMPO';
    return 'DEJÁ QUE SUENE';
  }
}

// ═══════════════════ SECTION HEADER ═══════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;
  const _SectionHeader({required this.title, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: MelodiaColors.textColor(theme.isDarkMode),
          ),
        ),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onTap,
            child: Text(
              action!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.effectiveAccent,
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════ PARA TI — CARRUSEL ═══════════════════

class _ForYouCarousel extends StatelessWidget {
  final List<LocalSong> songs;
  final PlayerModel player;
  const _ForYouCarousel({required this.songs, required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return SizedBox(
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 24),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final song = songs[i];
          final isCurrent = player.current?.id == song.id && player.hasQueue;
          return GestureDetector(
            onTap: () => player.playQueue(songs, i),
            child: SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'artwork_${song.id}',
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: MelodiaColors.linearGradientMain,
                        boxShadow: MelodiaColors.ambientGlow(
                          theme.effectiveAccent,
                          alpha: isCurrent ? 0.25 : 0.12,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FutureBuilder<dynamic>(
                            future: context.read<LibraryModel>().songArtworkFor(song.id, albumId: song.albumId),
                            builder: (context, snap) {
                              if (snap.hasData && snap.data != null) {
                                return Image.memory(snap.data, fit: BoxFit.cover);
                              }
                              return Icon(Icons.music_note, size: 40, color: theme.isDarkMode ? Colors.white24 : Colors.black26);
                            },
                          ),
                          // Play / Pause button
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
                                    const Text('Ahora', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                      color: isCurrent ? theme.effectiveAccent : null,
                    ),
                  ),
                  Text(
                    song.artist.isEmpty ? 'Artista desconocido' : song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: MelodiaColors.textSecondary),
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

// ═══════════════════ EXPLORA — CÍRCULOS ═══════════════════

class _AlbumGrid extends StatelessWidget {
  final List<LocalSong> songs;
  final PlayerModel player;
  final ThemeProvider theme;
  const _AlbumGrid({required this.songs, required this.player, required this.theme});

  @override
  Widget build(BuildContext context) {
    final albums = _groupByAlbum(songs);
    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 24),
        itemCount: albums.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final album = albums[i];
          return GestureDetector(
            onTap: () => _showAlbumSheet(context, album, player),
            child: SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(50),
                      gradient: MelodiaColors.linearGradientMain,
                      boxShadow: [
                        BoxShadow(
                          color: theme.effectiveAccent.withValues(alpha: 0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: FutureBuilder<dynamic>(
                      future: context.read<LibraryModel>().songArtworkFor(album.songs.first.id, albumId: album.albumId),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data != null) {
                          return Image.memory(snap.data, fit: BoxFit.cover);
                        }
                         return Icon(Icons.album, size: 40, color: theme.isDarkMode ? Colors.white24 : Colors.black26);
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAlbumSheet(BuildContext context, _AlbumGroup album, PlayerModel player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MelodiaColors.surfaceBaseFor(theme.isDarkMode),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.isDarkMode ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  album.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${album.artist} · ${album.songs.length} canciones',
                  style: const TextStyle(fontSize: 12, color: MelodiaColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: album.songs.length,
                    itemBuilder: (_, i) {
                      final song = album.songs[i];
                      return SongTileRow(
                        song: song,
                        onTap: () => player.playQueue(album.songs, i),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ═══════════════════ RECIENTEMENTE ═══════════════════

class _RecentlyPlayed extends StatelessWidget {
  final List<LocalSong> songs;
  final PlayerModel player;
  const _RecentlyPlayed({required this.songs, required this.player});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 24),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final song = songs[i];
          final isCurrent = player.current?.id == song.id && player.hasQueue;
          return GestureDetector(
            onTap: () => player.playQueue(songs, i),
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FutureBuilder<dynamic>(
                      future: context.read<LibraryModel>().songArtworkFor(song.id, albumId: song.albumId),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data != null) {
                          return Image.memory(snap.data, width: 48, height: 48, fit: BoxFit.cover);
                        }
                        return Container(
                          width: 48,
                          height: 48,
                          color: theme.isDarkMode ? Colors.white10 : Colors.black12,
                          child: Icon(Icons.music_note, color: theme.isDarkMode ? Colors.white38 : Colors.black38, size: 22),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent ? theme.effectiveAccent : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist.isEmpty ? 'Desconocido' : song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: MelodiaColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isCurrent ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 24,
                    color: isCurrent ? theme.effectiveAccent : MelodiaColors.textSecondary,
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

// ═══════════════════ EMPTY STATES ═══════════════════

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MelodiaColors.surfaceBaseFor(theme.isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 13, color: MelodiaColors.textSecondary),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: MelodiaColors.surfaceBaseFor(theme.isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(Icons.music_note, size: 40, color: theme.effectiveAccent),
          const SizedBox(height: 12),
          const Text(
            'Escanea tu música en la pestaña Library',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: MelodiaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  final String message;
  const _HomeError({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MelodiaColors.surfaceBaseFor(theme.isDarkMode),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 34, color: theme.effectiveAccent),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: MelodiaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Preview de estadísticas en el Home: top 3 canciones + top 3 artistas.
class _StatsPreview extends StatelessWidget {
  final PlayHistoryModel history;
  final List<LocalSong> songs;
  final ThemeProvider theme;
  const _StatsPreview({required this.history, required this.songs, required this.theme});

  @override
  Widget build(BuildContext context) {
    final topSongs = history.getTopPlayed(songs, limit: 3);
    final topArtists = history.getTopArtistas(songs, limit: 3);
    final accent = theme.effectiveAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MelodiaColors.surfaceBaseFor(theme.isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Canciones', style: TextStyle(fontSize: 11, color: MelodiaColors.textSecondary)),
                const SizedBox(height: 8),
                ...topSongs.asMap().entries.map((e) {
                  final s = e.value;
                  final plays = history.getPlayCount(s.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${e.key + 1}. ${s.title} ($plays)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Artistas', style: TextStyle(fontSize: 11, color: MelodiaColors.textSecondary)),
                const SizedBox(height: 8),
                ...topArtists.asMap().entries.map((e) {
                  final a = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${e.key + 1}. ${a.name} (${a.totalPlays})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
