import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/library_model.dart';
import '../models/play_history_model.dart';
import '../models/song.dart';
import '../widgets/artwork_thumb.dart';

/// Pantalla de estadísticas: top artistas y top canciones con artwork y barras.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final history = context.watch<PlayHistoryModel>();
    final library = context.watch<LibraryModel>();
    final songs = library.songs;
    final textColor = theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;
    final secondary = MelodiaColors.textSecondary;
    final accent = theme.effectiveAccent;

    final topSongs = history.getTopPlayed(songs, limit: 10);
    final topArtists = history.getTopArtistas(songs, limit: 10);

    final totalPlays = history.all.fold<int>(0, (sum, e) => sum + e.playCount);
    final totalSongs = history.all.length;
    final totalSeconds = history.getTotalListeningSeconds(songs);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'Estadísticas',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Summary ──
          if (totalPlays > 0) ...[
            _SummaryHeader(
              totalPlays: totalPlays,
              totalSongs: totalSongs,
              totalSeconds: totalSeconds,
              accent: accent,
              textColor: textColor,
            ),
            const SizedBox(height: 28),
          ],

          // ── Top Artistas ──
          _SectionTitle(title: 'Top Artistas', textColor: textColor),
          const SizedBox(height: 12),
          if (topArtists.isEmpty)
            _EmptyState(text: 'Aún no hay datos', color: secondary)
          else
            ...topArtists.asMap().entries.map((entry) {
              final i = entry.key;
              final artist = entry.value;
              final maxPlays = topArtists.first.totalPlays;
              return _AnimatedStatItem(
                index: i,
                child: _ArtistTile(
                  rank: i + 1,
                  artist: artist,
                  maxPlays: maxPlays,
                  accent: accent,
                  textColor: textColor,
                  secondary: secondary,
                ),
              );
            }),
          const SizedBox(height: 32),

          // ── Top Canciones ──
          _SectionTitle(title: 'Top Canciones', textColor: textColor),
          const SizedBox(height: 12),
          if (topSongs.isEmpty)
            _EmptyState(text: 'Aún no hay datos', color: secondary)
          else
            ...topSongs.asMap().entries.map((entry) {
              final i = entry.key;
              final song = entry.value;
              final plays = history.getPlayCount(song.id);
              final maxPlays = history.getPlayCount(topSongs.first.id);
              return _AnimatedStatItem(
                index: i,
                child: _SongTile(
                  rank: i + 1,
                  song: song,
                  plays: plays,
                  maxPlays: maxPlays,
                  library: library,
                  accent: accent,
                  textColor: textColor,
                  secondary: secondary,
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ── Summary header ──

class _SummaryHeader extends StatelessWidget {
  final int totalPlays;
  final int totalSongs;
  final int totalSeconds;
  final Color accent;
  final Color textColor;

  const _SummaryHeader({
    required this.totalPlays,
    required this.totalSongs,
    required this.totalSeconds,
    required this.accent,
    required this.textColor,
  });

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(
            value: '$totalPlays',
            label: 'Repros.',
            accent: accent,
            textColor: textColor,
          ),
          Container(width: 1, height: 36, color: accent.withValues(alpha: 0.2)),
          _SummaryItem(
            value: '$totalSongs',
            label: 'Canciones',
            accent: accent,
            textColor: textColor,
          ),
          Container(width: 1, height: 36, color: accent.withValues(alpha: 0.2)),
          _SummaryItem(
            value: _formatDuration(totalSeconds),
            label: 'Escucha',
            accent: accent,
            textColor: textColor,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;
  final Color textColor;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.accent,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: MelodiaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Section title ──

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color textColor;

  const _SectionTitle({required this.title, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }
}

// ── Empty state ──

class _EmptyState extends StatelessWidget {
  final String text;
  final Color color;

  const _EmptyState({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(text, style: TextStyle(color: color, fontSize: 14)),
      ),
    );
  }
}

// ── Animated entrance for each stat item ──

class _AnimatedStatItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedStatItem({required this.index, required this.child});

  @override
  State<_AnimatedStatItem> createState() => _AnimatedStatItemState();
}

class _AnimatedStatItemState extends State<_AnimatedStatItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ── Artist tile with circular avatar + bar ──

class _ArtistTile extends StatelessWidget {
  final int rank;
  final ArtistStats artist;
  final int maxPlays;
  final Color accent;
  final Color textColor;
  final Color secondary;

  const _ArtistTile({
    required this.rank,
    required this.artist,
    required this.maxPlays,
    required this.accent,
    required this.textColor,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final ratio = maxPlays > 0 ? artist.totalPlays / maxPlays : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTop3 ? accent.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 16,
                fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
                color: isTop3 ? accent : secondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.3),
                  accent.withValues(alpha: 0.1),
                ],
              ),
            ),
            child: const Icon(Icons.person, size: 22, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${artist.songCount} canciones',
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 4,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            height: 4,
                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent,
                                  accent.withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${artist.totalPlays}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Song tile with artwork + bar ──

class _SongTile extends StatelessWidget {
  final int rank;
  final LocalSong song;
  final int plays;
  final int maxPlays;
  final LibraryModel library;
  final Color accent;
  final Color textColor;
  final Color secondary;

  const _SongTile({
    required this.rank,
    required this.song,
    required this.plays,
    required this.maxPlays,
    required this.library,
    required this.accent,
    required this.textColor,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final ratio = maxPlays > 0 ? plays / maxPlays : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTop3 ? accent.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 16,
                fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
                color: isTop3 ? accent : secondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 42,
              height: 42,
              child: ArtworkThumb(song: song, size: 42),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                Text(
                  song.artist.isEmpty ? 'Desconocido' : song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: secondary),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 4,
                            width: constraints.maxWidth,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            height: 4,
                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent,
                                  accent.withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$plays',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}
