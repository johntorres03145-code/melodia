import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/player_model.dart';
import '../pages/now_playing_page.dart';
import '../screens/queue_screen.dart';
import '../services/youtube_search.dart';
import 'artwork_thumb.dart';

/// Barra inferior flotante con la canción en reproducción.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final theme = context.watch<ThemeProvider>();
    final song = player.current;
    final ytVideo = player.currentYouTube;

    if (!player.hasQueue) return const SizedBox.shrink();
    if (song == null && ytVideo == null) return const SizedBox.shrink();

    final title = song?.title ?? ytVideo?.title ?? '';
    final subtitle = song?.artist ?? ytVideo?.channel ?? '';
    final heroTag = song != null ? 'artwork_${song.id}' : 'artwork_yt_${ytVideo?.videoId ?? 'empty'}';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(_createRoute(const NowPlayingPage()));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: theme.isDarkMode
              ? MelodiaColors.surfaceRaised
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Hero(
              tag: heroTag,
              child: song != null
                  ? ArtworkThumb(song: song, size: 44)
                  : _YouTubeThumb(video: ytVideo, size: 44),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle.isEmpty ? 'Desconocido' : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: MelodiaColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: theme.effectiveAccent,
                size: 30,
              ),
              onPressed: () => player.togglePlay(),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.queue_music_rounded,
                  color: MelodiaColors.textSecondary, size: 22),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => ChangeNotifierProvider.value(
                    value: player,
                    child: DraggableScrollableSheet(
                      initialChildSize: 0.6,
                      minChildSize: 0.3,
                      maxChildSize: 0.9,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: BoxDecoration(
                            color: theme.backgroundColor,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          child: const QueueScreen(),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.skip_next_rounded,
                  color: MelodiaColors.textSecondary, size: 26),
              onPressed: () => player.next(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail para videos de YouTube (muestra la miniatura del video).
class _YouTubeThumb extends StatelessWidget {
  final YouTubeVideo? video;
  final double size;
  const _YouTubeThumb({required this.video, required this.size});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: video != null && video!.thumb.isNotEmpty
          ? Image.network(
              video!.thumb,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => Container(
                width: size,
                height: size,
                color: Colors.white10,
                child: const Icon(Icons.music_note, color: Colors.white38),
              ),
            )
          : Container(
              width: size,
              height: size,
              color: Colors.white10,
              child: const Icon(Icons.music_note, color: Colors.white38),
            ),
    );
  }
}

/// Ruta con transición slide-up + fade para Now Playing y otras pantallas.
Route<T> _createRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.5),
          ),
          child: child,
        ),
      );
    },
  );
}
