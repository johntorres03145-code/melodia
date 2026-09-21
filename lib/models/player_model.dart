import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../services/audio_player_handler.dart';
import '../services/youtube_audio_service.dart';
import '../services/youtube_search.dart';
import '../services/yt_url_cache.dart';
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
  final YtUrlCache _ytUrlCache = YtUrlCache();
  AndroidEqualizer? _equalizer;
  AndroidLoudnessEnhancer? _loudnessEnhancer;
  bool _soundEnhancement = false;

  // ── Crossfade ──
  int _crossfadeSecs = 0;
  bool _crossfadeEnabled = false;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;
  AudioPlayer? _crossfadeNextPlayer;
  bool _crossfadeTriggeredForSong = false;
  Duration _crossfadeNextDuration = Duration.zero;

  // ── Protección de transición ──
  bool _isSettingSource = false;

  // ── Gapless ──
  ConcatenatingAudioSource? _concatSource;
  StreamSubscription? _indexSub;

  // ── Stream subscriptions (se cancelan al cambiar de player) ──
  StreamSubscription? _stateSub;
  StreamSubscription? _posSub;
  StreamSubscription? _processSub;

  // ── Cola local ──
  List<LocalSong> _queue = [];
  List<LocalSong> _originalQueue = [];
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

  // ── Velocidad de reproducción ──
  double _speed = 1.0;
  static const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

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
  Duration get duration {
    if (_isCrossfading && _crossfadeNextDuration > Duration.zero) {
      return _crossfadeNextDuration;
    }
    return _player.duration ?? Duration.zero;
  }
  bool get isCrossfading => _isCrossfading;
  bool get crossfadeEnabled => _crossfadeEnabled;
  bool get isLoadingYouTube => _isLoadingYouTube;
  double get speed => _speed;
  List<double> get speedOptions => _speedOptions;

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

  /// Índice de la canción anterior en la cola (respeta shuffle).
  int get prevQueueIndex {
    final cur = _source == TrackSource.local ? _currentIndex : _ytIndex;
    if (cur < 0) return -1;
    if (_shuffle && _shuffleOrder.isNotEmpty) {
      final pos = _shuffleOrder.indexOf(cur);
      if (pos <= 0) return -1;
      return _shuffleOrder[pos - 1];
    }
    return cur - 1;
  }

  PlayerModel({
    AudioPlayer? player,
    this._playHistory,
    AndroidEqualizer? equalizer,
    AndroidLoudnessEnhancer? loudnessEnhancer,
  })  : _player = player ?? AudioPlayer(useProxyForRequestHeaders: false),
        _equalizer = equalizer,
        _loudnessEnhancer = loudnessEnhancer {
    _setupListeners();
    _ytUrlCache.init();
  }

  AndroidEqualizer? get equalizer => _equalizer;
  AndroidLoudnessEnhancer? get loudnessEnhancer => _loudnessEnhancer;
  bool get soundEnhancement => _soundEnhancement;

  void setSoundEnhancement(bool enabled) {
    _soundEnhancement = enabled;
    _loudnessEnhancer?.setEnabled(enabled);
    if (enabled) {
      _loudnessEnhancer?.setTargetGain(3.0);
    }
    notifyListeners();
  }

  void _setupListeners() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _processSub?.cancel();
    _indexSub?.cancel();
    _stateSub = _player.playerStateStream.listen((_) => notifyListeners());
    _posSub = _player.positionStream.listen((p) {
      // Durante crossfade: NO sobreescribir _position (lo controla nextPosSub)
      if (_isCrossfading) return;
      _position = p;
      // Crossfade: detectar cuando faltan _crossfadeSecs para el final
      if (_crossfadeEnabled && !_crossfadeTriggeredForSong) {
        final dur = _player.duration;
        if (dur != null && dur > Duration.zero && _source == TrackSource.local) {
          final remaining = dur - p;
          if (remaining <= Duration(seconds: _crossfadeSecs) && remaining > Duration.zero) {
            final nextIdx = nextQueueIndex;
            if (nextIdx >= 0 && nextIdx < _queue.length) {
              _crossfadeTriggeredForSong = true;
              _crossfadeTo(_queue[nextIdx]);
            }
          }
        }
      }
      notifyListeners();
    });
    _processSub = _player.processingStateStream.listen((p) {
      if (p == ProcessingState.completed) {
        _onCompleted();
      }
    });
    _indexSub = _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (_isCrossfading) return;
      if (_isSettingSource) {
        // Primer evento del nuevo player post-crossfade: resetear flag
        _isSettingSource = false;
        return;
      }
      if (_source == TrackSource.local && idx >= 0 && idx < _queue.length) {
        final prev = _currentIndex;
        _currentIndex = idx;
        _crossfadeTriggeredForSong = false;
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
      // Crossfade fallback: si el position stream no lo detectó (canción muy corta)
      if (_crossfadeEnabled && !_isCrossfading) {
        final nextIdx = nextQueueIndex;
        if (nextIdx >= 0 && nextIdx < _queue.length) {
          _crossfadeTriggeredForSong = true;
          _crossfadeTo(_queue[nextIdx]);
          return;
        }
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

  /// Cicla entre las velocidades de reproducción disponibles.
  void cycleSpeed() {
    final idx = _speedOptions.indexOf(_speed);
    final nextIdx = (idx + 1) % _speedOptions.length;
    setSpeed(_speedOptions[nextIdx]);
  }

  /// Establece una velocidad de reproducción específica.
  void setSpeed(double s) {
    _speed = s;
    _player.setSpeed(s);
    notifyListeners();
  }

  void setCrossfadeEnabled(bool enabled, int duration) {
    _crossfadeEnabled = enabled;
    _crossfadeSecs = enabled ? duration.clamp(2, 12) : 0;
  }

  /// Vincula el handler de audio_service (se recorre en main).
  void attachHandler(AudioPlayerHandler handler) {
    _handler = handler;
  }

  void _syncToHandler() {
    if (_source == TrackSource.local) {
      _handler?.publishQueue(orderedQueue, _currentIndex);
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
    _isSettingSource = true;
    _source = TrackSource.local;
    _queue = List.of(songs);
    _originalQueue = List.of(songs);
    _currentIndex = startIndex;
    _ytQueue = [];
    _ytIndex = -1;
    _crossfadeTriggeredForSong = false;

    // Construir shuffle order si está activo
    if (_shuffle) {
      _buildShuffleOrder();
    } else {
      _shuffleOrder = [];
    }

    _syncToHandler();

    if (_crossfadeEnabled) {
      // Crossfade: cargar solo la canción actual (control manual del timing)
      await _player.setUrl(songs[startIndex].path);
      _position = Duration.zero;
      _player.play();
    } else {
      // Normal: ConcatenatingAudioSource para gapless
      _concatSource = ConcatenatingAudioSource(
        children: songs.map((s) => AudioSource.uri(
          Uri.file(s.path),
          tag: s.id,
        )).toList(),
      );

      // NO usamos setShuffleModeEnabled: el shuffle se maneja
      // 100% con _shuffleOrder + nextQueueIndex/prevQueueIndex + seek()

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
    _isSettingSource = false;
  }

  /// Agrega una canción al final de la cola actual.
  void addToQueue(LocalSong song) {
    _queue.add(song);
    _concatSource?.add(AudioSource.uri(Uri.file(song.path), tag: song.id));
    _syncToHandler();
    notifyListeners();
  }

  /// Inserta una canción justo después de la actual en la cola.
  void playNext(LocalSong song) {
    final insertAt = _currentIndex + 1;
    _queue.insert(insertAt, song);
    if (_concatSource != null) {
      _concatSource!.insert(insertAt, AudioSource.uri(Uri.file(song.path), tag: song.id));
    }
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
    if (_isCrossfading) _cancelCrossfade();
    _isSettingSource = true;
    _currentIndex = index;
    _crossfadeTriggeredForSong = false;
    _syncCurrentToHandler();
    if (_crossfadeEnabled) {
      await _player.setUrl(_queue[index].path);
      _position = Duration.zero;
      _player.play();
    } else {
      try {
        await _player.seek(Duration.zero, index: index);
      } catch (_) {}
      _position = Duration.zero;
      _player.play();
    }
    _isSettingSource = false;
    notifyListeners();
  }

  /// Salta a una canción específica de la cola de YouTube.
  Future<void> skipToYtIndex(int index) async {
    if (index < 0 || index >= _ytQueue.length) return;
    _isLoadingYouTube = true;
    notifyListeners();

    _ytIndex = index;
    await _resolveYtSource(index);

    _syncCurrentToHandler();
    if (_ytAudioSources[index] != null) {
      await _loadYouTubeCurrent();
      _position = Duration.zero;
      _player.play();
    }

    _isLoadingYouTube = false;
    notifyListeners();
    _prefetchNextYouTube();
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
    if (_shuffle) {
      _buildShuffleOrder();
    } else {
      _shuffleOrder = [];
    }
    _syncToHandler();

    _isLoadingYouTube = true;
    notifyListeners();

    await _resolveYtSource(startIndex);
    await _loadYouTubeCurrent();
    _position = Duration.zero;
    _player.play();

    _isLoadingYouTube = false;
    notifyListeners();

    _prefetchNextYouTube();
  }

  Future<void> _loadYouTubeCurrent() async {
    if (_ytIndex < 0 || _ytIndex >= _ytQueue.length) return;
    final source = _ytAudioSources[_ytIndex];
    if (source == null) {
      debugPrint('No hay stream de audio para: ${_ytQueue[_ytIndex].title}');
      _skipFailedYouTube();
      return;
    }
    try {
      await _player.setAudioSource(source).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('No pude cargar YouTube: ${_ytQueue[_ytIndex].title} — $e');
      _ytAudioSources[_ytIndex] = null;
      _skipFailedYouTube();
      return;
    }
    _syncCurrentToHandler();
  }

  void _skipFailedYouTube() {
    final idx = _nextYtIndex();
    if (idx >= 0) {
      debugPrint('Saltando canción fallida → siguiente ($idx)');
      Future.microtask(() => next());
    } else if (_repeat == PlayerRepeatMode.all) {
      debugPrint('Repetición total, reiniciando cola');
      Future.microtask(() {
        _ytIndex = 0;
        _loadYouTubeCurrent().then((_) => _player.play());
      });
    } else {
      debugPrint('No hay más canciones, manteniendo servicio activo');
      _position = Duration.zero;
      notifyListeners();
    }
  }



  // ═══════════════════ CONTROLES COMPARTIDOS ═══════════════════

  Future<void> togglePlay() async {
    if (!hasQueue) return;
    HapticFeedback.mediumImpact();
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
    HapticFeedback.lightImpact();
    if (_isCrossfading) {
      debugPrint('[CROSSFADE] next() called while crossfading → canceling');
      _cancelCrossfade();
    }

    if (_source == TrackSource.local) {
      if (_crossfadeEnabled) {
        // Crossfade mode: skip manual sin ConcatenatingAudioSource
        final idx = nextQueueIndex;
        if (idx >= 0 && idx < _queue.length) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _isSettingSource = true;
          _currentIndex = idx;
          _crossfadeTriggeredForSong = false;
          await _player.setUrl(_queue[idx].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _isSettingSource = false;
        } else if (_repeat == PlayerRepeatMode.all && _queue.isNotEmpty) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _isSettingSource = true;
          _currentIndex = 0;
          _crossfadeTriggeredForSong = false;
          await _player.setUrl(_queue[0].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _isSettingSource = false;
        }
        notifyListeners();
      } else {
        // Modo normal (sin crossfade): usar nextQueueIndex + seek() para respetar shuffle
        final idx = nextQueueIndex;
        if (idx >= 0 && idx < _queue.length) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _currentIndex = idx;
          await _player.seek(Duration.zero, index: idx);
          _syncCurrentToHandler();
          notifyListeners();
        } else if (_repeat == PlayerRepeatMode.all && _queue.isNotEmpty) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _currentIndex = 0;
          await _player.seek(Duration.zero, index: 0);
          _syncCurrentToHandler();
          notifyListeners();
        }
      }
    } else {
      final idx = _nextYtIndex();
      if (idx < 0) {
        if (_repeat == PlayerRepeatMode.all) {
          _ytIndex = 0;
          await _resolveYtSource(0);
          await _loadYouTubeCurrent();
          _position = Duration.zero;
          _player.play();
        } else {
          await _player.seek(Duration.zero);
          _position = Duration.zero;
          notifyListeners();
        }
        return;
      }

      _isLoadingYouTube = true;
      notifyListeners();

      _ytIndex = idx;
      await _resolveYtSource(idx);

      _syncCurrentToHandler();
      if (_ytAudioSources[idx] != null) {
        await _loadYouTubeCurrent();
        _position = Duration.zero;
        _player.play();
      }

      _isLoadingYouTube = false;
      notifyListeners();
      _prefetchNextYouTube();
    }
  }

  Future<void> previous() async {
    if (!hasQueue) return;
    HapticFeedback.lightImpact();
    if (_isCrossfading) {
      _cancelCrossfade();
    }
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      return;
    }

    if (_source == TrackSource.local) {
      if (_crossfadeEnabled) {
        // Crossfade mode: ir a la anterior manualmente (respeta shuffle)
        final prevIdx = prevQueueIndex;
        if (prevIdx >= 0 && prevIdx < _queue.length) {
          _isSettingSource = true;
          _currentIndex = prevIdx;
          _crossfadeTriggeredForSong = false;
          await _player.setUrl(_queue[prevIdx].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _isSettingSource = false;
          notifyListeners();
        }
      } else {
        // Modo normal (sin crossfade): usar prevQueueIndex + seek() para respetar shuffle
        final prevIdx = prevQueueIndex;
        if (prevIdx >= 0 && prevIdx < _queue.length) {
          _currentIndex = prevIdx;
          await _player.seek(Duration.zero, index: prevIdx);
          _syncCurrentToHandler();
          notifyListeners();
        }
      }
    } else {
      final idx = _prevYtIndex();
      if (idx < 0) return;

      _isLoadingYouTube = true;
      notifyListeners();

      _ytIndex = idx;
      await _resolveYtSource(idx);

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

  Future<void> _resolveYtSource(int index) async {
    if (index < 0 || index >= _ytQueue.length) return;
    if (_ytAudioSources[index] != null) return;

    final videoId = _ytQueue[index].videoId;

    final cached = _ytUrlCache.get(videoId);
    if (cached != null) {
      _ytAudioSources[index] =
          AudioSource.uri(Uri.parse(cached), tag: 'yt_$videoId');
      debugPrint('YtPrefetch: cache HIT para $videoId');
      return;
    }

    final url = await _ytAudioService.getAudioUrl(videoId);
    if (url != null) {
      _ytAudioSources[index] =
          AudioSource.uri(Uri.parse(url), tag: 'yt_$videoId');
      _ytUrlCache.put(videoId, url);
    }
  }

  void _prefetchNextYouTube() {
    if (_source != TrackSource.youtube) return;
    for (int offset = 1; offset <= 2; offset++) {
      final idx = _ytIndex + offset;
      if (idx >= 0 && idx < _ytQueue.length && _ytAudioSources[idx] == null) {
        final vid = _ytQueue[idx].videoId;
        final cached = _ytUrlCache.get(vid);
        if (cached != null) {
          _ytAudioSources[idx] =
              AudioSource.uri(Uri.parse(cached), tag: 'yt_$vid');
          continue;
        }
        _resolveYtSource(idx).catchError((_) {});
      }
    }
  }

  void toggleShuffle() async {
    _shuffle = !_shuffle;
    if (_shuffle) {
      _buildShuffleOrder();
    } else {
      _shuffleOrder = [];
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
    } else if (_source == TrackSource.local) {
      if (!_shuffle && _originalQueue.isNotEmpty) {
        final currentSong =
            _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
        _queue = List.of(_originalQueue);
        if (currentSong != null) {
          _currentIndex = _queue.indexOf(currentSong);
          if (_currentIndex < 0) _currentIndex = 0;
        }
      }
    }
    // NO usamos setShuffleModeEnabled: el shuffle se maneja
    // 100% con _shuffleOrder + nextQueueIndex/prevQueueIndex + seek()
    _syncToHandler();
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

  /// Crossfade estilo Lark Player: cambia UI inmediatamente, audio se mezcla gradualmente.
  Future<void> _crossfadeTo(LocalSong nextSong) async {
    debugPrint('[CROSSFADE] _crossfadeTo START: "${nextSong.title}"');
    if (_isCrossfading) _cancelCrossfade();

    _isCrossfading = true;

    // Calcular índice de la siguiente canción
    final nextIdx = _queue.indexWhere((s) => s.id == nextSong.id);
    if (nextIdx < 0) {
      debugPrint('[CROSSFADE] nextSong not found in queue, aborting');
      _isCrossfading = false;
      return;
    }

    // Cambiar UI INMEDIATAMENTE: artwork, nombre, barra de progreso
    _currentIndex = nextIdx;
    _position = Duration.zero;
    _syncCurrentToHandler();
    notifyListeners();

    // Clonar ecualizador (fire-and-forget con timeout corto)
    AndroidEqualizer? newEqualizer;
    if (_equalizer != null) {
      newEqualizer = AndroidEqualizer();
      try {
        await _copyEqualizerBands(_equalizer!, newEqualizer)
            .timeout(const Duration(seconds: 1));
        debugPrint('[CROSSFADE] EQ copy OK');
      } catch (e) {
        debugPrint('[CROSSFADE] EQ copy failed: $e');
        newEqualizer = null;
      }
    }

    final nextPlayer = newEqualizer != null
        ? AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [newEqualizer]), useProxyForRequestHeaders: false)
        : AudioPlayer(useProxyForRequestHeaders: false);
    _crossfadeNextPlayer = nextPlayer;
    try {
      await nextPlayer.setUrl(nextSong.path);
      _crossfadeNextDuration = nextPlayer.duration ?? Duration.zero;
      nextPlayer.setVolume(0.0);
      nextPlayer.play();

      // Escuchar posición del nuevo player para la barra de progreso
      StreamSubscription? nextPosSub;
      nextPosSub = nextPlayer.positionStream.listen((p) {
        if (_isCrossfading) _position = p;
      });

      final durationMs = _crossfadeSecs * 1000;
      final steps = 20;
      final stepMs = (durationMs / steps).toInt();
      debugPrint('[CROSSFADE] Ramp: ${_crossfadeSecs}s, $steps steps, ${stepMs}ms each');

      // Ramp: viejo baja volumen, nuevo sube
      _crossfadeTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
        if (_crossfadeNextPlayer == null) { timer.cancel(); return; }
        final t = timer.tick / steps;

        if (t >= 1.0) {
          timer.cancel();
          _crossfadeTimer = null;
          nextPosSub?.cancel();
          try { nextPlayer.setVolume(1.0); } catch (_) {}
          _swapCrossfadePlayer(nextPlayer, newEqualizer, nextSong);
          return;
        }

        final eased = t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
        try { _player.setVolume((1.0 - eased).clamp(0.0, 1.0)); } catch (_) {}
        try { nextPlayer.setVolume(eased.clamp(0.0, 1.0)); } catch (_) {}
      });
    } catch (e) {
      debugPrint('[CROSSFADE] ERROR: $e');
      nextPlayer.dispose();
      _crossfadeNextPlayer = null;
      _crossfadeNextDuration = Duration.zero;
      _isCrossfading = false;
      _syncCurrentToHandler();
      notifyListeners();
    }
  }

  /// Intercambia el player viejo por el nuevo después del ramp de crossfade.
  void _swapCrossfadePlayer(AudioPlayer nextPlayer, AndroidEqualizer? newEqualizer, LocalSong nextSong) {
    debugPrint('[CROSSFADE] Swapping players → "${nextSong.title}"');
    _crossfadeNextPlayer = null;
    _crossfadeNextDuration = Duration.zero;

    // Dispose fire-and-forget del player viejo
    try { _player.setVolume(1.0); } catch (_) {}
    _player.dispose();

    _player = nextPlayer;
    if (newEqualizer != null) {
      _equalizer = newEqualizer;
    }

    _position = nextPlayer.position;
    _setupListeners();
    _handler?.rebindPlayer(nextPlayer);
    _syncCurrentToHandler();
    _isCrossfading = false;
    _isSettingSource = false;
    debugPrint('[CROSSFADE] Swap complete. Playing: "${nextSong.title}" (index=$_currentIndex)');
    notifyListeners();
  }

  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    try { _crossfadeNextPlayer?.dispose(); } catch (_) {}
    _crossfadeNextPlayer = null;
    _crossfadeNextDuration = Duration.zero;
    _isCrossfading = false;
    _crossfadeTriggeredForSong = false;
    _isSettingSource = false;
    try { _player.setVolume(1.0); } catch (_) {}
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _processSub?.cancel();
    _indexSub?.cancel();
    _crossfadeTimer?.cancel();
    _cancelCrossfade();
    _ytAudioService.dispose();
    _ytUrlCache.close();
    _handler?.dispose();
    _player.dispose();
    super.dispose();
  }
}
