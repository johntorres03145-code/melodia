import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:chord_diagrams/chord_diagrams.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'models/favorites_model.dart';
import 'models/library_model.dart';
import 'models/play_history_model.dart';
import 'models/player_model.dart';
import 'models/playlist_model.dart';
import 'screens/main_scaffold.dart';
import 'screens/splash_screen.dart';
import 'services/audio_player_handler.dart';
import 'services/youtube_search.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ChordDiagrams.ensureInitialized();

  // Sesión de audio para mantener la reproducción en segundo plano.
  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration.music());
  await session.setActive(true);

  // Pedir todos los permisos al inicio para que aparezcan seguidos.
  if (Platform.isAndroid) {
    await [
      Permission.notification,
      Permission.audio,
    ].request();
  }

  // Inicializar AdMob (fire-and-forget).
  MobileAds.instance.initialize().ignore();

  await Hive.initFlutter();
  final settingsBox = await Hive.openBox('settings');
  final playlistsBox = await Hive.openBox('playlists');
  final historyBox = await Hive.openBox('play_history');

  final themeProvider = ThemeProvider();
  await themeProvider.init(settingsBox);

  final favoritesProvider = FavoritesModel();
  await favoritesProvider.init(settingsBox);

  final playlistModel = PlaylistModel();
  await playlistModel.init(playlistsBox);

  final playHistory = PlayHistoryModel();
  await playHistory.init(historyBox);

  // Reproducción en segundo plano (audio_service) compartiendo el player.
  final equalizer = AndroidEqualizer();
  if (themeProvider.equalizerEnabled) {
    equalizer.setEnabled(true);
  }
  final loudnessEnhancer = AndroidLoudnessEnhancer();
  final pipeline = AudioPipeline(
    androidAudioEffects: [equalizer, loudnessEnhancer],
  );
  final player = AudioPlayer(audioPipeline: pipeline, useProxyForRequestHeaders: false);
  final playerModel = PlayerModel(
    player: player,
    playHistory: playHistory,
    equalizer: equalizer,
    loudnessEnhancer: loudnessEnhancer,
  );
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(player: player, model: playerModel),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.melodia.channel.audio',
      androidNotificationChannelName: 'Reproducción',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
    ),
  );
  playerModel.attachHandler(audioHandler);

  // Sincronizar crossfade con los valores guardados en ThemeProvider.
  playerModel.setCrossfadeEnabled(themeProvider.crossfadeEnabled, themeProvider.crossfadeDuration);

  final libraryModel = LibraryModel();
  libraryModel.init(settingsBox);
  libraryModel.attachPlayHistory(playHistory);
  audioHandler.attachLibrary(libraryModel);
  audioHandler.attachFavorites(favoritesProvider);
  audioHandler.attachPlayHistory(playHistory);
  audioHandler.attachPlaylists(playlistModel);

  const ytApiKey = String.fromEnvironment('YOUTUBE_API_KEY');
  if (ytApiKey.isNotEmpty) {
    audioHandler.attachYouTubeSearch(YouTubeSearch(ytApiKey));
  }

  runApp(MelodiaApp(
    themeProvider: themeProvider,
    favoritesProvider: favoritesProvider,
    playerModel: playerModel,
    playlistModel: playlistModel,
    playHistory: playHistory,
    libraryModel: libraryModel,
    settingsBox: settingsBox,
  ));
}

class MelodiaApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  final FavoritesModel favoritesProvider;
  final PlayerModel playerModel;
  final PlaylistModel playlistModel;
  final PlayHistoryModel playHistory;
  final LibraryModel libraryModel;
  final Box settingsBox;
  const MelodiaApp({
    super.key,
    required this.themeProvider,
    required this.favoritesProvider,
    required this.playerModel,
    required this.playlistModel,
    required this.playHistory,
    required this.libraryModel,
    required this.settingsBox,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LibraryModel>.value(value: libraryModel),
        ChangeNotifierProvider<PlayerModel>.value(value: playerModel),
        ChangeNotifierProvider<FavoritesModel>.value(value: favoritesProvider),
        ChangeNotifierProvider<PlaylistModel>.value(value: playlistModel),
        ChangeNotifierProvider<PlayHistoryModel>.value(value: playHistory),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: 'MELOD♪A',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(theme),
            home: SplashScreen.shouldShow(settingsBox)
                ? const SplashScreen()
                : const MainScaffold(),
          );
        },
      ),
    );
  }
}