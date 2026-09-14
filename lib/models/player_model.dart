import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../services/audio_player_handler.dart';
import '../services/youtube_audio_service.dart';
import '../services/youtube_search.dart';
import 'play_history_model.dart';
import 'song.dart';

/// Modo de repetición del reproductor.
enum PlayerRepeatMode { off, all, one }

/// Fuente de reproducción actual.
enum TrackSource { local, youtube }

/// Estado del reproductor: canción actual, lista, controles y progreso.
class PlayerModel extends ChangeNotifier {
  AudioPlayer _player;
  AudioPlayerHandler? _handler;
  final PlayHistoryModel? _playHistory;
  final YouTubeAudioService _ytAudioService = YouTubeAudioService();
  AndroidEqualizer? _equalizer;

  // ── Crossfade ──
  int _crossfadeSecs = 0;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;
  Timer? _uiUpdateTimer;
  AudioPlayer? _crossfadeNextPlayer;

  // ── Gapless ──
  ConcatenatingAudioSource? _concatSource;
  StreamSubscription? _indexSub;

  // ── Stream subscriptions (se cancelan al cambiar de player) ──
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _processSub;

  // ── Cola local ──
  List<LocalSong> _queue = [];
  int _currentIndex = -1;

  // ── Cola de YouTube ──
  List<YouTubeVideo> _ytQueue = [];
  List<YouTubeVideo> _originalYtQueue = [];
  int _ytIndex = -1;
  List<AudioSource?> _ytAudioSources = [];
  bool _isLoadingYouTube = false;
  TrackSource _source = TrackSource.local;

  PlayerRepeatMode _repeat = PlayerRepeatMode.off;
  bool _shuffle = false;
  List<int> _shuffleOrder = [];

  Duration _position = Duration.zero;

  // ── Getters públicos ──

  TrackSource get source => _source;

  LocalSong? get current {
    if (_source != TrackSource.local) return null;
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex];
  }

  YouTubeVideo? get currentYouTube {
    if (_source != TrackSource.youtube) return null;
    if (_ytIndex < 0 || _ytIndex >= _ytQueue.length) return null;
    return _ytQueue[_ytIndex];
  }

  bool get playing => _player.playing;
  bool get hasQueue => _source == TrackSource.local
      ? _queue.isNotEmpty
      : _ytQueue.isNotEmpty;
  PlayerRepeatMode get repeat => _repeat;
  bool get shuffle => _shuffle;
  Duration get position => _position;
  Duration get duration => _player.duration ?? Duration.zero;
  bool get isCrossfading => _isCrossfading;
  bool get isLoadingYouTube => _isLoadingYouTube;

  /// Índice de la siguiente canción en la cola (para resaltar en UI).
  int get nextQueueIndex {
    final len = _source == TrackSource.local ? _queue.length : _ytQueue.length;
    final cur = _source == TrackSource.local ? _currentIndex : _ytIndex;
    if (cur < 0 || cur >= len) return -1;
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      final pos = _shuffleOrder.indexOf(cur);
      final np = pos + 1;
      if (np >= _shuffleOrder.length) {
        return _repeat == PlayerRepeatMode.all ? _shuffleOrder[0] : -1;
      }
      return _shuffleOrder[np];
    }
    final ni = cur + 1;
    if (ni >= len) {
      return _repeat == PlayerRepeatMode.all ? 0 : -1;
    }
    return ni;
  }

  PlayerModel({AudioPlayer? player, this._playHistory, AndroidEqualizer? equalizer})
      : _player = player ?? AudioPlayer(),
        _equalizer = equalizer {
    _setupListeners();
  }

  AndroidEqualizer? get equalizer => _equalizer;

  void _setupListeners() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _processSub?.cancel();
    _indexSub?.cancel();
    _stateSub = _player.playerStateStream.listen((_) => notifyListeners());
    _posSub = _player.positionStream.listen((p) {
      _position = p;
      notifyListeners();
    });
    _processSub = _player.processingStateStream.listen((p) {
      if (p == ProcessingState.completed) {
        _onCompleted();
      }
    });
    _indexSub = _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (_source == TrackSource.local && idx >= 0 && idx < _queue.length) {
        final prev = _currentIndex;
        _currentIndex = idx;
        if (prev != idx && prev >= 0 && prev < _queue.length) {
          _playHistory?.recordPlay(_queue[prev].id);
        }
        _syncCurrentToHandler();
        notifyListeners();
      }
    });
  }

  void _onCompleted() {
    if (_source == TrackSource.local) {
      if (_currentIndex >= 0 && _currentIndex < _queue.length) {
        _playHistory?.recordPlay(_queue[_currentIndex].id);
      }
    } else if (_source == TrackSource.youtube) {
      next();
      return;
    }
    notifyListeners();
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeSecs = seconds.clamp(0, 12);
  }

  void setCrossfadeEnabled(bool enabled, int duration) {
    _crossfadeSecs = enabled ? duration.clamp(2, 12) : 0;
  }

  /// Vincula el handler de audio_service (se recorre en main).
  void attachHandler(AudioPlayerHandler handler) {
    _handler = handler;
  }

  void _syncToHandler() {
    if (_source == TrackSource.local) {
      _handler?.publishQueue(_queue, _currentIndex);
    } else if (_source == TrackSource.youtube) {
      _handler?.publishYouTubeQueue(_ytQueue, _ytIndex);
    }
  }

  void _syncCurrentToHandler() {
    if (_source == TrackSource.local) {
      _handler?.onSongChanged(_currentIndex);
    } else if (_source == TrackSource.youtube) {
      _handler?.onYouTubeChanged(_ytIndex);
    }
  }

  // ═══════════════════ REPRODUCCIÓN LOCAL ═══════════════════

  Future<void> playQueue(List<LocalSong> songs, int startIndex) async {
    if (_isCrossfading) _cancelCrossfade();
    _source = TrackSource.local;
    _queue = List.of(songs);
    _currentIndex = startIndex;
    _ytQueue = [];
    _ytIndex = -1;
    _syncToHandler();

    _concatSource = ConcatenatingAudioSource(
      children: songs.map((s) => AudioSource.uri(
        Uri.file(s.path),
        tag: s.id,
      )).toList(),
    );

    if (_shuffle) {
      _player.setShuffleModeEnabled(true);
    } else {
      _player.setShuffleModeEnabled(false);
    }

    switch (_repeat) {
      case PlayerRepeatMode.off:
        _player.setLoopMode(LoopMode.off);
      case PlayerRepeatMode.all:
        _player.setLoopMode(LoopMode.all);
      case PlayerRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
    }

    await _player.setAudioSource(_concatSource!, initialIndex: startIndex);
    _position = Duration.zero;
    _player.play();
  }

  /// Agrega una canción al final de la cola actual.
  void addToQueue(LocalSong song) {
    _queue.add(song);
    _concatSource?.add(AudioSource.uri(Uri.file(song.path), tag: song.id));
    _syncToHandler();
    notifyListeners();
  }

  /// Quita una canción de la cola por índice.
  void removeFromQueue(int index) {
    if (index < 0 || index >= _queue.length) return;
    if (index == _currentIndex) return;
    _queue.removeAt(index);
    _concatSource?.removeAt(index);
    if (index < _currentIndex) _currentIndex--;
    _syncToHandler();
    notifyListeners();
  }

  /// Reordena la cola: mueve la canción de oldIndex a newIndex.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex >= _queue.length) return;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    _concatSource?.move(oldIndex, newIndex);
    if (oldIndex == _currentIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex--;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex++;
    }
    _syncToHandler();
    notifyListeners();
  }

  /// Salta a una canción específica de la cola.
  void skipToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _syncCurrentToHandler();
    try {
      await _player.seek(Duration.zero, index: index);
    } catch (_) {}
    _position = Duration.zero;
    _player.play();
    notifyListeners();
  }

  /// Salta a una canción específica de la cola de YouTube.
  Future<void> skipToYtIndex(int index) async {
    if (index < 0 || index >= _ytQueue.length) return;
    _isLoadingYouTube = true;
    notifyListeners();

    _ytIndex = index;

    if (_ytAudioSources[index] == null) {
      final url = await _ytAudioService.getAudioUrl(_ytQueue[index].videoId);
      if (url != null) {
        _ytAudioSources[index] =
            AudioSource.uri(Uri.parse(url), tag: 'yt_${_ytQueue[index].videoId}');
      }
    }

    _syncCurrentToHandler();
    if (_ytAudioSources[index] != null) {
      await _loadYouTubeCurrent();
      _position = Duration.zero;
      _player.play();
    }

    _isLoadingYouTube = false;
    notifyListeners();
  }

  /// Getter de la cola local.
  List<LocalSong> get queue => List.unmodifiable(_queue);

  /// Cola local en el orden que se está reproduciendo (shuffle o original).
  List<LocalSong> get orderedQueue {
    if (!_shuffle || _shuffleOrder.isEmpty) return List.unmodifiable(_queue);
    return _shuffleOrder
        .where((i) => i >= 0 && i < _queue.length)
        .map((i) => _queue[i])
        .toList();
  }

  /// Índice actual en la cola.
  int get currentIndex => _currentIndex;

  /// Cola de YouTube actual (para UI).
  List<YouTubeVideo> get ytQueue => List.unmodifiable(_ytQueue);

  /// Cola de YouTube en el orden que se está reproduciendo.
  List<YouTubeVideo> get orderedYtQueue {
    if (!_shuffle || _shuffleOrder.isEmpty) return List.unmodifiable(_ytQueue);
    return _shuffleOrder
        .where((i) => i >= 0 && i < _ytQueue.length)
        .map((i) => _ytQueue[i])
        .toList();
  }

  /// Índice actual en la cola de YouTube.
  int get ytIndex => _ytIndex;

  // ═══════════════════ REPRODUCCIÓN YOUTUBE ═══════════════════

  Future<void> playYouTubeQueue(
    List<YouTubeVideo> videos,
    List<AudioSource?> audioSources,
    int startIndex,
  ) async {
    _source = TrackSource.youtube;
    _ytQueue = List.of(videos);
    _originalYtQueue = List.of(videos);
    _ytIndex = startIndex;
    _ytAudioSources = audioSources;
    _queue = [];
    _currentIndex = -1;
    _buildShuffleOrder();
    _syncToHandler();

    _isLoadingYouTube = true;
    notifyListeners();

    await _loadYouTubeCurrent();
    _position = Duration.zero;
    _player.play();

    _isLoadingYouTube = false;
    notifyListeners();
  }

  Future<void> _loadYouTubeCurrent() async {
    if (_ytIndex < 0 || _ytIndex >= _ytQueue.length) return;
    final source = _ytAudioSources[_ytIndex];
    if (source == null) {
      debugPrint('No hay stream de audio para: ${_ytQueue[_ytIndex].title}');
      return;
    }
    try {
      await _player.setAudioSource(source);
    } catch (e) {
      debugPrint('No pude cargar YouTube: ${_ytQueue[_ytIndex].title} — $e');
    }
    _syncCurrentToHandler();
  }



  // ═══════════════════ CONTROLES COMPARTIDOS ═══════════════════

  Future<void> togglePlay() async {
    if (!hasQueue) return;
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.currentIndex == null && hasQueue) {
        if (_source == TrackSource.local) {
          _currentIndex = 0;
        }
      }
      await _player.play();
    }
  }

  Future<void> next() async {
    if (!hasQueue) return;
    if (_isCrossfading) {
      debugPrint('[CROSSFADE] next() called while crossfading → canceling');
      _cancelCrossfade();
    }

    if (_source == TrackSource.local) {
      if (_player.hasNext) {
        await _player.seekToNext();
      } else if (_repeat == PlayerRepeatMode.all) {
        await _player.seek(Duration.zero, index: 0);
        _player.play();
      } else {
        _player.pause();
        await _player.seek(Duration.zero);
      }
    } else {
      final idx = _nextYtIndex();
      if (idx < 0) {
        if (_repeat == PlayerRepeatMode.all) {
          _ytIndex = 0;
          await _loadYouTubeCurrent();
          _position = Duration.zero;
          _player.play();
        } else {
          _player.pause();
          await _player.seek(Duration.zero);
        }
        return;
      }

      _isLoadingYouTube = true;
      notifyListeners();

      _ytIndex = idx;

      if (_ytAudioSources[idx] == null) {
        final url = await _ytAudioService.getAudioUrl(_ytQueue[idx].videoId);
        if (url != null) {
          _ytAudioSources[idx] = AudioSource.uri(Uri.parse(url), tag: 'yt_${_ytQueue[idx].videoId}');
        }
      }

      _syncCurrentToHandler();
      if (_ytAudioSources[idx] != null) {
        await _loadYouTubeCurrent();
        _position = Duration.zero;
        _player.play();
      }

      _isLoadingYouTube = false;
      notifyListeners();
    }
  }

  Future<void> previous() async {
    if (!hasQueue) return;
    if (_isCrossfading) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_source == TrackSource.local) {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
      }
    } else {
      final idx = _prevYtIndex();
      if (idx < 0) return;

      _isLoadingYouTube = true;
      notifyListeners();

      _ytIndex = idx;

      if (_ytAudioSources[idx] == null) {
        final url = await _ytAudioService.getAudioUrl(_ytQueue[idx].videoId);
        if (url != null) {
          _ytAudioSources[idx] = AudioSource.uri(Uri.parse(url), tag: 'yt_${_ytQueue[idx].videoId}');
        }
      }

      _syncCurrentToHandler();
      if (_ytAudioSources[idx] != null) {
        await _loadYouTubeCurrent();
        _position = Duration.zero;
        _player.play();
      }

      _isLoadingYouTube = false;
      notifyListeners();
    }
  }

  int _nextYtIndex() {
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      final pos = _shuffleOrder.indexOf(_ytIndex);
      final np = pos + 1;
      return np >= _shuffleOrder.length ? -1 : _shuffleOrder[np];
    }
    final ni = _ytIndex + 1;
    return ni >= _ytQueue.length ? -1 : ni;
  }

  int _prevYtIndex() {
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      final pos = _shuffleOrder.indexOf(_ytIndex);
      final pp = pos - 1;
      return pp < 0 ? -1 : _shuffleOrder[pp];
    }
    final pi = _ytIndex - 1;
    return pi < 0 ? -1 : pi;
  }

  void _buildShuffleOrder() {
    final len = _source == TrackSource.local ? _queue.length : _ytQueue.length;
    final currentIdx = _source == TrackSource.local ? _currentIndex : _ytIndex;
    _shuffleOrder = List.generate(len, (i) => i)..shuffle();
    if (currentIdx >= 0 && _shuffleOrder.isNotEmpty) {
      _shuffleOrder.remove(currentIdx);
      _shuffleOrder.insert(0, currentIdx);
    }
  }

  void toggleShuffle() {
    _shuffle = !_shuffle;
    if (_shuffle) {
      _buildShuffleOrder();
    }
    if (_source == TrackSource.youtube) {
      if (!_shuffle && _originalYtQueue.isNotEmpty) {
        final currentVideo =
            _ytIndex >= 0 && _ytIndex < _ytQueue.length ? _ytQueue[_ytIndex] : null;
        _ytQueue = List.of(_originalYtQueue);
        if (currentVideo != null) {
          _ytIndex = _ytQueue.indexOf(currentVideo);
          if (_ytIndex < 0) _ytIndex = 0;
        }
      }
    }
    _player.setShuffleModeEnabled(_shuffle);
    notifyListeners();
  }

  void cycleRepeat() {
    _repeat = PlayerRepeatMode.values[(_repeat.index + 1) % 3];
    switch (_repeat) {
      case PlayerRepeatMode.off:
        _player.setLoopMode(LoopMode.off);
      case PlayerRepeatMode.all:
        _player.setLoopMode(LoopMode.all);
      case PlayerRepeatMode.one:
        _player.setLoopMode(LoopMode.one);
    }
    notifyListeners();
  }

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> _copyEqualizerBands(AndroidEqualizer src, AndroidEqualizer dst) async {
    final oldParams = await src.parameters;
    final newParams = await dst.parameters;
    for (int i = 0; i < oldParams.bands.length && i < newParams.bands.length; i++) {
      newParams.bands[i].setGain(oldParams.bands[i].gain);
    }
    dst.setEnabled(true);
  }

  /// Crossfade optimizado: crea un segundo reproductor temporal, mezcla volumen
  /// entre ambos, y al terminar intercambia el reproductor principal.
  Future<void> _crossfadeTo(LocalSong nextSong) async {
    debugPrint('[CROSSFADE] _crossfadeTo START: "${nextSong.title}"');
    if (_isCrossfading) _cancelCrossfade();

    _isCrossfading = true;
    notifyListeners();

    AndroidEqualizer? newEqualizer;
    if (_equalizer != null) {
      newEqualizer = AndroidEqualizer();
      try {
        await _copyEqualizerBands(_equalizer!, newEqualizer)
            .timeout(const Duration(seconds: 2));
        debugPrint('[CROSSFADE] EQ copy OK');
      } catch (e) {
        debugPrint('[CROSSFADE] EQ copy failed, using fresh EQ: $e');
      }
    }

    final nextPlayer = newEqualizer != null
        ? AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [newEqualizer]))
        : AudioPlayer();
    _crossfadeNextPlayer = nextPlayer;
    try {
      debugPrint('[CROSSFADE] Loading next song...');
      await nextPlayer.setUrl(nextSong.path);
      debugPrint('[CROSSFADE] Next song loaded. Starting muted playback...');
      nextPlayer.setVolume(0.0);
      nextPlayer.play();

      final durationMs = _crossfadeSecs * 1000;
      final steps = 20;
      final stepMs = (durationMs / steps).toInt();
      debugPrint('[CROSSFADE] Ramp: ${_crossfadeSecs}s, $steps steps, ${stepMs}ms each');
      final completer = Completer<void>();

      _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        notifyListeners();
      });

      _crossfadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
        if (_crossfadeNextPlayer == null) { timer.cancel(); return; }
        final t = timer.tick / steps;
        debugPrint('[CROSSFADE] Ramp tick ${timer.tick}/$steps (t=${t.toStringAsFixed(2)})');
        if (t >= 1.0) {
          timer.cancel();
          _crossfadeTimer = null;
          try { nextPlayer.setVolume(1.0); } catch (_) {}
          completer.complete();
          return;
        }
        final eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
        try { _player.setVolume((1.0 - eased).clamp(0.0, 1.0)); } catch (_) {}
        try { nextPlayer.setVolume(eased.clamp(0.0, 1.0)); } catch (_) {}
      });

      await completer.future;
      debugPrint('[CROSSFADE] Ramp complete. Swapping players...');

      try {
        await _player.pause().timeout(const Duration(milliseconds: 500));
      } catch (_) {}
      try {
        await _player.stop().timeout(const Duration(milliseconds: 500));
      } catch (_) {}
      _player.dispose();

      _player = nextPlayer;
      if (newEqualizer != null) {
        _equalizer = newEqualizer;
      }
      _position = nextPlayer.position;
      _setupListeners();
      _handler?.rebindPlayer(nextPlayer);
      _syncCurrentToHandler();
      debugPrint('[CROSSFADE] Swap complete. Now playing: "${nextSong.title}"');
      notifyListeners();

      _uiUpdateTimer?.cancel();
      int postSwapTicks = 0;
      _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _position = _player.position;
        notifyListeners();
        postSwapTicks++;
        if (postSwapTicks >= 6) {
          _uiUpdateTimer?.cancel();
          _uiUpdateTimer = null;
        }
      });
    } catch (e) {
      debugPrint('[CROSSFADE] ERROR: $e');
      nextPlayer.dispose();
    } finally {
      _crossfadeNextPlayer = null;
      _crossfadeTimer = null;
      _isCrossfading = false;
      notifyListeners();
    }
  }

  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = null;
    try { _crossfadeNextPlayer?.dispose(); } catch (_) {}
    _crossfadeNextPlayer = null;
    _isCrossfading = false;
    try { _player.setVolume(1.0); } catch (_) {}
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _processSub?.cancel();
    _indexSub?.cancel();
    _crossfadeTimer?.cancel();
    _uiUpdateTimer?.cancel();
    _cancelCrossfade();
    _ytAudioService.dispose();
    _player.dispose();
    super.dispose();
  }
}
