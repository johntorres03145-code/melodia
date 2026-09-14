import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/player_model.dart';
import '../services/youtube_audio_service.dart';
import '../services/youtube_search.dart';

/// Pantalla visual de una playlist de YouTube.
/// Muestra la lista de canciones con indicador de la que está sonando.
class YouTubePlaylistScreen extends StatefulWidget {
  final YouTubePlaylist playlist;
  final YouTubeSearch search;

  const YouTubePlaylistScreen({
    super.key,
    required this.playlist,
    required this.search,
  });

  @override
  State<YouTubePlaylistScreen> createState() => _YouTubePlaylistScreenState();
}

class _YouTubePlaylistScreenState extends State<YouTubePlaylistScreen> {
  List<YouTubeVideo>? _videos;
  bool _loading = true;
  String? _error;
  bool _playing = false;
  final YouTubeAudioService _audioService = YouTubeAudioService();

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      final videos =
          await widget.search.fetchPlaylistVideos(widget.playlist.playlistId);
      if (!mounted) return;
      setState(() {
        _videos = videos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error al cargar: $e';
      });
    }
  }

  Future<void> _playAll() async {
    final videos = _videos;
    if (videos == null || videos.isEmpty) return;
    final player = context.read<PlayerModel>();
    setState(() => _playing = true);

    final audioUrl = await _audioService.getAudioUrl(videos.first.videoId);
    if (audioUrl == null) {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener el audio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final sources = List<AudioSource?>.filled(videos.length, null);
    sources[0] =
        AudioSource.uri(Uri.parse(audioUrl), tag: 'yt_${videos.first.videoId}');
    setState(() => _playing = false);
    await player.playYouTubeQueue(videos, sources, 0);
  }

  Future<void> _playShuffled() async {
    final videos = _videos;
    if (videos == null || videos.isEmpty) return;
    final player = context.read<PlayerModel>();
    setState(() => _playing = true);

    final audioUrl = await _audioService.getAudioUrl(videos.first.videoId);
    if (audioUrl == null) {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener el audio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final sources = List<AudioSource?>.filled(videos.length, null);
    sources[0] =
        AudioSource.uri(Uri.parse(audioUrl), tag: 'yt_${videos.first.videoId}');
    setState(() => _playing = false);
    await player.playYouTubeQueue(videos, sources, 0);
    if (!player.shuffle) player.toggleShuffle();
  }

  Future<void> _playFromIndex(int index) async {
    final videos = _videos;
    if (videos == null || index >= videos.length) return;
    final player = context.read<PlayerModel>();
    setState(() => _playing = true);

    final audioUrl = await _audioService.getAudioUrl(videos[index].videoId);
    if (audioUrl == null) {
      if (!mounted) return;
      setState(() => _playing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener el audio.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final sources = List<AudioSource?>.filled(videos.length, null);
    sources[index] =
        AudioSource.uri(Uri.parse(audioUrl), tag: 'yt_${videos[index].videoId}');
    setState(() => _playing = false);
    await player.playYouTubeQueue(videos, sources, index);
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerModel>();
    final accent = theme.effectiveAccent;
    final textColor = theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;
    final secondary = MelodiaColors.textSecondary;

    final currentYtVideo = player.source == TrackSource.youtube
        ? player.currentYouTube
        : null;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Header con portada + info ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: theme.backgroundColor,
            iconTheme: IconThemeData(color: textColor),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.playlist.thumb.isNotEmpty
                      ? Image.network(
                          widget.playlist.thumb,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: MelodiaColors.surfaceRaised,
                            child: const Icon(Icons.queue_music,
                                color: Colors.white38, size: 64),
                          ),
                        )
                      : Container(
                          color: MelodiaColors.surfaceRaised,
                          child: const Icon(Icons.queue_music,
                              color: Colors.white38, size: 64),
                        ),
                  // Degradado
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  // Info abajo
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.playlist.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.playlist.channel} · ${_videos?.length ?? widget.playlist.videoCount} canciones',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (_videos != null && _videos!.isNotEmpty) ...[
                // Botón shuffle
                IconButton(
                  icon: Icon(
                    player.shuffle ? Icons.shuffle : Icons.shuffle,
                    color: player.shuffle ? accent : secondary,
                  ),
                  tooltip: 'Aleatorio',
                  onPressed: _playing ? null : _playShuffled,
                ),
              ],
            ],
          ),

          // ── Botones de acción ──
          if (_videos != null && _videos!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _playing ? null : _playAll,
                        icon: _playing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.play_arrow, size: 22),
                        label: Text(_playing ? 'Cargando...' : 'Reproducir todo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _playing ? null : _playShuffled,
                        icon: Icon(Icons.shuffle, color: accent, size: 20),
                        label: Text('Aleatorio',
                            style: TextStyle(color: accent)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: accent.withValues(alpha: 0.4)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Loading / Error ──
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            )
          else if (_videos == null || _videos!.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('La playlist está vacía',
                    style: TextStyle(color: secondary)),
              ),
            )
          else ...[
            // ── Lista de canciones ──
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final video = _videos![index];
                  final isCurrent =
                      currentYtVideo?.videoId == video.videoId;
                  final isLoadingThis =
                      player.isLoadingYouTube && isCurrent;

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(
                        milliseconds: 200 + (index * 40).clamp(0, 400)),
                    curve: Curves.easeOutCubic,
                    builder: (_, opacity, child) => Opacity(
                      opacity: opacity,
                      child: child,
                    ),
                    child: Container(
                      decoration: isCurrent
                          ? BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              border: Border(
                                left: BorderSide(
                                    color: accent, width: 3),
                              ),
                            )
                          : null,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 2),
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: video.thumb.isNotEmpty
                                    ? Image.network(
                                        video.thumb,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.white10,
                                          child: const Icon(
                                              Icons.music_note,
                                              color: Colors.white38,
                                              size: 20),
                                        ),
                                      )
                                    : Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.white10,
                                        child: const Icon(
                                            Icons.music_note,
                                            color: Colors.white38,
                                            size: 20),
                                      ),
                              ),
                              if (isCurrent)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: isLoadingThis
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: accent,
                                          ),
                                        )
                                      : Icon(Icons.equalizer,
                                          color: accent, size: 22),
                                ),
                            ],
                          ),
                        ),
                        title: Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isCurrent ? FontWeight.w700 : FontWeight.w500,
                            color: isCurrent ? accent : textColor,
                          ),
                        ),
                        subtitle: Text(
                          video.channel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent
                                ? accent.withValues(alpha: 0.7)
                                : secondary,
                          ),
                        ),
                        trailing: isCurrent
                            ? Icon(Icons.equalizer, color: accent, size: 18)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                    fontSize: 12, color: secondary),
                              ),
                        onTap: _playing ? null : () => _playFromIndex(index),
                      ),
                    ),
                  );
                },
                childCount: _videos!.length,
              ),
            ),

            // ── Espacio al final ──
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ],
      ),
    );
  }
}
