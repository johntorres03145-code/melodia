import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/favorites_model.dart';
import '../models/library_model.dart';
import '../models/player_model.dart';
import '../models/song.dart';
import '../screens/equalizer_screen.dart';
import '../screens/album_detail_screen.dart';
import '../screens/artist_detail_screen.dart';
import '../screens/queue_screen.dart';
import '../widgets/animated_equalizer_icon.dart';
import '../widgets/chord_panel.dart';
import '../services/lyrics_service.dart';
import '../services/youtube_search.dart';
import '../widgets/melodia_logo.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with TickerProviderStateMixin {
  late final AnimationController _waveCtrl;
  late final AnimationController _vinylCtrl;
  final LyricsService _lyricsService = LyricsService();
  List<LyricLine>? _lyrics;
  bool _showLyrics = false;
  String? _lastLyricsKey;
  final Map<int, Future<dynamic>> _artworkFutures = {};
  final ScrollController _lyricsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _vinylCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // 1 vuelta cada 2s
    );
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _vinylCtrl.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerModel>();
    final theme = context.watch<ThemeProvider>();
    final song = player.current;
    final ytVideo = player.currentYouTube;

    // Buscar letras SOLO cuando cambia la canción
    final lyricsKey = song?.id.toString() ?? ytVideo?.videoId;
    if (lyricsKey != null && lyricsKey != _lastLyricsKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fetchLyricsIfNeeded(song, ytVideo);
      });
    }

    if (player.playing) {
      if (!_waveCtrl.isAnimating) _waveCtrl.repeat();
      if (!_vinylCtrl.isAnimating) _vinylCtrl.repeat();
    } else {
      _waveCtrl.stop();
      _vinylCtrl.stop();
    }

    return Scaffold(
      backgroundColor: theme.blurBackground ? Colors.transparent : theme.backgroundColor,
      body: _blurBackgroundWrapper(
        theme: theme,
        song: song,
        ytVideo: ytVideo,
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            return SafeArea(
              child: isLandscape
                  ? _landscapeLayout(context, player, theme, song, ytVideo)
                  : _portraitLayout(context, player, theme, song, ytVideo),
            );
          },
        ),
      ),
    );
  }

  /// Envuelve el contenido con fondo borroso usando la portada ampliada.
  Widget _blurBackgroundWrapper({
    required ThemeProvider theme,
    required LocalSong? song,
    required YouTubeVideo? ytVideo,
    required Widget child,
  }) {
    if (!theme.blurBackground) return child;

    return Stack(
      children: [
        // Fondo: portada ampliada con blur intenso
        Positioned.fill(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.darken,
            ),
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 400,
                height: 400,
                child: _artworkContent(context, song, ytVideo, 300),
              ),
            ),
          ),
        ),
        // Capa de blur optimizada (sigma 40→16 para performance)
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(color: Colors.black.withValues(alpha: 0.15)),
          ),
        ),
        // Contenido encima
        Positioned.fill(child: child),
      ],
    );
  }

  /// Busca la letra si la canción cambió.
  void _fetchLyricsIfNeeded(LocalSong? song, YouTubeVideo? ytVideo) {
    final key = song?.id.toString() ?? ytVideo?.videoId;
    if (key == null || key == _lastLyricsKey) return;
    _lastLyricsKey = key;
    _lyrics = null; // Limpiar letras viejas antes de fetch
    final artist = song?.artist ?? ytVideo?.channel ?? '';
    final title = song?.title ?? ytVideo?.title ?? '';
    _lyricsService.fetchLyrics(artist, title).then((l) {
      if (mounted && _lastLyricsKey == key) {
        setState(() => _lyrics = l);
      }
    });
  }

  // ─────────────── PORTRAIT ───────────────

  Widget _portraitLayout(
    BuildContext context,
    PlayerModel player,
    ThemeProvider theme,
    LocalSong? song,
    YouTubeVideo? ytVideo,
  ) {
    final isYtLoading = player.source == TrackSource.youtube && player.isLoadingYouTube;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -100) {
          player.next();
        } else if (v > 100) {
          player.previous();
        }
      },
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 300) {
          Navigator.of(context).pop();
        }
      },
      child: Column(
        children: [
          _topBar(context, player, theme),
          const Spacer(flex: 2),
          isYtLoading
              ? _skeletonArtwork(theme)
              : _wavesAndArtwork(context, song, ytVideo, theme),
          const SizedBox(height: 28),
          isYtLoading
              ? _skeletonTitle(theme)
              : _titleAndArtist(context, song, ytVideo, theme),
          const Spacer(flex: 2),
          _progressBar(context, player, theme),
          const SizedBox(height: 14),
          _controls(context, player, theme),
          const SizedBox(height: 8),
          _equalizerButton(context, theme, player),
          if (!isYtLoading && (song != null || ytVideo != null))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ChordPanel(
                title: song?.title ?? ytVideo?.title ?? '',
                artist: song?.artist ?? ytVideo?.channel ?? '',
              ),
            ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _skeletonArtwork(ThemeProvider theme) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(280 * 0.07),
        color: theme.isDarkMode
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.06),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note_rounded,
                size: 48, color: theme.effectiveAccent.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.effectiveAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonTitle(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Animated dots "Cargando audio..."
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                MelodiaColors.textSecondary,
                theme.effectiveAccent.withValues(alpha: 0.8),
                MelodiaColors.textSecondary,
              ],
            ).createShader(bounds),
            child: const Text(
              'Cargando audio…',
              style: TextStyle(fontSize: 15, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: 140,
            height: 3,
            child: LinearProgressIndicator(
              backgroundColor: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
              color: theme.effectiveAccent.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wavesAndArtwork(
      BuildContext context, LocalSong? song, YouTubeVideo? ytVideo, ThemeProvider theme) {
    final player = context.read<PlayerModel>();
    final hasLyrics = _lyrics != null && _lyrics!.isNotEmpty;

    return GestureDetector(
      onVerticalDragUpdate: hasLyrics ? (d) {
        // Deslizar hacia arriba muestra letra, hacia abajo oculta
        if (d.delta.dy < -5 && !_showLyrics) setState(() => _showLyrics = true);
        if (d.delta.dy > 5 && _showLyrics) setState(() => _showLyrics = false);
      } : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _showLyrics && hasLyrics
            ? _lyricsOverlay(context, player, theme)
            : Stack(
                key: const ValueKey('artwork'),
                alignment: Alignment.center,
                children: [
                  _wavesBackground(theme, player),
                  _staticArtwork(context, song, ytVideo, theme, size: 280),
                  // Ring progress overlay (alrededor de la portada)
                  if (theme.progressBarStyle == ProgressBarStyle.ring)
                    Positioned(
                      width: 296,
                      height: 296,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          _seekFromRing(details.localPosition, 296, player);
                        },
                        onTapDown: (details) {
                          _seekFromRing(details.localPosition, 296, player);
                        },
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: player.duration.inMilliseconds > 0
                                ? (player.position.inMilliseconds / player.duration.inMilliseconds).clamp(0.0, 1.0)
                                : 0.0,
                            color: theme.effectiveAccent,
                          ),
                        ),
                      ),
                    ),
                  // Indicador de swipe (si hay letra)
                  if (hasLyrics)
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_arrow_up, size: 14, color: Colors.white54),
                            Text(' Letra', style: TextStyle(fontSize: 10, color: Colors.white54)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  /// Offset de sincronización de la letra (negativo = la línea se muestra un poco antes).
  static const _lyricSyncOffset = Duration(milliseconds: -250);

  /// Overlay de letra sincronizada.
  Widget _lyricsOverlay(BuildContext context, PlayerModel player, ThemeProvider theme) {
    final pos = player.position - _lyricSyncOffset;
    final lyrics = _lyrics!;

    // Encontrar la línea activa
    int activeIdx = 0;
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (pos >= lyrics[i].timestamp) { activeIdx = i; break; }
    }

    // Auto-scroll a la línea activa
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lyricsScrollController.hasClients) {
        final targetOffset = (activeIdx * 25.0) - 100.0;
        _lyricsScrollController.animateTo(
          targetOffset.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 5 && _showLyrics) setState(() => _showLyrics = false);
      },
      child: Container(
        key: const ValueKey('lyrics'),
        height: 280,
        width: 320,
        decoration: BoxDecoration(
          color: theme.backgroundColor.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: theme.effectiveAccent.withValues(alpha: 0.15), blurRadius: 20),
          ],
        ),
        child: Column(
          children: [
            // Hint para volver a la portada
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_down, size: 16, color: MelodiaColors.textInactive),
                  const SizedBox(width: 4),
                  Text('Deslizá hacia abajo',
                      style: TextStyle(fontSize: 10, color: MelodiaColors.textInactive)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _lyricsScrollController,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: lyrics.length,
                itemBuilder: (ctx, i) {
                  final isActive = i == activeIdx;
                  return AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: isActive ? 17 : 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? theme.effectiveAccent : MelodiaColors.textInactive,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(lyrics[i].text, textAlign: TextAlign.center),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Portrait: carátula estática SIN rotación.
  Widget _staticArtwork(
    BuildContext context,
    LocalSong? song,
    YouTubeVideo? ytVideo,
    ThemeProvider theme, {
    required double size,
  }) {
    final borderRadius = size * 0.07;
    final heroTag = _heroTag(song, ytVideo);

    return Hero(
      tag: heroTag,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: theme.effectiveAccent.withValues(alpha: 0.25),
              blurRadius: size * 0.2,
              offset: Offset(0, size * 0.1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: _artworkContent(context, song, ytVideo, size),
        ),
      ),
    );
  }

  // ─────────────── LANDSCAPE ───────────────

  Widget _landscapeLayout(
    BuildContext context,
    PlayerModel player,
    ThemeProvider theme,
    LocalSong? song,
    YouTubeVideo? ytVideo,
  ) {
    final isYtLoading = player.source == TrackSource.youtube && player.isLoadingYouTube;
    final hasLyrics = _lyrics != null && _lyrics!.isNotEmpty;

    return LayoutBuilder(builder: (ctx, constraints) {
      final h = constraints.maxHeight;
      final widthLeft = constraints.maxWidth * 6 / 12;
      final maxByWidth = (widthLeft - 16) / 1.30;
      final maxByHeight = (h - 40) / 1.0;
      final desired = h < 400 ? 240.0 : 280.0;
      final discSize = desired.clamp(0, math.min(maxByWidth, maxByHeight)).toDouble();

      return Row(
        children: [
          // Izquierda: disco centrado en esquina, bien grande
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: isYtLoading
                    ? _skeletonArtwork(theme)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _titleAndArtistCompact(context, song, ytVideo, theme),
                          ),
                          const SizedBox(height: 16),
                          _vinylWithSleeve(context, song, ytVideo, theme, discSizeOverride: discSize),
                        ],
                      ),
              ),
            ),
          ),
          // Derecha: letra con fondo oscuro + progress + controles (más compacto)
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: hasLyrics
                        ? _lyricsPanelLandscape(context, player, theme)
                        : Container(
                            decoration: BoxDecoration(
                              color: MelodiaColors.midnight.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.effectiveAccent.withValues(alpha: 0.12)),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.music_note, color: MelodiaColors.textInactive, size: 32),
                                  const SizedBox(height: 8),
                                  Text('Sin letra disponible',
                                      style: TextStyle(color: MelodiaColors.textInactive, fontSize: 13)),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _progressBar(context, player, theme),
                  const SizedBox(height: 10),
                  _controls(context, player, theme),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _titleAndArtistCompact(
      BuildContext context, LocalSong? song, YouTubeVideo? ytVideo, ThemeProvider theme) {
    final title = song?.title ?? ytVideo?.title ?? 'Sin canción';
    final artist = song?.artist ?? ytVideo?.channel ?? 'Artista desconocido';
    return Column(
      children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        Text(artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: MelodiaColors.textInactive)),
      ],
    );
  }

  Widget _lyricsPanelLandscape(BuildContext context, PlayerModel player, ThemeProvider theme) {
    final pos = player.position - _lyricSyncOffset;
    final lyrics = _lyrics!;
    int activeIdx = 0;
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (pos >= lyrics[i].timestamp) { activeIdx = i; break; }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lyricsScrollController.hasClients) {
        final target = (activeIdx * 25.0) - 80.0;
        _lyricsScrollController.animateTo(
          target.clamp(0.0, _lyricsScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    return Container(
      decoration: BoxDecoration(
        color: MelodiaColors.midnight.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.effectiveAccent.withValues(alpha: 0.10)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text('Letra', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: MelodiaColors.textInactive)),
            ),
            Expanded(
              child: ListView.builder(
                controller: _lyricsScrollController,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                itemCount: lyrics.length,
                itemBuilder: (ctx, i) {
                  final isActive = i == activeIdx;
                  return AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: isActive ? 15 : 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? theme.effectiveAccent : MelodiaColors.textInactive,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(lyrics[i].text, textAlign: TextAlign.center),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Landscape: funda con imagen + disco que sale al reproducir.
  Widget _vinylWithSleeve(
      BuildContext context, LocalSong? song, YouTubeVideo? ytVideo, ThemeProvider theme,
      {double? discSizeOverride}) {
    final discSize = discSizeOverride ?? 240.0;
    final sleeveSize = discSize * 1.05;
    final slideOut = discSize * 0.68; // más expuesto

    return SizedBox(
      width: sleeveSize + slideOut + 16,
      height: sleeveSize + 12,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Disco (atrás) — se desliza a la derecha al reproducir
          AnimatedBuilder(
            animation: _vinylCtrl,
            builder: (context, child) {
              final isPlaying = _vinylCtrl.isAnimating;
              final offset = isPlaying ? slideOut : 0.0;
              return TweenAnimationOffset(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                offset: Offset(offset, 0),
                child: child!,
              );
            },
            child: Transform.rotate(
              angle: _vinylCtrl.value * 2 * math.pi,
              child: _vinylDisc(context, song, ytVideo, theme, discSize),
            ),
          ),
          // Funda (adelante, encima) — siempre visible, oculta el disco al pausar
          Container(
            width: sleeveSize,
            height: sleeveSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _artworkContent(context, song, ytVideo, sleeveSize,
                  fallback: const Color(0xFF1A1A1E)),
            ),
          ),
        ],
      ),
    );
  }

  /// Disco de vinilo: círculo negro con surcos + etiqueta central.
  Widget _vinylDisc(
    BuildContext context,
    LocalSong? song,
    YouTubeVideo? ytVideo,
    ThemeProvider theme,
    double size,
  ) {
    final heroTag = _heroTag(song, ytVideo);
    final labelSize = size * 0.42;

    return Hero(
      tag: heroTag,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.effectiveAccent.withValues(alpha: 0.15),
              blurRadius: 30,
            ),
          ],
        ),
        child: CustomPaint(
          painter: _VinylDiscPainter(),
          child: Center(
            child: ClipOval(
              child: Container(
                width: labelSize,
                height: labelSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: MelodiaColors.linearGradientMain,
                ),
                child: _artworkContent(context, song, ytVideo, labelSize),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────── SHARED ───────────────

  String _heroTag(LocalSong? song, YouTubeVideo? ytVideo) {
    if (song != null) return 'artwork_${song.id}';
    if (ytVideo != null) return 'artwork_yt_${ytVideo.videoId}';
    return 'artwork_empty';
  }

  String _currentTitle(LocalSong? song, YouTubeVideo? ytVideo) {
    return song?.title ?? ytVideo?.title ?? 'Sin canción';
  }

  String _currentArtist(LocalSong? song, YouTubeVideo? ytVideo) {
    if (song != null) return song.artist.isNotEmpty ? song.artist : 'Artista desconocido';
    if (ytVideo != null) return ytVideo.channel;
    return 'Artista desconocido';
  }

  Widget _artworkContent(BuildContext context, LocalSong? song, YouTubeVideo? ytVideo, double size,
      {Color? fallback}) {
    // YouTube: descargar thumbnail y extraer colores
    if (ytVideo != null && ytVideo.thumb.isNotEmpty) {
      return FutureBuilder<Uint8List>(
        future: _downloadThumb(ytVideo.thumb),
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            return Image.memory(snap.data!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true);
          }
          return Image.network(
            ytVideo.thumb,
            fit: BoxFit.cover,
            width: size,
            height: size,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => Icon(Icons.music_note,
                size: size * 0.3,
                color: context.read<ThemeProvider>().isDarkMode
                    ? Colors.white24
                    : Colors.black26),
          );
        },
      );
    }
    // Local: usar la carátula del álbum
    if (song != null) {
      _artworkFutures.putIfAbsent(song.id, () =>
          context.read<LibraryModel>().songArtworkFor(song.id, albumId: song.albumId));
      return FutureBuilder<dynamic>(
        future: _artworkFutures[song.id],
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            final bytes = snap.data as Uint8List;
            return Image.memory(bytes, fit: BoxFit.cover,
                width: size, height: size,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true);
          }
          return Icon(Icons.music_note, size: size * 0.3, color: context.read<ThemeProvider>().isDarkMode ? Colors.white24 : Colors.black26);
        },
      );
    }
    // Sin nada
    return Icon(Icons.music_note, size: size * 0.3, color: context.read<ThemeProvider>().isDarkMode ? Colors.white24 : Colors.black26);
  }

  // Cache para no re-descargar el mismo thumbnail
  String _lastThumbUrl = '';
  Uint8List? _lastThumbBytes;

  Future<Uint8List> _downloadThumb(String url) async {
    if (url == _lastThumbUrl && _lastThumbBytes != null) return _lastThumbBytes!;
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
        final result = Uint8List.fromList(bytes);
        _lastThumbUrl = url;
        _lastThumbBytes = result;
        return result;
      }
    } catch (_) {}
    finally { client?.close(force: true); }
    return Uint8List(0);
  }

  Widget _topBar(BuildContext context, PlayerModel player, ThemeProvider theme) {
    final textColor = theme.isDarkMode
        ? MelodiaColors.whiteSoft
        : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down_rounded, size: 30,
                color: textColor),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              children: [
                Text(
                  player.shuffle ? 'Reproduciendo (Aleatorio)' : 'En reproducción',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: MelodiaColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                MelodiaLogo(
                  fontSize: 10,
                  color: theme.effectiveAccent,
                  letterSpacing: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 52),
        ],
      ),
    );
  }

  Widget _wavesBackground(ThemeProvider theme, PlayerModel player) {
    // Frecuencia de pulso basada en la posición de la canción (simula ritmo)
    final posSec = player.position.inMilliseconds / 1000.0;
    final pulse = (math.sin(posSec * 3.0) * 0.5 + 0.5); // 0-1 oscilante

    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (ctx, child) => CustomPaint(
        size: const Size(340, 340),
        painter: _WavesPainter(
          progress: _waveCtrl.value,
          pulse: pulse,
          color: theme.effectiveAccent,
        ),
      ),
    );
  }

  Widget _titleAndArtist(
      BuildContext context, LocalSong? song, YouTubeVideo? ytVideo, ThemeProvider theme) {
    final textColor = theme.isDarkMode
        ? MelodiaColors.whiteSoft
        : Colors.black87;

    // Corazón favorito (solo canciones locales)
    final favorites = context.watch<FavoritesModel>();
    final isFav = song != null && favorites.isFavorite(song.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          GestureDetector(
            onTap: () {
              if (song != null && song.albumId != null) {
                final songs = context.read<LibraryModel>().songs;
                final albumSongs = songs.where((s) => s.albumId == song.albumId).toList();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => AlbumDetailScreen(albumName: song.album, songs: albumSongs, albumId: song.albumId!),
                ));
              }
            },
            child: Text(
              _currentTitle(song, ytVideo),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: textColor,
                decoration: song != null ? TextDecoration.underline : TextDecoration.none,
                decorationColor: textColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
              if (song != null && song.artist.isNotEmpty) {
                final songs = context.read<LibraryModel>().songs;
                final artistSongs = songs.where((s) => s.artist == song.artist).toList();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ArtistDetailScreen(artistName: song.artist, songs: artistSongs),
                ));
              }
            },
            child: Text(
              _currentArtist(song, ytVideo),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, color: MelodiaColors.textSecondary),
            ),
          ),
          if (song != null) ...[
            const SizedBox(height: 10),
            _AnimatedHeart(
              isFav: isFav,
              onTap: () => favorites.toggle(song),
            ),
          ],
        ],
      ),
    );
  }

  void _seekFromRing(Offset localPosition, double size, PlayerModel player) {
    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += 2 * math.pi;
    final progress = (angle / (2 * math.pi)).clamp(0.0, 1.0);
    final duration = player.duration.inMilliseconds;
    if (duration > 0) {
      player.seek(Duration(milliseconds: (progress * duration).round()));
    }
  }

  Widget _progressBar(
      BuildContext context, PlayerModel player, ThemeProvider theme) {
    final duration = player.duration.inMilliseconds;
    final pos = player.position.inMilliseconds;
    final progress = duration > 0 ? (pos / duration).clamp(0.0, 1.0) : 0.0;

    // Estilo de la barra según el perfil
    final style = theme.progressBarStyle;
    final accent = theme.effectiveAccent;
    final thumbColor = theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;

    Widget slider;
    switch (style) {
      case ProgressBarStyle.thin:
        slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 1.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
            activeTrackColor: accent,
            inactiveTrackColor: accent.withValues(alpha: 0.15),
            thumbColor: thumbColor,
          ),
          child: _progressSlider(player, progress),
        );
        break;
      case ProgressBarStyle.thick:
        slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: accent,
            inactiveTrackColor: accent.withValues(alpha: 0.15),
            thumbColor: thumbColor,
          ),
          child: _progressSlider(player, progress),
        );
        break;
      case ProgressBarStyle.rounded:
        slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: accent,
            inactiveTrackColor: accent.withValues(alpha: 0.15),
            thumbColor: thumbColor,
            trackShape: const RoundedRectSliderTrackShape(),
          ),
          child: _progressSlider(player, progress),
        );
        break;
      case ProgressBarStyle.minimal:
        slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 1,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.transparent,
            overlayColor: Colors.transparent,
          ),
          child: _progressSlider(player, progress),
        );
        break;
      case ProgressBarStyle.gradient:
        slider = _GradientProgressBar(
          progress: progress,
          accent: accent,
          onChanged: (v) {
            if (duration > 0) {
              player.seek(Duration(milliseconds: (v * duration).round()));
            }
          },
        );
        break;
      case ProgressBarStyle.glow:
        slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            activeTrackColor: accent,
            inactiveTrackColor: accent.withValues(alpha: 0.12),
            thumbColor: accent,
            overlayColor: accent.withValues(alpha: 0.2),
          ),
          child: _progressSlider(player, progress),
        );
        break;
      case ProgressBarStyle.dots:
        slider = _DotsProgressBar(
          progress: progress,
          accent: accent,
          onChanged: (v) {
            if (duration > 0) {
              player.seek(Duration(milliseconds: (v * duration).round()));
            }
          },
        );
        break;
      case ProgressBarStyle.ring:
        // Ring is drawn as an overlay on the artwork; show thin progress line here.
        slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 1.5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
            activeTrackColor: accent,
            inactiveTrackColor: accent.withValues(alpha: 0.1),
            thumbColor: Colors.transparent,
            overlayColor: Colors.transparent,
          ),
          child: _progressSlider(player, progress),
        );
        break;
      case ProgressBarStyle.reveal:
        slider = _RevealProgressBar(
          progress: progress,
          colors: theme.revealPalette.colors,
          onChanged: (v) {
            if (duration > 0) {
              player.seek(Duration(milliseconds: (v * duration).round()));
            }
          },
        );
        break;
      case ProgressBarStyle.neon:
        slider = _NeonProgressBar(
          progress: progress,
          accent: accent,
          onChanged: (v) {
            if (duration > 0) {
              player.seek(Duration(milliseconds: (v * duration).round()));
            }
          },
        );
        break;
      case ProgressBarStyle.wave:
        slider = _WaveProgressBar(
          progress: progress,
          accent: accent,
          isPlaying: player.playing,
          onChanged: (v) {
            if (duration > 0) {
              player.seek(Duration(milliseconds: (v * duration).round()));
            }
          },
        );
        break;
      case ProgressBarStyle.comic:
        slider = _ComicProgressBar(
          progress: progress,
          accent: accent,
          isPlaying: player.playing,
          onChanged: (v) {
            if (duration > 0) {
              player.seek(Duration(milliseconds: (v * duration).round()));
            }
          },
        );
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          slider,
          if (theme.showBarTimes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _timeLabel(player.position),
                  _timeLabel(duration > 0
                      ? Duration(milliseconds: duration)
                      : Duration.zero),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _progressSlider(PlayerModel player, double progress) {
    return Slider(
      value: progress,
      onChangeStart: (_) {},
      onChanged: (v) {
        final duration = player.duration.inMilliseconds;
        if (duration > 0) {
          player.seek(Duration(milliseconds: (v * duration).round()));
        }
      },
    );
  }

  Widget _timeLabel(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return Text('$m:$s',
        style: const TextStyle(fontSize: 12, color: MelodiaColors.textInactive));
  }

  Widget _controls(
      BuildContext context, PlayerModel player, ThemeProvider theme) {
    final repeatIcon = switch (player.repeat) {
      PlayerRepeatMode.off => Icons.repeat_rounded,
      PlayerRepeatMode.all => Icons.repeat_rounded,
      PlayerRepeatMode.one => Icons.repeat_one_rounded,
    };
    final repeatColor = switch (player.repeat) {
      PlayerRepeatMode.off => MelodiaColors.textInactive,
      PlayerRepeatMode.all => theme.effectiveAccent,
      PlayerRepeatMode.one => theme.effectiveAccent,
    };
    final iconColor = theme.isDarkMode
        ? MelodiaColors.whiteSoft
        : Colors.black87;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            player.shuffleMode == ShuffleMode.smart
                ? Icons.auto_awesome
                : Icons.shuffle_rounded,
            color: player.shuffle
                ? (player.shuffleMode == ShuffleMode.smart
                    ? Colors.amber
                    : theme.effectiveAccent)
                : MelodiaColors.textSecondary,
            size: 26,
          ),
          tooltip: player.shuffleMode == ShuffleMode.off
              ? 'Aleatorio off'
              : player.shuffleMode == ShuffleMode.normal
                  ? 'Aleatorio'
                  : 'Smart Shuffle',
          onPressed: player.toggleShuffle,
        ),
        _LongPressSeekButton(
          icon: Icons.skip_previous_rounded,
          iconColor: iconColor,
          onLongPress: () => player.seek(
            Duration(milliseconds: (player.position.inMilliseconds - 1000).clamp(0, player.duration.inMilliseconds)),
          ),
          onTap: player.previous,
        ),
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: theme.effectiveAccent),
          child: IconButton(
            icon: Icon(
              player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 38, color: Colors.black,
            ),
            onPressed: player.togglePlay,
          ),
        ),
        _LongPressSeekButton(
          icon: Icons.skip_next_rounded,
          iconColor: iconColor,
          onLongPress: () => player.seek(
            Duration(milliseconds: (player.position.inMilliseconds + 1000).clamp(0, player.duration.inMilliseconds)),
          ),
          onTap: player.next,
        ),
        IconButton(
          icon: Icon(repeatIcon, color: repeatColor, size: 26),
          onPressed: player.cycleRepeat,
        ),
      ],
    );
  }

  Widget _equalizerButton(BuildContext context, ThemeProvider theme, PlayerModel player) {
    final accent = theme.effectiveAccent;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EqualizerScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedEqualizerIcon(size: 18, color: accent, animate: player.playing),
                  const SizedBox(width: 6),
                  Text(
                    'Ecualizador',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
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
                    builder: (context, _) {
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.queue_music_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'Cola',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: accent),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: player.cycleSpeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: player.speed != 1.0
                    ? accent.withValues(alpha: 0.2)
                    : MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    '${player.speed}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: player.speed != 1.0 ? FontWeight.w600 : FontWeight.w500,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── CUSTOM PAINTERS ───────────────

/// Ondas sutiles detrás de la carátula en portrait — reactivas al ritmo.
class _WavesPainter extends CustomPainter {
  final double progress;
  final double pulse; // 0-1, oscila con la posición de la canción
  final Color color;
  _WavesPainter({required this.progress, required this.pulse, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;

    // 5 capas de ondas con intensidad variable
    for (int i = 0; i < 5; i++) {
      final phase = progress * 2 * math.pi + i * 1.2;
      final pulseBoost = pulse * (1 + i * 0.3); // capas exteriores más reactivas
      final radius = size.width * (0.34 + i * 0.04) + math.sin(phase) * (8 + pulseBoost * 15);
      final alpha = (0.03 + i * 0.015 + pulse * 0.03).clamp(0.0, 0.15);
      paint.color = color.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }

    // Brillo central pulsante (glow)
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.08 + pulse * 0.07),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.35));
    canvas.drawCircle(center, size.width * 0.35, glowPaint);
  }

  @override
  bool shouldRepaint(_WavesPainter old) =>
      old.progress != progress || old.pulse != pulse;
}

/// Disco de vinilo: círculo negro con surcos concéntricos.
class _VinylDiscPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Disco negro
    final discPaint = Paint()..color = const Color(0xFF111111);
    canvas.drawCircle(center, radius, discPaint);

    // Surcos concéntricos
    final groovePaint = Paint()
      ..color = const Color(0xFF1C1C1C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (double r = radius * 0.28; r < radius - 4; r += 3.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Brillo sutil en el borde
    final rimPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 1, rimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Animación de offset con Tween.
class TweenAnimationOffset extends StatelessWidget {
  final Offset offset;
  final Duration duration;
  final Curve curve;
  final Widget child;

  const TweenAnimationOffset({
    super.key,
    required this.offset,
    required this.duration,
    this.curve = Curves.easeInOut,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween(begin: Offset.zero, end: offset),
      duration: duration,
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(offset: value, child: child);
      },
      child: child,
    );
  }
}

// ─────────────── BARRA DE PROGRESO CREATIVA ───────────────

/// Barra de progreso con gradiente accent→magenta.
class _GradientProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final ValueChanged<double> onChanged;
  const _GradientProgressBar({required this.progress, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final magenta = MelodiaColors.magenta;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = 4.0;
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          onTapDown: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          child: Container(
            height: h + 8,
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                // Track de fondo
                Positioned(
                  top: 4, left: 0, right: 0,
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                  ),
                ),
                // Track activo con gradiente
                Positioned(
                  top: 4, left: 0,
                  width: w * progress,
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, magenta]),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                  ),
                ),
                // Thumb
                Positioned(
                  top: 0,
                  left: (w * progress) - 6,
                  child: Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [accent, magenta]),
                      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.4), blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Barra de progreso con puntos discretos.
class _DotsProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final ValueChanged<double> onChanged;
  const _DotsProgressBar({required this.progress, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dotCount = 40;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final activeIndex = (progress * dotCount).floor();
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          onTapDown: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          child: SizedBox(
            height: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(dotCount, (i) {
                final isActive = i <= activeIndex;
                return Container(
                  width: 4,
                  height: isActive ? 10 : 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? accent : accent.withValues(alpha: 0.2),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _AnimatedHeart extends StatefulWidget {
  final bool isFav;
  final VoidCallback onTap;
  const _AnimatedHeart({required this.isFav, required this.onTap});

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_AnimatedHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFav != oldWidget.isFav) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.effectiveAccent;
    final targetColor = widget.isFav ? accent : MelodiaColors.textSecondary;

    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Icon(
            widget.isFav ? Icons.favorite : Icons.favorite_border,
            key: ValueKey('${widget.isFav}_$accent'),
            size: 30,
            color: targetColor,
          ),
        ),
      ),
    );
  }
}

class _LongPressSeekButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _LongPressSeekButton({
    required this.icon,
    required this.iconColor,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_LongPressSeekButton> createState() => _LongPressSeekButtonState();
}

class _LongPressSeekButtonState extends State<_LongPressSeekButton> {
  Timer? _timer;

  void _startLongPress() {
    widget.onLongPress();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      widget.onLongPress();
    });
  }

  void _endLongPress() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPressStart: (_) => _startLongPress(),
      onLongPressEnd: (_) => _endLongPress(),
      onLongPressCancel: _endLongPress,
      child: Icon(widget.icon, size: 36, color: widget.iconColor),
    );
  }
}

/// Barra circular que se llena alrededor de la portada.
/// Se dibuja como un arco encima del contenido (el padre la posiciona).

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    // Anillo de fondo
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Anillo de progreso
    final sweep = 2 * math.pi * progress;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        colors: [color, color.withValues(alpha: 0.6)],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, sweep, false, progressPaint);

    // Thumb brillante en el borde del progreso
    final thumbAngle = -math.pi / 2 + sweep;
    final thumbX = center.dx + radius * math.cos(thumbAngle);
    final thumbY = center.dy + radius * math.sin(thumbAngle);
    final thumbPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumbX, thumbY), 8, thumbPaint);

    // Glow del thumb
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(thumbX, thumbY), 14, glowPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// Barra de progreso con paleta reveladora: colores que se descubren progresivamente.
class _RevealProgressBar extends StatelessWidget {
  final double progress;
  final List<Color> colors;
  final ValueChanged<double> onChanged;
  const _RevealProgressBar({required this.progress, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = 5.0;
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          onTapDown: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          child: Container(
            height: h + 10,
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                // Track de fondo
                Positioned(
                  top: 5, left: 0, right: 0,
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: colors.first.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                  ),
                ),
                // Track activo con gradiente desplazado
                Positioned(
                  top: 5, left: 0,
                  width: w * progress,
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        stops: List.generate(colors.length, (i) => (i / (colors.length - 1)).clamp(0.0, 1.0)),
                      ),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                  ),
                ),
                // Thumb con color que revela
                Positioned(
                  top: 0,
                  left: (w * progress) - 7,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: colors),
                      boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.4), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Barra de progreso con efecto neón: trazo fino con glow intenso.
class _NeonProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final ValueChanged<double> onChanged;
  const _NeonProgressBar({required this.progress, required this.accent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = 3.0;
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          onTapDown: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          child: Container(
            height: 24,
            alignment: Alignment.centerLeft,
            child: Stack(
              children: [
                // Glow exterior del track
                Positioned(
                  top: 6, left: 0, right: 0,
                  child: Container(
                    height: h + 8,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular((h + 8) / 2),
                      boxShadow: [
                        BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 16),
                        BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 32),
                      ],
                    ),
                  ),
                ),
                // Track de fondo
                Positioned(
                  top: 9, left: 0, right: 0,
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                  ),
                ),
                // Track activo neón
                Positioned(
                  top: 9, left: 0,
                  width: w * progress,
                  child: Container(
                    height: h,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(h / 2),
                      boxShadow: [
                        BoxShadow(color: accent.withValues(alpha: 0.8), blurRadius: 8),
                        BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 20),
                        BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 40),
                      ],
                    ),
                  ),
                ),
                // Thumb neón brillante
                Positioned(
                  top: 2,
                  left: (w * progress) - 8,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                      boxShadow: [
                        BoxShadow(color: accent.withValues(alpha: 0.9), blurRadius: 10),
                        BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Barra de progreso ondulatoria: la onda se desplaza con el ritmo.
class _WaveProgressBar extends StatefulWidget {
  final double progress;
  final Color accent;
  final bool isPlaying;
  final ValueChanged<double> onChanged;

  const _WaveProgressBar({
    required this.progress,
    required this.accent,
    required this.isPlaying,
    required this.onChanged,
  });

  @override
  State<_WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<_WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late AnimationController _ampCtrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _ampCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: widget.isPlaying ? 1.0 : 0.0,
    );
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_WaveProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat();
      _ampCtrl.forward();
    } else if (!widget.isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
      _ampCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _ampCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final dx = details.localPosition.dx;
            widget.onChanged((dx / w).clamp(0.0, 1.0));
          },
          onTapDown: (details) {
            final dx = details.localPosition.dx;
            widget.onChanged((dx / w).clamp(0.0, 1.0));
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_ctrl, _ampCtrl]),
            builder: (context, _) {
              return CustomPaint(
                size: Size(w, 24),
                painter: _WaveBarPainter(
                  progress: widget.progress,
                  color: widget.accent,
                  time: _ctrl.value * 2 * math.pi,
                  amplitude: _ampCtrl.value,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Painter de la barra ondulatoria.
class _WaveBarPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double time;
  final double amplitude;

  _WaveBarPainter({
    required this.progress,
    required this.color,
    required this.time,
    this.amplitude = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final midY = h * 0.55;
    final waveHeight = h * 0.35 * amplitude;

    // Track de fondo
    final bgPaint = Paint()..color = color.withValues(alpha: 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, midY - 2, size.width, 4), const Radius.circular(2)),
      bgPaint,
    );

    // Onda activa
    final activeWidth = size.width * progress;
    if (activeWidth <= 0) return;

    final steps = (activeWidth / 2).ceil();

    // Relleno de la onda
    final path = Path();
    path.moveTo(0, midY);
    for (int i = 0; i <= steps; i++) {
      final x = (i * 2).toDouble();
      if (x > activeWidth) break;
      final freq = 0.06;
      final pulse = 0.6 + 0.4 * (time * 2.5 + x * 0.02);
      final a = waveHeight * pulse.clamp(0.3, 1.0);
      final y = midY - math.sin(x * freq + time * 3.0) * a;
      path.lineTo(x, y);
    }
    path.lineTo(activeWidth, midY + waveHeight * 0.3);
    path.lineTo(activeWidth, h);
    path.lineTo(0, h);
    path.close();

    final rect = Rect.fromLTWH(0, 0, activeWidth, h);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.7),
        color.withValues(alpha: 0.2),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Borde superior de la onda
    final wavePath = Path();
    wavePath.moveTo(0, midY);
    for (int i = 0; i <= steps; i++) {
      final x = (i * 2).toDouble();
      if (x > activeWidth) break;
      final freq = 0.06;
      final pulse = 0.6 + 0.4 * (time * 2.5 + x * 0.02);
      final a = waveHeight * pulse.clamp(0.3, 1.0);
      final y = midY - math.sin(x * freq + time * 3.0) * a;
      wavePath.lineTo(x, y);
    }
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(wavePath, strokePaint);

    // Thumb
    final thumbX = activeWidth;
    final thumbFreq = 0.06;
    final thumbPulse = 0.6 + 0.4 * (time * 2.5 + thumbX * 0.02);
    final thumbAmplitude = waveHeight * thumbPulse.clamp(0.3, 1.0);
    final thumbY = midY - math.sin(thumbX * thumbFreq + time * 3.0) * thumbAmplitude;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(thumbX, thumbY), 10, glowPaint);

    final thumbPaint = Paint()..color = color;
    canvas.drawCircle(Offset(thumbX, thumbY), 5, thumbPaint);

    final centerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(thumbX, thumbY), 2, centerPaint);
  }

  @override
  bool shouldRepaint(_WaveBarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.time != time ||
      oldDelegate.amplitude != amplitude;
}

/// Barra de progreso estilo Cómic: panel interactivo con speed lines, halftone
/// y borde jagged.
class _ComicProgressBar extends StatelessWidget {
  final double progress;
  final Color accent;
  final bool isPlaying;
  final ValueChanged<double> onChanged;
  const _ComicProgressBar({
    required this.progress,
    required this.accent,
    required this.isPlaying,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = 32.0;
        return GestureDetector(
          onHorizontalDragUpdate: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          onTapDown: (d) {
            final v = (d.localPosition.dx / w).clamp(0.0, 1.0);
            onChanged(v);
          },
          child: CustomPaint(
            size: Size(w, h),
            painter: _ComicBarPainter(
              progress: progress,
              accent: accent,
              isPlaying: isPlaying,
            ),
          ),
        );
      },
    );
  }
}

class _ComicBarPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final bool isPlaying;
  _ComicBarPainter({
    required this.progress,
    required this.accent,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final progressW = w * progress.clamp(0.0, 1.0);

    // ── Sombra del panel (efecto pop-out) ──
    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    final shadowPath = _jaggedBorderPath(w + 2, h + 2, offset: const Offset(2, 3));
    canvas.drawPath(shadowPath, shadowPaint);

    // ── Fondo del panel ──
    final bgPaint = Paint()..color = const Color(0xFF12121C);
    final bgPath = _jaggedBorderPath(w, h);
    canvas.drawPath(bgPath, bgPaint);

    // ── Halftone dots (textura comic — más grande y variado) ──
    for (double dx = 4; dx < w; dx += 10) {
      for (double dy = 4; dy < h; dy += 10) {
        // Dots más grandes cerca del borde del progreso
        final distToProgress = (dx - progressW).abs();
        final dotSize = distToProgress < 20 ? 2.2 : 1.4;
        final alpha = distToProgress < 20 ? 0.12 : 0.06;
        final dotPaint = Paint()..color = Colors.white.withValues(alpha: alpha);
        canvas.drawCircle(Offset(dx, dy), dotSize, dotPaint);
      }
    }

    // ── Barra de progreso ──
    if (progressW > 0) {
      // Fill con gradiente
      final progressRect = Rect.fromLTWH(0, 0, progressW, h);
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          colors: [accent, accent.withValues(alpha: 0.8)],
        ).createShader(progressRect);
      final progressPath = _jaggedBorderPath(w, h);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, progressW, h));
      canvas.drawPath(progressPath, gradientPaint);
      canvas.restore();

      // Halftone invertido dentro del progreso
      for (double dx = 4; dx < progressW; dx += 10) {
        for (double dy = 4; dy < h; dy += 10) {
          final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.18);
          canvas.drawCircle(Offset(dx, dy), 1.8, dotPaint);
        }
      }
    }

    // ── Speed lines detrás del thumb (estilo manga) ──
    if (progressW > 12) {
      final thumbX = progressW.clamp(12.0, w - 12.0);
      final thumbY = h / 2;
      final linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;

      final lineAngles = [-0.35, -0.18, -0.06, 0.06, 0.18, 0.35];
      final lineLengths = [10.0, 14.0, 10.0, 10.0, 14.0, 10.0];
      final lineStartX = thumbX - 14;

      for (int i = 0; i < lineAngles.length; i++) {
        final angle = lineAngles[i];
        final len = lineLengths[i];
        final startX = lineStartX - (i % 2 == 0 ? 4 : 0);
        final endX = startX - len;
        final dy = len * angle;
        canvas.drawLine(
          Offset(startX, thumbY + dy),
          Offset(endX, thumbY + dy * 1.5),
          linePaint,
        );
      }
    }

    // ── Borde jagged negro (estilo panel de cómic) ──
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    final borderPath = _jaggedBorderPath(w, h);
    canvas.drawPath(borderPath, borderPaint);

    // ── Thumb: círculo blanco con borde negro y estrella de impacto ──
    final thumbX = progressW.clamp(12.0, w - 12.0);
    final thumbY = h / 2;
    final thumbR = 10.0;

    // Glow sutil del accent
    final glowPaint = Paint()
      ..color = accent.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(thumbX, thumbY), thumbR + 4, glowPaint);

    // Círculo blanco
    final thumbBg = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(thumbX, thumbY), thumbR, thumbBg);

    // Borde negro del thumb
    final thumbBorder = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    canvas.drawCircle(Offset(thumbX, thumbY), thumbR, thumbBorder);

    // Punto de acento en el centro
    final dotCenter = Paint()..color = accent;
    canvas.drawCircle(Offset(thumbX, thumbY), 3.5, dotCenter);

    // ── Mini estrella de impacto en la esquina superior derecha ──
    final starX = thumbX + 7;
    final starY = thumbY - 7;
    final starPaint = Paint()..color = accent;
    _drawMiniStar(canvas, starX, starY, 4.0, starPaint);
  }

  /// Genera un Path con borde jagged (dientes de sierra) estilo cómic.
  Path _jaggedBorderPath(double w, double h, {Offset offset = Offset.zero}) {
    final path = Path();
    final teethH = 2.0;
    final teethW = 6.0;
    final top = offset.dy;
    final left = offset.dx;

    // Top edge (dientes hacia arriba)
    path.moveTo(left, top);
    for (double x = left; x < left + w; x += teethW) {
      path.lineTo(x + teethW * 0.5, top - teethH);
      path.lineTo(x + teethW, top);
    }

    // Right edge
    path.lineTo(left + w, top + h);

    // Bottom edge (dientes hacia abajo)
    for (double x = left + w; x > left; x -= teethW) {
      path.lineTo(x - teethW * 0.5, top + h + teethH);
      path.lineTo(x - teethW, top + h);
    }

    path.close();
    return path;
  }

  /// Dibuja una mini estrella de 4 puntas.
  void _drawMiniStar(Canvas canvas, double cx, double cy, double r, Paint paint) {
    final path = Path();
    final inner = r * 0.35;
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final outerX = cx + r * math.cos(angle);
      final outerY = cy + r * math.sin(angle);
      final midAngle = angle + math.pi / 4;
      final midX = cx + inner * math.cos(midAngle);
      final midY = cy + inner * math.sin(midAngle);
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(midX, midY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ComicBarPainter old) =>
      old.progress != progress || old.accent != accent || old.isPlaying != isPlaying;
}