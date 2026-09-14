import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/player_model.dart';
import '../pages/youtube_player_screen.dart';
import '../services/youtube_audio_service.dart';
import '../services/youtube_search.dart';
import 'youtube_playlist_screen.dart';

const kYouTubeApiKey = String.fromEnvironment('YOUTUBE_API_KEY');

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _controller = TextEditingController();
  final YouTubeSearch _search =
      kYouTubeApiKey.isEmpty ? YouTubeSearch('') : YouTubeSearch(kYouTubeApiKey);
  final YouTubeAudioService _audioService = YouTubeAudioService();

  List<YouTubeVideo>? _results;
  List<YouTubePlaylist>? _playlists;
  bool _loading = false;
  String? _error;
  String? _loadingVideoId;

  Future<void> _submit(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = null;
      _playlists = null;
    });
    try {
      final resultsFuture = _search.search(q);
      final playlistsFuture = _search.searchPlaylists(q);
      final results = await resultsFuture;
      final playlists = await playlistsFuture;
      if (!mounted) return;
      setState(() {
        _results = results;
        _playlists = playlists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pude buscar: $e';
      });
    }
  }

  void _openVideo(YouTubeVideo video) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => YouTubePlayerScreen(video: video)),
    );
  }

  Future<void> _playAudio(
      YouTubeVideo video, List<YouTubeVideo> allVideos, int index) async {
    final player = context.read<PlayerModel>();
    if (!mounted) return;
    setState(() => _loadingVideoId = video.videoId);

    final audioUrl = await _audioService.getAudioUrl(video.videoId);
    if (audioUrl == null) {
      if (!mounted) return;
      setState(() => _loadingVideoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo obtener el audio de este video.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final audioSource =
        AudioSource.uri(Uri.parse(audioUrl), tag: 'yt_${video.videoId}');
    final sources = List<AudioSource?>.filled(allVideos.length, null);
    sources[index] = audioSource;
    setState(() => _loadingVideoId = null);
    await player.playYouTubeQueue(allVideos, sources, index);
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Explorar',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: MelodiaColors.textColor(theme.isDarkMode),
                  ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _submit,
              decoration: InputDecoration(
                hintText: 'Buscar en YouTube…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() {});
                        },
                      ),
                isDense: true,
                fillColor: MelodiaColors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildResults(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ThemeProvider theme) {
    if (kYouTubeApiKey.isEmpty) {
      return const _Message(
        icon: Icons.key,
        title: 'Falta la API key',
        body:
            'Compila con: flutter build apk --dart-define=YOUTUBE_API_KEY=TU_KEY',
      );
    }
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: theme.effectiveAccent));
    }
    if (_error != null) {
      return _Message(icon: Icons.error_outline, title: 'Error', body: _error!);
    }
    final results = _results;
    if (results == null) {
      return const _Message(
        icon: Icons.explore_outlined,
        title: 'Explora',
        body: 'Busca un artista, canción o tema.',
      );
    }
    if (results.isEmpty) {
      return const _Message(
        icon: Icons.search_off,
        title: 'Sin resultados',
        body: 'Prueba con otras palabras.',
      );
    }

    final playlists = _playlists;
    final hasPlaylists = playlists != null && playlists.isNotEmpty;

    return Column(
      children: [
        if (hasPlaylists) ...[
          Text(
            'Mixes y playlists',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MelodiaColors.textColor(theme.isDarkMode),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: playlists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _playlistCard(theme, playlists[i]),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Videos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MelodiaColors.textColor(theme.isDarkMode),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) {
              final video = results[i];
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration:
                    Duration(milliseconds: 300 + (i * 60).clamp(0, 500)),
                curve: Curves.easeOutCubic,
                builder: (_, opacity, child) => Opacity(
                  opacity: opacity,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - opacity)),
                    child: child,
                  ),
                ),
                child: _videoTile(theme, video, results, i),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _playlistCard(ThemeProvider theme, YouTubePlaylist playlist) {
    return GestureDetector(      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => YouTubePlaylistScreen(
              playlist: playlist,
              search: _search,
            ),
          ),
        );
      },
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: playlist.thumb.isNotEmpty
                      ? Image.network(
                          playlist.thumb,
                          width: 110,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 110,
                            height: 70,
                            color: MelodiaColors.surfaceRaised,
                            child: const Icon(Icons.queue_music,
                                color: Colors.white38, size: 28),
                          ),
                        )
                      : Container(
                          width: 110,
                          height: 70,
                          color: MelodiaColors.surfaceRaised,
                          child: const Icon(Icons.queue_music,
                              color: Colors.white38, size: 28),
                        ),
                ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.effectiveAccent.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow,
                        color: Colors.white, size: 22),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              playlist.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: MelodiaColors.textColor(theme.isDarkMode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoTile(ThemeProvider theme, YouTubeVideo video,
      List<YouTubeVideo> allVideos, int index) {
    final isLoading = _loadingVideoId == video.videoId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: isLoading ? null : () => _playAudio(video, allVideos, index),
      onLongPress: isLoading ? null : () => _openVideo(video),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            video.thumb.isNotEmpty
                ? Image.network(
                    video.thumb,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.white10,
                      child: const Icon(Icons.play_circle,
                          color: Colors.white38, size: 28),
                    ),
                  )
                : Container(
                    width: 72,
                    height: 72,
                    color: Colors.white10,
                    child: const Icon(Icons.play_circle,
                        color: Colors.white38, size: 28),
                  ),
            if (isLoading)
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.effectiveAccent,
                    ),
                  ),
                ),
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
          fontWeight: FontWeight.w600,
          color: isLoading ? theme.effectiveAccent : null,
        ),
      ),
      subtitle: Text(
        isLoading ? 'Cargando audio…' : video.channel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: isLoading
              ? theme.effectiveAccent.withValues(alpha: 0.7)
              : MelodiaColors.textSecondary,
        ),
      ),
      trailing: isLoading
          ? null
          : Icon(Icons.play_circle_outline,
              color: theme.effectiveAccent, size: 26),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Message({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.effectiveAccent),
            const SizedBox(height: 14),
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MelodiaColors.textColor(theme.isDarkMode))),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: MelodiaColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
