import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/favorites_model.dart';
import '../models/library_model.dart';
import '../models/player_model.dart';
import '../models/playlist_model.dart';
import '../models/song.dart';
import '../widgets/artwork_thumb.dart';
import 'album_detail_screen.dart';
import 'artist_detail_screen.dart';
import 'playlists_screen.dart';

/// Biblioteca: escanea la música del dispositivo, muestra en 3 pestañas.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _selectMode = false;
  final Set<int> _selectedIds = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<LibraryModel>().load();
    });
  }

  void _toggleSelection(int songId) {
    setState(() {
      if (_selectedIds.contains(songId)) {
        _selectedIds.remove(songId);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(songId);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  void _selectAll(List<LocalSong> songs) {
    setState(() {
      if (_selectedIds.length == songs.length) {
        _selectedIds.clear();
        _selectMode = false;
      } else {
        _selectedIds.addAll(songs.map((s) => s.id));
      }
    });
  }

  void _showPlaylistPicker(BuildContext context, List<LocalSong> songs) {
    final playlists = context.read<PlaylistModel>();
    final selectedSongs =
        songs.where((s) => _selectedIds.contains(s.id)).toList();
    final theme = context.read<ThemeProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: playlists,
        child: _PlaylistPickerSheet(
          selectedSongs: selectedSongs,
          theme: theme,
        ),
      ),
    ).then((_) => _exitSelectMode());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryModel>();
    final player = context.read<PlayerModel>();
    final songs = library.songs;
    final accent = theme.effectiveAccent;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──
            Text(
              'My Library',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: MelodiaColors.textColor(theme.isDarkMode),
                  ),
            ),
            const SizedBox(height: 10),

            // ── Playlists shortcut ──
            _playlistsButton(context, theme),
            const SizedBox(height: 10),

            // ── Search + Sort ──
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (q) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                        library.setQuery(q);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar canciones...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<SortMode>(
                  icon: Icon(Icons.sort,
                      color: MelodiaColors.textColor(theme.isDarkMode)),
                  onSelected: library.setSortMode,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: SortMode.name, child: Text('Nombre (A-Z)')),
                    PopupMenuItem(
                        value: SortMode.recent,
                        child: Text('Última agregada')),
                    PopupMenuItem(
                        value: SortMode.mostPlayed,
                        child: Text('Más escuchadas')),
                    PopupMenuItem(
                        value: SortMode.duration, child: Text('Duración')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── TabBar ──
            TabBar(
              controller: _tabController,
              labelColor: accent,
              unselectedLabelColor: MelodiaColors.textInactive,
              labelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w400),
              indicatorColor: accent,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              dividerHeight: 0,
              tabs: const [
                Tab(text: 'Canciones'),
                Tab(text: 'Álbumes'),
                Tab(text: 'Artistas'),
              ],
            ),

            // ── TabBarView ──
            Expanded(
              child: Stack(
                children: [
                  library.loading
                      ? Center(
                          child:
                              CircularProgressIndicator(color: accent))
                      : library.error != null
                          ? _CenteredMessage(
                              icon: Icons.error_outline,
                              message: library.error!)
                          : TabBarView(
                              controller: _tabController,
                              children: [
                                _songList(songs, player),
                                _albumList(library, theme, player),
                                _artistList(library, theme, player),
                              ],
                            ),
                  // ── Bottom action bar (multi-select) ──
                  if (_selectMode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        decoration: BoxDecoration(
                          color: theme.isDarkMode
                              ? const Color(0xFF1A1D28)
                              : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              // Selección info
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _selectAll(songs),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _selectedIds.length == songs.length
                                            ? Icons.check_circle
                                            : Icons.radio_button_unchecked,
                                        color: accent,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_selectedIds.length} seleccionada${_selectedIds.length == 1 ? '' : 's'}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: accent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Botón agregar a playlist
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showPlaylistPicker(context, songs),
                                icon: const Icon(Icons.playlist_add, size: 20),
                                label: const Text('Agregar a playlist'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botón cancelar
                              IconButton(
                                onPressed: _exitSelectMode,
                                icon: const Icon(Icons.close, size: 20),
                                color: MelodiaColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Songs Tab ──
  Widget _songList(List<LocalSong> songs, PlayerModel player) {
    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_music_outlined,
                  size: 56,
                  color: context
                      .read<ThemeProvider>()
                      .effectiveAccent
                      .withValues(alpha: 0.6)),
              const SizedBox(height: 16),
              const Text(
                'Tu biblioteca está vacía',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: MelodiaColors.textSecondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Conectá tu dispositivo y otorgá permisos\npara acceder a tu música.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: MelodiaColors.textInactive),
              ),
            ],
          ),
        ),
      );
    }
    final accent = context.read<ThemeProvider>().effectiveAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Scrollable action chips ──
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _ActionChip(
                  label: 'Reproducir todo',
                  icon: Icons.play_arrow_rounded,
                  filled: true,
                  onTap: () => player.playQueue(songs, 0),
                ),
                const SizedBox(width: 10),
                _ActionChip(
                  label: 'Aleatorio',
                  icon: Icons.shuffle,
                  filled: false,
                  onTap: () {
                    final shuffled = List.of(songs)..shuffle();
                    player.playQueue(shuffled, 0);
                  },
                ),
                const SizedBox(width: 10),
                _ActionChip(
                  label: _selectMode ? 'Cancelar' : 'Seleccionar',
                  icon: _selectMode ? Icons.close : Icons.checklist,
                  filled: _selectMode,
                  onTap: () {
                    setState(() {
                      if (_selectMode) {
                        _exitSelectMode();
                      } else {
                        _selectMode = true;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: songs.length,
            itemBuilder: (context, i) {
              final song = songs[i];
              final isSelected = _selectedIds.contains(song.id);
              return GestureDetector(
                onLongPress: () {
                  _showSongOptions(context, song);
                },
                child: Container(
                  color: isSelected ? accent.withValues(alpha: 0.1) : null,
                  child: ListTile(
                    onTap: _selectMode
                        ? () => _toggleSelection(song.id)
                        : () {
                            final library = context.read<LibraryModel>();
                            final sortedSongs = library.songs;
                            final fullIndex =
                                sortedSongs.indexWhere((s) => s.id == song.id);
                            library.setQuery('');
                            player.playQueue(
                                sortedSongs, fullIndex >= 0 ? fullIndex : 0);
                          },
                    contentPadding: EdgeInsets.zero,
                    leading: _selectMode
                        ? Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? accent
                                  : MelodiaColors.textInactive,
                              size: 22,
                            ),
                          )
                        : ArtworkThumb(song: song),
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist.isEmpty
                          ? 'Artista desconocido'
                          : song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _selectMode
                        ? null
                        : PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: MelodiaColors.textInactive, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onSelected: (v) =>
                                _onSongMenuAction(context, v, song),
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'play',
                                child: _MenuTile(
                                    icon: Icons.play_arrow_rounded,
                                    title: 'Reproducir ahora'),
                              ),
                              const PopupMenuItem(
                                value: 'queue',
                                child: _MenuTile(
                                    icon: Icons.queue_music,
                                    title: 'Agregar a la cola'),
                              ),
                              PopupMenuItem(
                                value: 'favorite',
                                child: _MenuTile(
                                  icon: context
                                          .read<FavoritesModel>()
                                          .isFavorite(song.id)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  title: context
                                          .read<FavoritesModel>()
                                          .isFavorite(song.id)
                                      ? 'Quitar de favoritos'
                                      : 'Agregar a favoritos',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'playlist',
                                child: _MenuTile(
                                    icon: Icons.playlist_add,
                                    title: 'Agregar a playlist'),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'hide',
                                child: _MenuTile(
                                    icon: Icons.visibility_off,
                                    title: 'Ocultar canción'),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${songs.length} canciones',
            style: const TextStyle(
                fontSize: 12, color: MelodiaColors.textInactive),
          ),
        ),
      ],
    );
  }

  // ── Long-press / popup menu actions ──
  void _onSongMenuAction(
      BuildContext context, String value, LocalSong song) {
    final player = context.read<PlayerModel>();
    final favorites = context.read<FavoritesModel>();
    final library = context.read<LibraryModel>();

    switch (value) {
      case 'play':
        player.playQueue([song], 0);
      case 'queue':
        player.addToQueue(song);
      case 'favorite':
        favorites.toggle(song);
      case 'playlist':
        _showSingleSongPlaylistPicker(context, song);
      case 'hide':
        library.hideSong(song.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Canción ocultada: ${song.title}'),
            action: SnackBarAction(
              label: 'Deshacer',
              textColor: context.read<ThemeProvider>().effectiveAccent,
              onPressed: () => library.unhideSong(song.id),
            ),
            duration: const Duration(minutes: 5),
          ),
        );
    }
  }

  void _showSongOptions(BuildContext context, LocalSong song) {
    final theme = context.read<ThemeProvider>();
    final accent = theme.effectiveAccent;
    final textColor =
        theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;
    final isFav = context.read<FavoritesModel>().isFavorite(song.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: MelodiaColors.textInactive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Song info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  ArtworkThumb(song: song, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        Text(
                          song.artist.isEmpty
                              ? 'Desconocido'
                              : song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: MelodiaColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            _BottomSheetTile(
              icon: Icons.play_arrow_rounded,
              title: 'Reproducir ahora',
              onTap: () {
                Navigator.pop(context);
                context.read<PlayerModel>().playQueue([song], 0);
              },
            ),
            _BottomSheetTile(
              icon: Icons.queue_music,
              title: 'Agregar a la cola',
              onTap: () {
                Navigator.pop(context);
                context.read<PlayerModel>().addToQueue(song);
              },
            ),
            _BottomSheetTile(
              icon: isFav ? Icons.favorite : Icons.favorite_border,
              title: isFav
                  ? 'Quitar de favoritos'
                  : 'Agregar a favoritos',
              onTap: () {
                Navigator.pop(context);
                context.read<FavoritesModel>().toggle(song);
              },
            ),
            _BottomSheetTile(
              icon: Icons.playlist_add,
              title: 'Agregar a playlist',
              onTap: () {
                Navigator.pop(context);
                _showSingleSongPlaylistPicker(context, song);
              },
            ),
            const Divider(height: 1),
            _BottomSheetTile(
              icon: Icons.visibility_off,
              title: 'Ocultar canción',
              color: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                final library = context.read<LibraryModel>();
                library.hideSong(song.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Canción ocultada: ${song.title}'),
                    action: SnackBarAction(
                      label: 'Deshacer',
                      textColor: accent,
                      onPressed: () => library.unhideSong(song.id),
                    ),
                    duration: const Duration(minutes: 5),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSingleSongPlaylistPicker(
      BuildContext context, LocalSong song) {
    final playlists = context.read<PlaylistModel>();
    final theme = context.read<ThemeProvider>();
    final accent = theme.effectiveAccent;
    final textColor =
        theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: playlists,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MelodiaColors.textInactive,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Agregar "${song.title}" a...',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add, color: accent, size: 22),
                ),
                title: Text('Crear nueva playlist',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: textColor)),
                onTap: () async {
                  final name = await _showCreatePlaylistDialog(context);
                  if (name != null &&
                      name.isNotEmpty &&
                      context.mounted) {
                    await playlists.create(name: name);
                    final newPlaylist = playlists.all.last;
                    await playlists.addSong(newPlaylist.id, song);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Agregada a "$name"'),
                          backgroundColor: accent,
                        ),
                      );
                    }
                  }
                },
              ),
              const Divider(height: 1),
              if (playlists.all.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay playlists creadas',
                      style: TextStyle(
                          color: MelodiaColors.textSecondary)),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.all.length,
                    itemBuilder: (context, i) {
                      final pl = playlists.all[i];
                      return ListTile(
                        leading: pl.coverImage != null
                            ? ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(8),
                                child: Image.memory(pl.coverImage!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover),
                              )
                            : Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.queue_music,
                                    color: accent, size: 20),
                              ),
                        title: Text(pl.name,
                            style: TextStyle(color: textColor)),
                        subtitle: Text('${pl.count} canciones',
                            style: const TextStyle(
                                fontSize: 12,
                                color:
                                    MelodiaColors.textSecondary)),
                        onTap: () async {
                          await playlists.addSong(pl.id, song);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Agregada a "${pl.name}"'),
                                backgroundColor: accent,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showCreatePlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    final theme = context.read<ThemeProvider>();
    final accent = theme.effectiveAccent;
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: const Text('Nueva playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nombre de la playlist',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Crear', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }

  // ── Artists Tab ──
  Widget _artistList(
      LibraryModel library, ThemeProvider theme, PlayerModel player) {
    final artists = library.artists;
    if (artists.isEmpty) {
      return const Center(
          child: Text('No hay artistas',
              style: TextStyle(color: MelodiaColors.textSecondary)));
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: artists.length,
      itemBuilder: (context, i) {
        final artist = artists[i];
        return GestureDetector(
          onTap: () {
            final songsByArtist = library.songsByArtist(artist.name);
            if (songsByArtist.isNotEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtistDetailScreen(
                        artistName: artist.name, songs: songsByArtist),
                  ));
            }
          },
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: MelodiaColors.linearGradientMain,
                  boxShadow: [
                    BoxShadow(
                      color: theme.effectiveAccent.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: artist.sampleSongId != null
                      ? FutureBuilder<dynamic>(
                          future: context
                              .read<LibraryModel>()
                              .songArtworkFor(artist.sampleSongId!,
                                  albumId: artist.sampleAlbumId),
                          builder: (context, snap) {
                            if (snap.hasData && snap.data != null) {
                              return Image.memory(snap.data,
                                  width: 80, height: 80, fit: BoxFit.cover);
                            }
                            return Icon(Icons.person,
                                color: theme.isDarkMode ? Colors.white70 : Colors.black54, size: 30);
                          },
                        )
                      : Icon(Icons.person,
                          color: theme.isDarkMode ? Colors.white70 : Colors.black54, size: 30),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Text(
                '${artist.songCount}',
                style: const TextStyle(
                    fontSize: 11, color: MelodiaColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Albums Tab ──
  Widget _albumList(
      LibraryModel library, ThemeProvider theme, PlayerModel player) {
    final albums = library.albums;
    if (albums.isEmpty) {
      return const Center(
          child: Text('No hay álbumes',
              style: TextStyle(color: MelodiaColors.textSecondary)));
    }
    return GridView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final album = albums[i];
        return GestureDetector(
          onTap: () {
            final songsByAlbum = library.songsByAlbum(album.name);
            if (songsByAlbum.isNotEmpty) {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlbumDetailScreen(
                        albumName: album.name,
                        songs: songsByAlbum,
                        albumId: album.albumId),
                  ));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: MelodiaColors.linearGradientMain,
                  boxShadow: [
                    BoxShadow(
                      color: theme.effectiveAccent.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: album.albumId != null
                    ? FutureBuilder<dynamic>(
                        future: context
                            .read<LibraryModel>()
                            .artworkFor(album.albumId),
                        builder: (context, snap) {
                          if (snap.hasData && snap.data != null) {
                            return Image.memory(snap.data,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 130);
                          }
                          return Center(
                              child: Icon(Icons.library_music,
                                  size: 36, color: theme.isDarkMode ? Colors.white70 : Colors.black54));
                        },
                      )
                    : Center(
                        child: Icon(Icons.library_music,
                            size: 36, color: theme.isDarkMode ? Colors.white70 : Colors.black54)),
              ),
              const SizedBox(height: 8),
              Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '${album.songCount} canciones',
                style: const TextStyle(
                    fontSize: 11, color: MelodiaColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Playlists card ──
  Widget _playlistsButton(BuildContext context, ThemeProvider theme) {
    final playlists = context.watch<PlaylistModel>();
    final count = playlists.all.length;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: MelodiaColors.linearGradientMain,
              ),
              child: Icon(Icons.queue_music,
                  color: theme.isDarkMode ? Colors.white70 : Colors.black54, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Playlists',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    count == 0
                        ? 'Creá tu primera playlist'
                        : '$count playlist${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: MelodiaColors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: MelodiaColors.textColor(theme.isDarkMode),
                size: 22),
          ],
        ),
      ),
    );
  }
}

/// Botón de acción compacto (fill / outline).
class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.effectiveAccent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: accent, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled ? Colors.white : accent,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const _CenteredMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: theme.effectiveAccent),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: MelodiaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet para elegir a qué playlist agregar canciones.
class _PlaylistPickerSheet extends StatelessWidget {
  final List<LocalSong> selectedSongs;
  final ThemeProvider theme;
  const _PlaylistPickerSheet({
    required this.selectedSongs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistModel>();
    final accent = theme.effectiveAccent;
    final textColor =
        theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: MelodiaColors.textInactive,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Agregar ${selectedSongs.length} canción${selectedSongs.length == 1 ? '' : 'es'} a...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          // Crear nueva playlist
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add, color: accent, size: 22),
            ),
            title: Text(
              'Crear nueva playlist',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            onTap: () async {
              final name = await _showCreatePlaylistDialog(context);
              if (name != null && name.isNotEmpty && context.mounted) {
                await playlists.create(name: name);
                final newPlaylist = playlists.all.last;
                await playlists.addSongs(newPlaylist.id, selectedSongs);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${selectedSongs.length} canciones agregadas a "$name"'),
                      backgroundColor: accent,
                    ),
                  );
                }
              }
            },
          ),
          const Divider(height: 1),
          // Lista de playlists existentes
          if (playlists.all.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No hay playlists creadas',
                style: TextStyle(color: MelodiaColors.textSecondary),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: playlists.all.length,
                itemBuilder: (context, i) {
                  final playlist = playlists.all[i];
                  return ListTile(
                    leading: playlist.coverImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              playlist.coverImage!,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.queue_music,
                                color: accent, size: 20),
                          ),
                    title: Text(
                      playlist.name,
                      style: TextStyle(color: textColor),
                    ),
                    subtitle: Text(
                      '${playlist.count} canciones',
                      style: const TextStyle(
                          fontSize: 12,
                          color: MelodiaColors.textSecondary),
                    ),
                    onTap: () async {
                      await playlists.addSongs(playlist.id, selectedSongs);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '${selectedSongs.length} canciones agregadas a "${playlist.name}"'),
                            backgroundColor: accent,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<String?> _showCreatePlaylistDialog(BuildContext context) async {
    final controller = TextEditingController();
    final accent = theme.effectiveAccent;
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.backgroundColor,
        title: const Text('Nueva playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Nombre de la playlist',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Crear', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  const _MenuTile({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MelodiaColors.textSecondary),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class _BottomSheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;
  const _BottomSheetTile({
    required this.icon,
    required this.title,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? MelodiaColors.textSecondary;
    return ListTile(
      leading: Icon(icon, size: 22, color: effectiveColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: color != null ? color : null,
        ),
      ),
      onTap: onTap,
    );
  }
}
