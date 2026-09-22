import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/favorites_model.dart';
import '../models/library_model.dart';
import '../models/play_history_model.dart';
import '../models/player_model.dart';
import '../models/playlist_model.dart';
import '../models/song.dart';
import 'youtube_audio_service.dart';
import 'youtube_search.dart';

const _catRoot = 'root';
const _catAllSongs = 'cat_songs';
const _catAlbums = 'cat_albums';
const _catArtists = 'cat_artists';
const _catFavorites = 'cat_favorites';
const _catRecent = 'cat_recent';
const _catRecentAA = 'recent';
const _catTopPlayed = 'cat_top_played';
const _catPlaylists = 'cat_playlists';
const _catPlaylistItems = 'playlist_';

class AudioPlayerHandler extends BaseAudioHandler {
  AudioPlayer player;
  final PlayerModel model;
  LibraryModel? _library;
  FavoritesModel? _favorites;
  PlayHistoryModel? _playHistory;
  PlaylistModel? _playlists;
  YouTubeSearch? _ytSearch;
  final YouTubeAudioService _ytAudioService = YouTubeAudioService();
  StreamSubscription? _eventSub;
  StreamSubscription? _processingSub;
  Timer? _periodicTimer;
  Directory? _artDir;

  AudioPlayerHandler({required this.player, required this.model}) {
    _subscribeToPlayer();
    _startPeriodicRefresh();
  }

  void rebindPlayer(AudioPlayer newPlayer) {
    _eventSub?.cancel();
    _processingSub?.cancel();
    player = newPlayer;
    _subscribeToPlayer();
  }

  void _subscribeToPlayer() {
    _eventSub?.cancel();
    _processingSub?.cancel();
    _eventSub = player.playbackEventStream.listen((event) {
      _notifyPlaybackState(
        controls: _controls,
        processingState: _mapProcessing(event.processingState),
        playing: player.playing,
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
      );
    });
    _processingSub = player.processingStateStream.listen((p) {
      if (p == ProcessingState.completed) {
        _notifyPlaybackState(playing: false);
      }
    });
  }

  void _startPeriodicRefresh() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _notifyPlaybackState(
        controls: _controls,
        processingState: _mapProcessing(player.processingState),
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
      );
    });
  }

  void attachLibrary(LibraryModel library) => _library = library;
  void attachFavorites(FavoritesModel favorites) => _favorites = favorites;
  void attachPlayHistory(PlayHistoryModel history) => _playHistory = history;
  void attachPlaylists(PlaylistModel playlists) => _playlists = playlists;
  void attachYouTubeSearch(YouTubeSearch search) => _ytSearch = search;

  // ═══════════════════ ANDROID AUTO BROWSING ═══════════════════

  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    switch (parentMediaId) {
      case _catRoot:
        return _getRootCategories();
      case _catAllSongs:
        return _getAllSongs();
      case _catAlbums:
        return _getAlbums();
      case _catFavorites:
        return _getFavorites();
      case _catArtists:
        return _getArtists();
      case _catRecent:
      case _catRecentAA:
        return _getRecent();
      case _catTopPlayed:
        return _getTopPlayed();
      case _catPlaylists:
        return _getPlaylists();
      default:
        if (parentMediaId.startsWith(_catPlaylistItems)) {
          return _getPlaylistSongs(
              parentMediaId.substring(_catPlaylistItems.length));
        } else if (parentMediaId.startsWith('album_')) {
          return _getSongsByAlbum(parentMediaId.substring(6));
        } else if (parentMediaId.startsWith('artist_')) {
          return _getSongsByArtist(parentMediaId.substring(7));
        }
        return [];
    }
  }

  List<MediaItem> _getRootCategories() {
    final lib = _library;
    final songCount = lib?.allSongs.length ?? 0;
    final albumCount = lib?.albums.length ?? 0;
    final artistCount = lib?.artists.length ?? 0;
    final favCount = _favorites?.songs.length ?? 0;
    final recentCount = _playHistory != null
        ? _playHistory!.getRecentlyPlayed(lib?.allSongs ?? [], limit: 50).length
        : 0;
    final topPlayedCount = _playHistory != null
        ? _playHistory!.getTopPlayed(lib?.allSongs ?? [], limit: 50).length
        : 0;

    return [
      MediaItem(
        id: _catAllSongs,
        title: 'Todas las canciones',
        displaySubtitle: '$songCount canciones',
        playable: false,
      ),
      MediaItem(
        id: _catAlbums,
        title: 'Álbumes',
        displaySubtitle: '$albumCount álbumes',
        playable: false,
      ),
      MediaItem(
        id: _catArtists,
        title: 'Artistas',
        displaySubtitle: '$artistCount artistas',
        playable: false,
      ),
      MediaItem(
        id: _catFavorites,
        title: 'Favoritos',
        displaySubtitle: '$favCount canciones',
        playable: false,
      ),
      MediaItem(
        id: _catRecent,
        title: 'Recientes',
        displaySubtitle: '$recentCount canciones',
        playable: false,
      ),
      MediaItem(
        id: _catTopPlayed,
        title: 'Más escuchadas',
        displaySubtitle: '$topPlayedCount canciones',
        playable: false,
      ),
      MediaItem(
        id: _catPlaylists,
        title: 'Playlists',
        displaySubtitle: '${_playlists?.all.length ?? 0} playlists',
        playable: false,
      ),
    ];
  }

  Future<List<MediaItem>> _getAllSongs() async {
    final lib = _library;
    if (lib == null) return [];
    return _songsToMediaItems(lib.allSongs);
  }

  Future<List<MediaItem>> _getAlbums() async {
    final lib = _library;
    if (lib == null) return [];
    return lib.albums.map((a) => MediaItem(
          id: 'album_${a.name}',
          title: a.name,
          displaySubtitle: '${a.songCount} canciones',
          playable: false,
        )).toList();
  }

  Future<List<MediaItem>> _getSongsByAlbum(String albumName) async {
    final lib = _library;
    if (lib == null) return [];
    return _songsToMediaItems(lib.songsByAlbum(albumName));
  }

  Future<List<MediaItem>> _getArtists() async {
    final lib = _library;
    if (lib == null) return [];
    return lib.artists.map((a) => MediaItem(
          id: 'artist_${a.name}',
          title: a.name,
          displaySubtitle: '${a.songCount} canciones',
          playable: false,
        )).toList();
  }

  Future<List<MediaItem>> _getSongsByArtist(String artistName) async {
    final lib = _library;
    if (lib == null) return [];
    return _songsToMediaItems(lib.songsByArtist(artistName));
  }

  Future<List<MediaItem>> _getFavorites() async {
    final favs = _favorites;
    if (favs == null) return [];
    return _songsToMediaItems(favs.songs);
  }

  Future<List<MediaItem>> _getRecent() async {
    final hist = _playHistory;
    final lib = _library;
    if (hist == null || lib == null) return [];
    return _songsToMediaItems(hist.getRecentlyPlayed(lib.allSongs, limit: 50));
  }

  Future<List<MediaItem>> _getTopPlayed() async {
    final hist = _playHistory;
    final lib = _library;
    if (hist == null || lib == null) return [];
    return _songsToMediaItems(hist.getTopPlayed(lib.allSongs, limit: 50));
  }

  Future<List<MediaItem>> _getPlaylists() async {
    final playlists = _playlists;
    if (playlists == null) return [];
    return playlists.all.map((p) => MediaItem(
          id: '${_catPlaylistItems}${p.id}',
          title: p.name,
          displaySubtitle: '${p.count} canciones',
          playable: false,
        )).toList();
  }

  Future<List<MediaItem>> _getPlaylistSongs(String playlistId) async {
    final playlists = _playlists;
    final lib = _library;
    if (playlists == null || lib == null) return [];
    final playlist = playlists.getById(playlistId);
    if (playlist == null) return [];
    final songMap = {for (final s in lib.allSongs) s.id.toString(): s};
    final songs = playlist.songIds
        .map((id) => songMap[id])
        .whereType<LocalSong>()
        .toList();
    return _songsToMediaItems(songs);
  }

  Future<List<MediaItem>> _songsToMediaItems(List<LocalSong> songs) async {
    final futures = songs.map((s) async {
      Uri? artUri;
      if (_library != null) {
        final bytes = await _library!.songArtworkFor(s.id, albumId: s.albumId);
        artUri = await _writeArtwork(s.id, bytes);
      }
      return MediaItem(
        id: s.path,
        title: s.title,
        artist: s.artist.isEmpty ? 'Artista desconocido' : s.artist,
        album: s.album,
        duration: s.duration,
        artUri: artUri,
        playable: true,
      );
    }).toList();
    return Future.wait(futures);
  }

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    if (mediaId.startsWith('yt_')) {
      final videoId = mediaId.substring(3);
      final q = super.queue.value;
      final existing = q.firstWhere(
        (item) => item.id == mediaId,
        orElse: () => MediaItem(id: mediaId, title: ''),
      );
      final audioUrl = await _ytAudioService.getAudioUrl(videoId);
      if (audioUrl == null) return;
      final source = AudioSource.uri(Uri.parse(audioUrl), tag: 'yt_$videoId');
      final video = YouTubeVideo(
        videoId: videoId,
        title: existing.title.isNotEmpty ? existing.title : (extras?['title'] ?? videoId),
        channel: existing.artist ?? (extras?['artist'] ?? ''),
        thumb: existing.artUri?.toString() ?? (extras?['thumb'] ?? ''),
      );
      await model.playYouTubeQueue([video], [source], 0);
      return;
    }
    final lib = _library;
    if (lib == null) return;
    final songs = lib.allSongs;
    final index = songs.indexWhere((s) => s.path == mediaId);
    if (index >= 0) {
      model.playQueue(songs, index);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final q = super.queue.value;
    if (index < 0 || index >= q.length) return;
    final item = q[index];
    await playFromMediaId(item.id, {
      'title': item.title,
      'artist': item.artist,
    });
  }

  // ═══════════════════ BÚSQUEDA ANDROID AUTO ═══════════════════

  @override
  Future<List<MediaItem>> search(String query,
      [Map<String, dynamic>? extras]) async {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final results = <MediaItem>[];

    final lib = _library;
    if (lib != null) {
      final localMatches = lib.allSongs.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q);
      }).toList();
      results.addAll(await _songsToMediaItems(localMatches));
    }

    final ytSearch = _ytSearch;
    if (ytSearch != null) {
      try {
        final ytResults = await ytSearch.search(query, max: 10);
        for (final v in ytResults) {
          results.add(MediaItem(
            id: 'yt_${v.videoId}',
            title: v.title,
            artist: v.channel,
            album: 'YouTube',
            artUri: Uri.parse(v.thumb),
            playable: true,
          ));
        }
      } catch (_) {}
    }

    return results;
  }

  // ═══════════════════ COLA LOCAL ═══════════════════

  Future<void> publishQueue(List<LocalSong> songs, int index) async {
    final futures = songs.map((s) async {
      Uri? artUri;
      if (_library != null) {
        try {
          final bytes = await _library!.songArtworkFor(s.id, albumId: s.albumId);
          artUri = await _writeArtwork(s.id, bytes);
        } catch (_) {}
      }
      return MediaItem(
        id: s.path,
        title: s.title,
        artist: s.artist.isEmpty ? 'Artista desconocido' : s.artist,
        album: s.album,
        duration: s.duration,
        artUri: artUri,
      );
    }).toList();
    final items = await Future.wait(futures);
    super.queue.add(items);
    _emitCurrentSongFromQueue();
  }

  // ═══════════════════ COLA YOUTUBE ═══════════════════

  Future<void> publishYouTubeQueue(List<YouTubeVideo> videos, int index) async {
    final futures = videos.map((v) async {
      final artUri = await _fetchYouTubeArt(v.videoId);
      return MediaItem(
        id: 'yt_${v.videoId}',
        title: v.title,
        artist: v.channel,
        artUri: artUri,
        duration: v.duration != null ? Duration(seconds: v.duration!) : null,
      );
    }).toList();
    final items = await Future.wait(futures);
    super.queue.add(items);
    _emitCurrentSongFromQueue();
  }

  // ═══════════════════ ACTUALIZACIÓN ═══════════════════

  void _emitCurrentSongFromQueue() {
    final q = super.queue.value;
    if (q.isEmpty) return;
    final searchId = model.current?.path ??
        (model.currentYouTube != null ? 'yt_${model.currentYouTube!.videoId}' : null);
    if (searchId == null) return;
    final idx = q.indexWhere((item) => item.id == searchId);
    if (idx < 0) return;
    var item = q[idx];
    final dur = player.duration;
    if (dur != null && dur > Duration.zero) {
      item = item.copyWith(duration: dur);
    }
    mediaItem.add(item);
  }

  void onSongChanged(int index) => _emitCurrentSongFromQueue();
  void onYouTubeChanged(int index) => _emitCurrentSongFromQueue();

  // ═══════════════════ ARTWORK ═══════════════════

  Future<Directory> _getArtDir() async {
    if (_artDir != null && await _artDir!.exists()) return _artDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _artDir = Directory('${appDir.path}/notification_art');
    if (!await _artDir!.exists()) {
      await _artDir!.create(recursive: true);
    }
    return _artDir!;
  }

  Future<Uri?> _writeArtwork(int id, List<int>? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    final dir = await _getArtDir();
    final file = File('${dir.path}/art_$id.jpg');
    if (await file.exists()) return Uri.file(file.path);
    await file.writeAsBytes(bytes, flush: true);
    return Uri.file(file.path);
  }

  Future<Uri?> _fetchYouTubeArt(String videoId) async {
    final cached = File('${(await _getArtDir()).path}/yt_$videoId.jpg');
    if (await cached.exists()) return Uri.file(cached.path);
    HttpClient? client;
    try {
      final url = Uri.parse('https://img.youtube.com/vi/$videoId/mqdefault.jpg');
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(url);
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        final dir = await _getArtDir();
        final file = File('${dir.path}/yt_$videoId.jpg');
        await file.writeAsBytes(bytes, flush: true);
        return Uri.file(file.path);
      }
    } catch (_) {}
    client?.close(force: true);
    return null;
  }

  // ═══════════════════ PLAYBACK STATE ═══════════════════

  AudioServiceRepeatMode _mapRepeatMode() {
    switch (model.repeat) {
      case PlayerRepeatMode.off:
        return AudioServiceRepeatMode.none;
      case PlayerRepeatMode.all:
        return AudioServiceRepeatMode.all;
      case PlayerRepeatMode.one:
        return AudioServiceRepeatMode.one;
    }
  }

  AudioServiceShuffleMode _mapShuffleMode() {
    return model.shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
  }

  void _notifyPlaybackState({
    List<MediaControl>? controls,
    AudioProcessingState? processingState,
    bool? playing,
    Duration? updatePosition,
    Duration? bufferedPosition,
  }) {
    playbackState.add(
      (playbackState.valueOrNull ?? PlaybackState()).copyWith(
        controls: controls ?? _controls,
        processingState: processingState ?? AudioProcessingState.ready,
        playing: playing ?? player.playing,
        updatePosition: updatePosition ?? player.position,
        bufferedPosition: bufferedPosition ?? player.bufferedPosition,
        speed: player.speed,
        repeatMode: _mapRepeatMode(),
        shuffleMode: _mapShuffleMode(),
        systemActions: const { MediaAction.seek },
      ),
    );
  }

  AudioProcessingState _mapProcessing(ProcessingState p) {
    switch (p) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
      case ProcessingState.completed:
        return AudioProcessingState.ready;
    }
  }

  List<MediaControl> get _controls => [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ];

  @override
  Future<void> play() async {
    await model.togglePlay();
  }

  @override
  Future<void> pause() async {
    await model.togglePlay();
  }

  @override
  Future<void> skipToNext() async {
    await model.next();
  }

  @override
  Future<void> skipToPrevious() async {
    await model.previous();
  }

  @override
  Future<void> seek(Duration position) async {
    await player.seek(position);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        if (model.repeat != PlayerRepeatMode.off) model.cycleRepeat();
      case AudioServiceRepeatMode.all:
        while (model.repeat != PlayerRepeatMode.all) {
          model.cycleRepeat();
        }
      case AudioServiceRepeatMode.one:
        while (model.repeat != PlayerRepeatMode.one) {
          model.cycleRepeat();
        }
      default:
        break;
    }
    _notifyPlaybackState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final shouldShuffle = shuffleMode == AudioServiceShuffleMode.all;
    if (model.shuffle != shouldShuffle) {
      model.toggleShuffle();
    }
    _notifyPlaybackState();
  }

  @override
  Future<void> stop() async {
    _periodicTimer?.cancel();
    await player.stop();
    await super.stop();
  }

  void dispose() {
    _periodicTimer?.cancel();
    _eventSub?.cancel();
    _processingSub?.cancel();
  }
}
