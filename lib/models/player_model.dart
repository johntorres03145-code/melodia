import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../services/audio_player_handler.dart';
import '../services/youtube_audio_service.dart';
import '../services/youtube_search.dart';
import '../services/yt_url_cache.dart';
import 'library_model.dart';
import 'play_history_model.dart';
import 'song.dart';

/// Modo de repetición del reproductor.
enum PlayerRepeatMode { off, all, one }

/// Modo de shuffle del reproductor.
enum ShuffleMode { off, normal, smart }

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

  // ── Dynamic color extraction ──
  ThemeProvider? _themeProvider;
  LibraryModel? _library;
  int _colorExtractionGeneration = 0;
  int _lastExtractedGeneration = -1;

  // ── Crossfade (dual-player real) ──
  int _crossfadeSecs = 0;
  bool _crossfadeEnabled = false;
  bool _isCrossfading = false;
  Timer? _crossfadeTimer;
  bool _crossfadeTriggeredForSong = false;
  int _crossfadePrevIndex = -1;
  AudioPlayer? _crossfadeNextPlayer;
  double _userVolume = 1.0;
  double _crossfadeProgress = 0.0;
  int _crossfadeTotalSteps = 0;
  // ignore: unused_field
  String _crossfadeState = 'idle'; // idle | preparing | fading | completed

  // ── Watchdog (deshabilitado — causa loops con crossfade) ──

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
  ShuffleMode _shuffleMode = ShuffleMode.off;
  List<int> _shuffleOrder = [];
  List<int> _playedHistory = []; // Para smart shuffle: orden de reproducción reciente

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
  bool get shuffle => _shuffleMode != ShuffleMode.off;
  ShuffleMode get shuffleMode => _shuffleMode;
  Duration get position => _position;
  Duration get duration {
    if (_isCrossfading && _crossfadeNextPlayer != null) {
      return _crossfadeNextPlayer!.duration ?? Duration.zero;
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
    if (_shuffleMode != ShuffleMode.off && _shuffleOrder.isNotEmpty) {
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
    if (_shuffleMode != ShuffleMode.off && _shuffleOrder.isNotEmpty) {
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
    _stateSub = _player.playerStateStream.listen((_) {
      notifyListeners();
    });
    _posSub = _player.positionStream.listen((p) {
      if (_isCrossfading) {
        // Durante crossfade la posición es la del next player, y sí notificar para que progress/miniplayer no se trabe
        if (_crossfadeNextPlayer != null) {
          try { _position = _crossfadeNextPlayer!.position; } catch (_) { _position = p; }
        } else {
          _position = p;
        }
        notifyListeners();
        return;
      }
      _position = p;
      _checkCrossfadeTrigger();
      notifyListeners();
    });
    _processSub = _player.processingStateStream.listen((p) {
      if (_isCrossfading || _isSettingSource || _isLoadingYouTube || _ytSkipInProgress) return;
      if (p == ProcessingState.completed) {
        _onCompleted();
      }
    });
    _indexSub = _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (_isSettingSource) {
        _isSettingSource = false;
        return;
      }
      if (_source == TrackSource.local && idx >= 0 && idx < _queue.length) {
        final prev = _currentIndex;
        _currentIndex = idx;
        if (prev != idx && prev >= 0 && prev < _queue.length) {
          _playHistory?.recordPlay(_queue[prev].id);
          _recordPlayedForShuffle(idx);
        }
        _syncCurrentToHandler();
        _triggerColorExtraction();
        notifyListeners();
      }
    });
  }

  void _onCompleted() {
    if (_isCrossfading || _isSettingSource || _isLoadingYouTube || _ytSkipInProgress) return;
    if (_source == TrackSource.local) {
      if (_crossfadeTriggeredForSong) return;
      if (_currentIndex >= 0 && _currentIndex < _queue.length) {
        _playHistory?.recordPlay(_queue[_currentIndex].id);
      }
      next();
      return;
    } else if (_source == TrackSource.youtube) {
      next();
      return;
    }
    notifyListeners();
  }

  void setCrossfadeDuration(int seconds) {
    _crossfadeSecs = seconds.clamp(0, 12);
    notifyListeners();
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
    notifyListeners();
  }

  /// Vincula el handler de audio_service (se recorre en main).
  void attachHandler(AudioPlayerHandler handler) {
    _handler = handler;
  }

  /// Connects ThemeProvider for dynamic color extraction from artwork.
  void attachTheme(ThemeProvider theme) => _themeProvider = theme;

  /// Connects LibraryModel for fetching song artwork bytes.
  void attachLibrary(LibraryModel library) => _library = library;

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

  // ═══════════════════ EXTRACCIÓN DE COLORES ═══════════════════

  /// Extrae colores de la portada de la canción actual.
  /// Se llama automáticamente cuando cambia la canción.
  void _extractColorsForCurrentSong() {
    final theme = _themeProvider;
    if (theme == null || !theme.autoColorEnabled) return;
    final lib = _library;
    if (lib == null) return;

    final song = current;
    final ytVideo = currentYouTube;
    final generation = _colorExtractionGeneration;

    if (song != null) {
      lib.songArtworkFor(song.id, albumId: song.albumId).then((bytes) {
        if (bytes == null) return;
        _applyPaletteFromBytes(bytes, generation);
      }).catchError((_) {});
    } else if (ytVideo != null && ytVideo.thumb.isNotEmpty) {
      _downloadThumbForColor(ytVideo.thumb).then((bytes) {
        if (bytes.isEmpty) return;
        _applyPaletteFromBytes(bytes, generation);
      }).catchError((_) {});
    }
  }

  void _applyPaletteFromBytes(Uint8List bytes, int generation) {
    PaletteGenerator.fromImageProvider(
      MemoryImage(bytes),
      maximumColorCount: 8,
    ).then((palette) {
      if (generation != _colorExtractionGeneration) return;
      final theme = _themeProvider;
      if (theme == null) return;
      final dominant = palette.dominantColor?.color ?? MelodiaColors.midnight;
      final vibrant = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          MelodiaColors.violetLight;
      theme.setAutoColorFromArtwork(dominant, vibrant);
    }).catchError((_) {});
  }

  Future<Uint8List> _downloadThumbForColor(String url) async {
    HttpClient? client;
    try {
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final bytes = await response.fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        return Uint8List.fromList(bytes);
      }
    } catch (_) {}
    finally { client?.close(force: true); }
    return Uint8List(0);
  }

  /// Dispara la extracción de colores si la canción cambió.
  void _triggerColorExtraction() {
    _colorExtractionGeneration++;
    _extractColorsForCurrentSong();
  }

  // ═══════════════════ CROSSFADE (DUAL PLAYER) ═══════════════════

  /// Verifica si es momento de iniciar el crossfade — DESHABILITADO temporalmente.
  void _checkCrossfadeTrigger() {
    return;
    if (!_crossfadeEnabled || _crossfadeSecs <= 0 || _isCrossfading) return;
    if (_crossfadeTriggeredForSong) return;
    if (_repeat == PlayerRepeatMode.one) return;
    if (_source != TrackSource.local) return;

    Duration? duration = _player.duration;
    if (duration == null || duration <= Duration.zero) {
      if (_currentIndex >= 0 && _currentIndex < _queue.length) {
        duration = _queue[_currentIndex].duration;
      }
    }
    if (duration == null || duration <= Duration.zero) return;

    // Canciones cortas: ajustar duración efectiva
    final effectiveSecs = _effectiveCrossfadeSecs(duration);
    if (effectiveSecs <= 0) return;

    final remaining = duration - _position;
    if (remaining.inSeconds <= effectiveSecs + 2 && remaining.inSeconds >= 0) {
      // ignore: avoid_print
      print('[CROSSFADE] check: pos=${_position.inSeconds}s dur=${duration.inSeconds}s rem=${remaining.inSeconds}s eff=$effectiveSecs trig=$_crossfadeTriggeredForSong');
    }
    if (remaining <= Duration(seconds: effectiveSecs)) {
      final nextIdx = nextQueueIndex;
      if (nextIdx >= 0 && nextIdx < _queue.length) {
        // ignore: avoid_print
        print('[CROSSFADE] TRIGGER → idx $nextIdx "${_queue[nextIdx].title}" rem=${remaining.inSeconds}s eff=$effectiveSecs');
        _crossfadeTo(_queue[nextIdx], effectiveSecs: effectiveSecs);
      }
    }
  }

  int _effectiveCrossfadeSecs(Duration duration) {
    if (_crossfadeSecs <= 0) return 0;
    // Si duración desconocida o muy corta, no hacer crossfade más largo que la mitad
    final half = (duration.inMilliseconds / 2).floor() ~/ 1000;
    if (duration.inSeconds < _crossfadeSecs * 2 && duration.inSeconds < 10) {
      // Canción <10s: máx 1s o desactivar si <3s
      if (duration.inSeconds < 3) return 0;
      return half.clamp(1, _crossfadeSecs);
    }
    return _crossfadeSecs.clamp(0, half > 0 ? half : _crossfadeSecs);
  }

  /// Helper: timeout para operaciones async que podrían colgar.
  Future<T?> _withTimeout<T>(Future<T> future, Duration timeout) async {
    try {
      return await future.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  /// Crossfade dual-player real: A 100→0% ∥ B 0→100% simultáneo, equal-power.
  Future<void> _crossfadeTo(LocalSong nextSong, {int? effectiveSecs}) async {
    if (_isCrossfading || !_crossfadeEnabled || _crossfadeSecs <= 0) return;
    final nextIdx = nextQueueIndex;
    if (nextIdx < 0 || nextIdx >= _queue.length) return;
    final effSecs = effectiveSecs ?? _effectiveCrossfadeSecs(nextSong.duration);
    if (effSecs <= 0) return;

    _isCrossfading = true;
    _crossfadeTriggeredForSong = true;
    _crossfadePrevIndex = _currentIndex;
    _crossfadeProgress = 0.0;
    _crossfadeState = 'preparing';
    // ignore: avoid_print
    print('[CROSSFADE] Starting dual → "${nextSong.title}" eff=${effSecs}s userVol=$_userVolume');

    AudioPlayer? nextPlayer;
    try {
      // Reutilizar player si existe y está idle, sino crear
      if (_crossfadeNextPlayer != null) {
        try { await _crossfadeNextPlayer!.stop(); } catch (_) {}
        nextPlayer = _crossfadeNextPlayer;
        _crossfadeNextPlayer = null;
      } else {
        // Crear con pipeline copiando equalizer para mantener efectos
        if (_equalizer != null || _loudnessEnhancer != null) {
          final eq = _equalizer != null ? AndroidEqualizer() : null;
          final loud = _loudnessEnhancer != null ? AndroidLoudnessEnhancer() : null;
          final pipeline = AudioPipeline(androidAudioEffects: [
            if (eq != null) eq,
            if (loud != null) loud,
          ]);
          nextPlayer = AudioPlayer(
            audioPipeline: pipeline,
            handleAudioSessionActivation: false,
            androidApplyAudioAttributes: false,
          );
          // Copiar gains si hay ecualizador
          if (_equalizer != null && eq != null) {
            try { await _copyEqualizerBands(_equalizer!, eq); } catch (_) {}
          }
          if (_soundEnhancement && loud != null) {
            try { loud.setEnabled(true); loud.setTargetGain(3.0); } catch (_) {}
          }
        } else {
          nextPlayer = AudioPlayer(
            handleAudioSessionActivation: false,
            androidApplyAudioAttributes: false,
          );
        }
      }

      _crossfadeState = 'preparing';
      final loadOk = await _withTimeout(
        nextPlayer!.setUrl(nextSong.path).then((_) => true),
        const Duration(seconds: 5),
      );
      if (loadOk == null) {
        // ignore: avoid_print
        print('[CROSSFADE] setUrl timed out — fallback');
        try { nextPlayer!.dispose(); } catch (_) {}
        _cancelCrossfade();
        _advanceIfOldPlayerDone();
        return;
      }

      await nextPlayer!.setVolume(0.0);
      await nextPlayer!.setSpeed(_speed);
      _crossfadeNextPlayer = nextPlayer;
      _crossfadeState = 'fading';

      final playOk = await _withTimeout(
        nextPlayer!.play().then((_) => true),
        const Duration(seconds: 5),
      );
      if (playOk == null) {
        // ignore: avoid_print
        print('[CROSSFADE] play() timed out — fallback single-player fade');
        // Fallback single-player: fade out rápido y switch
        try { nextPlayer!.dispose(); } catch (_) {}
        _crossfadeNextPlayer = null;
        await _fallbackSinglePlayerCrossfade(nextSong, nextIdx, effSecs);
        return;
      }

      // Actualizar UI al inicio de la transición (portada/colores 500-900ms, audio 5s)
      _currentIndex = nextIdx;
      _syncCurrentToHandler();
      _triggerColorExtraction();
      notifyListeners();

      final totalMs = (effSecs * 1000).clamp(500, 10000);
      const stepMs = 50;
      final totalSteps = (totalMs / stepMs).round().clamp(10, 200);
      _crossfadeTotalSteps = totalSteps;
      var step = 0;

      _crossfadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
        try {
          step++;
          _crossfadeProgress = (step / totalSteps).clamp(0.0, 1.0);
          final p = _crossfadeProgress;
          // Equal-power: cos/sin
          final fadeOut = math.cos(p * math.pi / 2);
          final fadeIn = math.sin(p * math.pi / 2);
          try { _player.setVolume((_userVolume * fadeOut).clamp(0.0, 1.0)); } catch (_) {}
          try { nextPlayer!.setVolume((_userVolume * fadeIn).clamp(0.0, 1.0)); } catch (_) {}
          // Posición = la del nuevo player
          try { _position = nextPlayer!.position; } catch (_) {}
          if (step % 2 == 0) notifyListeners();
          if (step >= totalSteps) {
            timer.cancel();
            _completeCrossfade();
          }
        } catch (e) {
          // ignore: avoid_print
          print('[CROSSFADE] Timer error: $e');
          timer.cancel();
          _cancelCrossfade();
          _advanceIfOldPlayerDone();
        }
      });
    } catch (e) {
      // ignore: avoid_print
      print('[CROSSFADE] Error starting: $e');
      if (nextPlayer != null) { try { nextPlayer.dispose(); } catch (_) {} }
      _crossfadeNextPlayer = null;
      _cancelCrossfade();
      _advanceIfOldPlayerDone();
    }
  }

  /// Fallback single-player cuando dual falla (ej. audio focus).
  Future<void> _fallbackSinglePlayerCrossfade(LocalSong nextSong, int nextIdx, int effSecs) async {
    try {
      final halfMs = (effSecs * 1000 / 2).round().clamp(500, 5000);
      const stepMs = 50;
      final steps = (halfMs / stepMs).round().clamp(5, 100);
      var step = 0;
      final c = Completer<void>();
      _crossfadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
        step++;
        final p = (step / steps).clamp(0.0, 1.0);
        final fadeOut = math.cos(p * math.pi / 2);
        try { _player.setVolume(_userVolume * fadeOut); } catch (_) {}
        if (step >= steps) { t.cancel(); c.complete(); }
      });
      await c.future;
      try { _player.setVolume(0.0); } catch (_) {}
      _currentIndex = nextIdx;
      _syncCurrentToHandler();
      _triggerColorExtraction();
      await _player.setUrl(nextSong.path);
      await _player.setVolume(0.0);
      await _player.setSpeed(_speed);
      _position = Duration.zero;
      await _player.play();
      notifyListeners();
      step = 0;
      final c2 = Completer<void>();
      _crossfadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
        step++;
        final p = (step / steps).clamp(0.0, 1.0);
        final fadeIn = math.sin(p * math.pi / 2);
        try { _player.setVolume(_userVolume * fadeIn); } catch (_) {}
        if (step >= steps) { t.cancel(); c2.complete(); }
      });
      await c2.future;
      try { _player.setVolume(_userVolume); } catch (_) {}
      _isCrossfading = false;
      _crossfadeTriggeredForSong = false;
      _crossfadePrevIndex = -1;
      _crossfadeState = 'completed';
      // ignore: avoid_print
      print('[CROSSFADE] Fallback single done');
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('[CROSSFADE] Fallback error: $e');
      _cancelCrossfade();
      _advanceIfOldPlayerDone();
    }
  }

  /// Completa el crossfade dual (swap players).
  void _completeCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    if (_crossfadeNextPlayer != null) {
      final oldPlayer = _player;
      _player = _crossfadeNextPlayer!;
      _crossfadeNextPlayer = null;
      _position = _player.position;
      _setupListeners();
      _handler?.rebindPlayer(_player);
      _syncCurrentToHandler();
      _syncToHandler();
      Future.delayed(const Duration(seconds: 2), () {
        try { oldPlayer.stop(); } catch (_) {}
        try { oldPlayer.dispose(); } catch (_) {}
      });
    }
    _isCrossfading = false;
    _crossfadeTriggeredForSong = false;
    _crossfadePrevIndex = -1;
    _crossfadeState = 'completed';
    _crossfadeProgress = 1.0;
    try { _player.setVolume(_userVolume); } catch (_) {}
    // ignore: avoid_print
    print('[CROSSFADE] Done dual.');
    notifyListeners();
  }

  /// Cancela el crossfade en progreso.
  void _cancelCrossfade() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
    try { _crossfadeNextPlayer?.stop(); } catch (_) {}
    try { _crossfadeNextPlayer?.dispose(); } catch (_) {}
    _crossfadeNextPlayer = null;
    _isCrossfading = false;
    _crossfadeTriggeredForSong = false;
    _crossfadeState = 'idle';
    _crossfadeProgress = 0.0;
    if (_crossfadePrevIndex >= 0 && _crossfadePrevIndex < _queue.length) {
      _currentIndex = _crossfadePrevIndex;
      _syncCurrentToHandler();
    }
    _crossfadePrevIndex = -1;
    try { _player.setVolume(_userVolume); } catch (_) {}
  }

  /// Si el player terminó y el crossfade falló, avanzar.
  void _advanceIfOldPlayerDone() {
    if (_isCrossfading || _isSettingSource) return;
    try {
      final state = _player.processingState;
      if (state == ProcessingState.completed) {
        // ignore: avoid_print
        print('[CROSSFADE] Player completed → auto-advancing');
        Future.microtask(() => next());
      }
    } catch (_) {
      Future.microtask(() => next());
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
    if (_shuffleMode != ShuffleMode.off) {
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
      // Normal: setUrl directo (sin ConcatenatingAudioSource para evitar demora)
      switch (_repeat) {
        case PlayerRepeatMode.off:
          await _player.setLoopMode(LoopMode.off);
        case PlayerRepeatMode.all:
          await _player.setLoopMode(LoopMode.all);
        case PlayerRepeatMode.one:
          await _player.setLoopMode(LoopMode.one);
      }

      await _player.setUrl(songs[startIndex].path);
      _position = Duration.zero;
      _player.play();
    }
    _triggerColorExtraction();
    _isSettingSource = false;
  }

  /// Agrega una canción al final de la cola actual.
  void addToQueue(LocalSong song) {
    if (_isCrossfading) _cancelCrossfade();
    _queue.add(song);
    _concatSource?.add(AudioSource.uri(Uri.file(song.path), tag: song.id));
    _syncToHandler();
    notifyListeners();
  }

  /// Inserta una canción justo después de la actual en la cola.
  void playNext(LocalSong song) {
    if (_isCrossfading) _cancelCrossfade();
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
    if (_isCrossfading) _cancelCrossfade();
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
    if (_isCrossfading) _cancelCrossfade();
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
    // Crossfade deshabilitado
    _isSettingSource = true;
    _currentIndex = index;
    _crossfadeTriggeredForSong = false;
    _syncCurrentToHandler();
    await _player.setUrl(_queue[index].path);
    _position = Duration.zero;
    _player.play();
    _isSettingSource = false;
    _triggerColorExtraction();
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
    if (_shuffleMode == ShuffleMode.off || _shuffleOrder.isEmpty) return List.unmodifiable(_queue);
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
    if (_shuffleMode == ShuffleMode.off || _shuffleOrder.isEmpty) return List.unmodifiable(_ytQueue);
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
    if (_shuffleMode != ShuffleMode.off) {
      _buildShuffleOrder();
    } else {
      _shuffleOrder = [];
    }
    _syncToHandler();
    _resetYtFailCount();
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
    _resetYtFailCount();
    _syncCurrentToHandler();
  }

  bool _ytSkipInProgress = false;
  int _ytConsecutiveFails = 0;
  void _skipFailedYouTube() {
    if (_ytSkipInProgress) return;
    _ytSkipInProgress = true;
    _ytConsecutiveFails++;
    // Si falla 3 seguidas muy rápido, detener para no ciclar infinito (bug reportado: cambia sola)
    if (_ytConsecutiveFails >= 4) {
      debugPrint('YouTube: 4 fallos consecutivos, deteniendo auto-skip');
      _ytConsecutiveFails = 0;
      _isLoadingYouTube = false;
      _ytSkipInProgress = false;
      notifyListeners();
      return;
    }
    final idx = _nextYtIndex();
    if (idx >= 0) {
      debugPrint('Saltando canción fallida → siguiente ($idx) intento $_ytConsecutiveFails');
      Future.delayed(const Duration(milliseconds: 800), () {
        _ytSkipInProgress = false;
        next();
      });
    } else if (_repeat == PlayerRepeatMode.all) {
      debugPrint('Repetición total, reiniciando cola');
      Future.delayed(const Duration(milliseconds: 800), () {
        _ytSkipInProgress = false;
        _ytIndex = 0;
        _loadYouTubeCurrent().then((_) => _player.play());
      });
    } else {
      debugPrint('No hay más canciones, manteniendo servicio activo');
      _position = Duration.zero;
      _ytSkipInProgress = false;
      _isLoadingYouTube = false;
      notifyListeners();
    }
  }

  void _resetYtFailCount() {
    _ytConsecutiveFails = 0;
    _ytSkipInProgress = false;
  }



  // ═══════════════════ CONTROLES COMPARTIDOS ═══════════════════

  Future<void> togglePlay() async {
    if (!hasQueue) return;
    HapticFeedback.mediumImpact();
    if (_isCrossfading) {
      // Pausar ambos y congelar timer
      final isPlaying = _player.playing || (_crossfadeNextPlayer?.playing ?? false);
      if (isPlaying) {
        _crossfadeTimer?.cancel();
        try { await _player.pause(); } catch (_) {}
        try { await _crossfadeNextPlayer?.pause(); } catch (_) {}
      } else {
        try { await _player.play(); } catch (_) {}
        try { await _crossfadeNextPlayer?.play(); } catch (_) {}
        if (_crossfadeProgress < 1.0 && _crossfadeNextPlayer != null && _crossfadeTotalSteps > 0) {
          final totalSteps = _crossfadeTotalSteps;
          var step = (_crossfadeProgress * totalSteps).round();
          final pNext = _crossfadeNextPlayer;
          const stepMs = 50;
          if (pNext != null) {
            _crossfadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
              step++;
              _crossfadeProgress = (step / totalSteps).clamp(0.0, 1.0);
              final p = _crossfadeProgress;
              final fadeOut = math.cos(p * math.pi / 2);
              final fadeIn = math.sin(p * math.pi / 2);
              try { _player.setVolume((_userVolume * fadeOut).clamp(0.0, 1.0)); } catch (_) {}
              try { pNext.setVolume((_userVolume * fadeIn).clamp(0.0, 1.0)); } catch (_) {}
              try { _position = pNext.position; } catch (_) {}
              if (step % 2 == 0) notifyListeners();
              if (step >= totalSteps) { timer.cancel(); _completeCrossfade(); }
            });
          }
        }
      }
      notifyListeners();
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_player.currentIndex == null && hasQueue) {
        if (_source == TrackSource.local) {
          _currentIndex = 0;
        }
      }
      _player.play();
    }
  }

  void setUserVolume(double v) {
    _userVolume = v.clamp(0.0, 1.0);
    if (!_isCrossfading) {
      try { _player.setVolume(_userVolume); } catch (_) {}
    }
    notifyListeners();
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
        final idx = nextQueueIndex;
        if (idx >= 0 && idx < _queue.length) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _currentIndex = idx;
          await _player.setUrl(_queue[idx].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _triggerColorExtraction();
          notifyListeners();
        } else if (_repeat == PlayerRepeatMode.all && _queue.isNotEmpty) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _currentIndex = 0;
          await _player.setUrl(_queue[0].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _triggerColorExtraction();
          notifyListeners();
        }
      } else {
        // Modo normal (sin crossfade): setUrl directo para cambio instantáneo
        final idx = nextQueueIndex;
        if (idx >= 0 && idx < _queue.length) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _currentIndex = idx;
          await _player.setUrl(_queue[idx].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _triggerColorExtraction();
          notifyListeners();
        } else if (_repeat == PlayerRepeatMode.all && _queue.isNotEmpty) {
          _playHistory?.recordPlay(_queue[_currentIndex].id);
          _currentIndex = 0;
          await _player.setUrl(_queue[0].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _triggerColorExtraction();
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
        final prevIdx = prevQueueIndex;
        if (prevIdx >= 0 && prevIdx < _queue.length) {
          _currentIndex = prevIdx;
          await _player.setUrl(_queue[prevIdx].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _triggerColorExtraction();
          notifyListeners();
        }
      } else {
        // Modo normal (sin crossfade): setUrl directo para cambio instantáneo
        final prevIdx = prevQueueIndex;
        if (prevIdx >= 0 && prevIdx < _queue.length) {
          _currentIndex = prevIdx;
          await _player.setUrl(_queue[prevIdx].path);
          _position = Duration.zero;
          _player.play();
          _syncCurrentToHandler();
          _triggerColorExtraction();
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
    if (_shuffleMode != ShuffleMode.off && _shuffleOrder.isNotEmpty) {
      final pos = _shuffleOrder.indexOf(_ytIndex);
      final np = pos + 1;
      return np >= _shuffleOrder.length ? -1 : _shuffleOrder[np];
    }
    final ni = _ytIndex + 1;
    return ni >= _ytQueue.length ? -1 : ni;
  }

  int _prevYtIndex() {
    if (_shuffleMode != ShuffleMode.off && _shuffleOrder.isNotEmpty) {
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

    if (_shuffleMode == ShuffleMode.smart && len > 1) {
      // Smart shuffle: priorizar canciones NO reproducidas recientemente
      final allIndices = List.generate(len, (i) => i);
      final played = Set<int>.from(_playedHistory);

      // Separar en no-reproducidas y reproducidas
      final unplayed = allIndices.where((i) => !played.contains(i)).toList();
      final alreadyPlayed = allIndices.where((i) => played.contains(i)).toList();

      // Mezclar ambos grupos por separado
      unplayed.shuffle();
      alreadyPlayed.shuffle();

      // Las no-reproducidas van primero, luego las ya reproducidas
      _shuffleOrder = [...unplayed, ...alreadyPlayed];
    } else {
      // Shuffle normal: aleatorio puro
      _shuffleOrder = List.generate(len, (i) => i)..shuffle();
    }

    // Siempre poner la canción actual primero
    if (currentIdx >= 0 && _shuffleOrder.isNotEmpty) {
      _shuffleOrder.remove(currentIdx);
      _shuffleOrder.insert(0, currentIdx);
    }
  }

  /// Registra una canción como reproducida para smart shuffle.
  void _recordPlayedForShuffle(int index) {
    if (_shuffleMode == ShuffleMode.smart) {
      _playedHistory.remove(index);
      _playedHistory.add(index);
      // Limitar historial a la mitad de la cola para no agotar opciones
      final maxHistory = (_queue.length * 0.5).ceil();
      while (_playedHistory.length > maxHistory) {
        _playedHistory.removeAt(0);
      }
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

  /// Cicla entre modos de shuffle: Off → Normal → Smart → Off
  void toggleShuffle() async {
    switch (_shuffleMode) {
      case ShuffleMode.off:
        _shuffleMode = ShuffleMode.normal;
        break;
      case ShuffleMode.normal:
        _shuffleMode = ShuffleMode.smart;
        break;
      case ShuffleMode.smart:
        _shuffleMode = ShuffleMode.off;
        break;
    }

    if (_shuffleMode != ShuffleMode.off) {
      _playedHistory.clear();
      _buildShuffleOrder();
    } else {
      _shuffleOrder = [];
    }

    // Restaurar cola original si se desactiva shuffle
    if (_shuffleMode == ShuffleMode.off) {
      if (_source == TrackSource.youtube && _originalYtQueue.isNotEmpty) {
        final currentVideo =
            _ytIndex >= 0 && _ytIndex < _ytQueue.length ? _ytQueue[_ytIndex] : null;
        _ytQueue = List.of(_originalYtQueue);
        if (currentVideo != null) {
          _ytIndex = _ytQueue.indexOf(currentVideo);
          if (_ytIndex < 0) _ytIndex = 0;
        }
      } else if (_source == TrackSource.local && _originalQueue.isNotEmpty) {
        final currentSong =
            _currentIndex >= 0 && _currentIndex < _queue.length ? _queue[_currentIndex] : null;
        _queue = List.of(_originalQueue);
        if (currentSong != null) {
          _currentIndex = _queue.indexOf(currentSong);
          if (_currentIndex < 0) _currentIndex = 0;
        }
      }
    }
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
