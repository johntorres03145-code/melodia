import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/player_model.dart';
import '../models/song.dart';
import '../services/youtube_search.dart';
import '../widgets/artwork_thumb.dart';

/// Pantalla de cola de reproducción (soporta local + YouTube).
/// Muestra la lista en el orden de reproducción actual (shuffle o natural).
class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final theme = context.watch<ThemeProvider>();
    final textColor =
        theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;
    final secondary = MelodiaColors.textSecondary;
    final accent = theme.effectiveAccent;

    final isYouTube = player.source == TrackSource.youtube;

    // Cola ordenada según shuffle
    final orderedList = isYouTube ? player.orderedYtQueue : player.orderedQueue;
    final queueLength = orderedList.length;

    // Encontrar posición actual en la lista ordenada
    final currentSongId = isYouTube
        ? player.currentYouTube?.videoId
        : player.current?.id;
    final currentOrderedIdx = currentSongId != null
        ? orderedList.indexWhere((item) =>
            isYouTube
                ? (item as dynamic).videoId == currentSongId
                : (item as dynamic).id == currentSongId)
        : -1;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        title: Text(
          'Cola de reproducción ($queueLength)',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.shuffle,
                color: player.shuffle ? accent : secondary, size: 20),
            onPressed: player.toggleShuffle,
          ),
        ],
      ),
      body: queueLength == 0
          ? Center(
              child: Text(
                'La cola está vacía',
                style: TextStyle(color: secondary, fontSize: 14),
              ),
            )
          : isYouTube
              ? _buildYouTubeQueue(
                  context, player, orderedList, currentOrderedIdx, textColor, secondary, accent)
              : _buildLocalQueue(
                  context, player, orderedList, currentOrderedIdx, textColor, secondary, accent),
    );
  }

  Widget _buildLocalQueue(
    BuildContext context,
    PlayerModel player,
    List<dynamic> orderedList,
    int currentOrderedIdx,
    Color textColor,
    Color secondary,
    Color accent,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: orderedList.length,
      itemBuilder: (context, index) {
        final song = orderedList[index] as LocalSong;
        final isCurrent = index == currentOrderedIdx;
        final isNext = index == currentOrderedIdx + 1;

        return Dismissible(
          key: ValueKey('queue_${song.id}'),
          direction: isCurrent
              ? DismissDirection.none
              : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: Colors.red.withValues(alpha: 0.8),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            // Find real index in original queue
            final realIdx = player.queue.indexOf(song);
            if (realIdx >= 0) player.removeFromQueue(realIdx);
          },
          child: _queueTile(
            isCurrent: isCurrent,
            isNext: isNext,
            leading: isCurrent
                ? Icon(Icons.equalizer, color: accent, size: 20)
                : ArtworkThumb(song: song, size: 44),
            title: song.title,
            subtitle: song.artist.isEmpty ? 'Desconocido' : song.artist,
            trailing: isCurrent
                ? null
                : Text(
                    '${index + 1}',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
            onTap: isCurrent ? null : () {
              // Find real index in original queue for skipToIndex
              final realIdx = player.queue.indexOf(song);
              if (realIdx >= 0) player.skipToIndex(realIdx);
            },
            accent: accent,
            textColor: textColor,
            secondary: secondary,
          ),
        );
      },
    );
  }

  Widget _buildYouTubeQueue(
    BuildContext context,
    PlayerModel player,
    List<dynamic> orderedList,
    int currentOrderedIdx,
    Color textColor,
    Color secondary,
    Color accent,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: orderedList.length,
      itemBuilder: (context, index) {
        final video = orderedList[index] as YouTubeVideo;
        final isCurrent = index == currentOrderedIdx;
        final isNext = index == currentOrderedIdx + 1;

        return _queueTile(
          isCurrent: isCurrent,
          isNext: isNext,
          leading: isCurrent
              ? Icon(Icons.equalizer, color: accent, size: 20)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: video.thumb.isNotEmpty
                      ? Image.network(
                          video.thumb,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.white10,
                            child: const Icon(Icons.music_note,
                                color: Colors.white38, size: 18),
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 44,
                          color: Colors.white10,
                          child: const Icon(Icons.music_note,
                              color: Colors.white38, size: 18),
                        ),
                ),
          title: video.title,
          subtitle: video.channel,
          trailing: isCurrent
              ? null
              : Text(
                  '${index + 1}',
                  style: TextStyle(fontSize: 12, color: secondary),
                ),
          onTap: isCurrent ? null : () {
            final realIdx = player.ytQueue.indexOf(video);
            if (realIdx >= 0) player.skipToYtIndex(realIdx);
          },
          accent: accent,
          textColor: textColor,
          secondary: secondary,
        );
      },
    );
  }

  Widget _queueTile({
    required bool isCurrent,
    required bool isNext,
    required Widget leading,
    required String title,
    required String subtitle,
    required Widget? trailing,
    required VoidCallback? onTap,
    required Color accent,
    required Color textColor,
    required Color secondary,
  }) {
    return Container(
      decoration: isNext
          ? BoxDecoration(
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(8),
              color: accent.withValues(alpha: 0.06),
            )
          : null,
      child: ListTile(
        leading: leading,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? accent : textColor,
          ),
        ),
        subtitle: Row(
          children: [
            if (isNext) ...[
              Icon(Icons.skip_next, size: 12, color: accent),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: isCurrent
                      ? accent.withValues(alpha: 0.7)
                      : isNext
                          ? accent.withValues(alpha: 0.6)
                          : secondary,
                ),
              ),
            ),
          ],
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
