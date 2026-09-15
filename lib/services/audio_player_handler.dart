import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../models/library_model.dart';
import '../models/player_model.dart';
import '../models/song.dart';
import 'youtube_search.dart';

/// Conecta el reproductor con audio_service (fondo + notificación).
///
/// Comparte el mismo [AudioPlayer] que usa el [PlayerModel] de la UI.
class AudioPlayerHandler extends BaseAudioHandler {
  AudioPlayer player;
  final PlayerModel model;
  LibraryModel? _library;
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

  /// Refresco periódico cada 1s: mantiene la barra de progreso activa
  /// incluso si el stream principal pierde eventos.
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

  void attachLibrary(LibraryModel library) {
    _library = library;
  }

  /// Directorio estable para imágenes de notificación (no se limpia por el SO).
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
    await file.writeAsBytes(bytes, flush: true);
    return Uri.file(file.path);
  }

  /// Descarga la miniatura de YouTube y la guarda localmente.
  Future<Uri?> _fetchYouTubeArt(String videoId) async {
    try {
      final url = Uri.parse(
        'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
      );
      final client = HttpClient();
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
    return null;
  }

  // ═══════════════════ COLA LOCAL ═══════════════════

  Future<void> publishQueue(List<LocalSong> songs, int index) async {
    final items = <MediaItem>[];
    for (final s in songs) {
      Uri? artUri;
      if (_library != null) {
        final bytes = await _library!.songArtworkFor(s.id, albumId: s.albumId);
        artUri = await _writeArtwork(s.id, bytes);
      }
      items.add(MediaItem(
        id: s.path,
        title: s.title,
        artist: s.artist.isEmpty ? 'Artista desconocido' : s.artist,
        album: s.album,
        duration: s.duration,
        artUri: artUri,
      ));
    }
    super.queue.add(items);
    _updateMediaItem(index);
  }

  // ═══════════════════ COLA YOUTUBE ═══════════════════

  Future<void> publishYouTubeQueue(List<YouTubeVideo> videos, int index) async {
    final items = <MediaItem>[];
    for (final v in videos) {
      final artUri = await _fetchYouTubeArt(v.videoId);
      items.add(MediaItem(
        id: 'yt_${v.videoId}',
        title: v.title,
        artist: v.channel,
        artUri: artUri,
      ));
    }
    super.queue.add(items);
    _updateMediaItem(index);
  }

  // ═══════════════════ ACTUALIZACIÓN ═══════════════════

  void _updateMediaItem(int index) {
    final q = super.queue.value;
    if (q.isNotEmpty && index >= 0 && index < q.length) {
      mediaItem.add(q[index]);
    }
  }

  void onSongChanged(int index) => _updateMediaItem(index);

  void onYouTubeChanged(int index) => _updateMediaItem(index);

  // ═══════════════════ PLAYBACK STATE ═══════════════════

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
        if (player.playing)
          MediaControl.pause
        else
          MediaControl.play,
        MediaControl.skipToNext,
      ];

  @override
  Future<void> play() async {
    await model.togglePlay();
  }

  @override
  Future<void> pause() async {
    if (player.playing) await player.pause();
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
