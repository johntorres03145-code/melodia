import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme_provider.dart';
import '../models/player_model.dart';
import '../widgets/ad_banner.dart';
import '../widgets/ambient_particles.dart';
import '../widgets/custom_tab_bar.dart';
import '../widgets/mini_player.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'splash_screen.dart';

/// Contenedor principal: 5 pestañas + minireproductor + barra inferior.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with WidgetsBindingObserver {
  int _index = 0;
  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SplashScreen.markOpened(Hive.box('settings'));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      SplashScreen.markOpened(Hive.box('settings'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(
        onOpenProfile: () => setState(() => _index = 4),
        onOpenLibrary: () => setState(() => _index = 2),
      ),
      const ExploreScreen(),
      const LibraryScreen(),
      FavoritesScreen(onOpenLibrary: () => setState(() => _index = 2)),
      const ProfileScreen(),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
        } else {
          final now = DateTime.now();
          if (_lastBackPress != null &&
              now.difference(_lastBackPress!) <
                  const Duration(seconds: 2)) {
            SystemNavigator.pop();
          } else {
            _lastBackPress = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Presioná de nuevo para salir'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _buildBackgroundImage(context),
            _buildAmbientGlow(context),
            _buildAmbientParticles(context),
            IndexedStack(index: _index, children: screens),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BannerAdWidget(),
            const MiniPlayer(),
            const SizedBox(height: 4),
            CustomTabBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundImage(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final path = theme.backgroundImagePath;
    if (path == null || !File(path).existsSync()) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: Opacity(
        opacity: theme.backgroundImageOpacity,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _buildAmbientGlow(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final path = theme.backgroundImagePath;
    if (!theme.autoColorEnabled) return const SizedBox.shrink();
    if (path != null && File(path).existsSync()) return const SizedBox.shrink();
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [
              theme.effectiveBackground.withValues(alpha: 0.5),
              theme.backgroundColor,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientParticles(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerModel>();
    final path = theme.backgroundImagePath;
    if (!theme.particlesEnabled) return const SizedBox.shrink();
    if (!theme.autoColorEnabled) return const SizedBox.shrink();
    if (path != null && File(path).existsSync()) return const SizedBox.shrink();
    return Positioned.fill(
      child: AmbientParticles(
        theme: theme,
        isPlaying: player.playing,
      ),
    );
  }
}
