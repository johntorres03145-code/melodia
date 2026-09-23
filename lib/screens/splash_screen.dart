import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import 'main_scaffold.dart';
import 'splash_screen_painter.dart';

/// Pantalla de animación de entrada de MELOD♪A.
///
/// Se muestra en primera instalación y cuando la app lleva 4+ horas sin abrirse.
/// La animación dura ~4.5 segundos y luego navega al HomeScreen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Determina si se debe mostrar el splash.
  /// Retorna true si es primera vez o si pasaron 4+ horas desde la última apertura.
  static bool shouldShow(Box settings) {
    final lastOpen = settings.get('lastOpenTime') as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSince = (now - lastOpen) / (1000 * 60 * 60);
    return hoursSince >= 4;
  }

  /// Guarda el timestamp de apertura actual.
  static void markOpened(Box settings) {
    settings.put('lastOpenTime', DateTime.now().millisecondsSinceEpoch);
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeBg;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Fade del fondo: de negro a transparente al inicio, luego permanece
    _fadeBg = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.1, curve: Curves.easeOut),
      ),
    );

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _ctrl.forward();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const MainScaffold(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToHome,
      child: Scaffold(
        backgroundColor: MelodiaColors.midnight,
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomPaint(
              size: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
              painter: SplashScreenPainter(progress: _ctrl.value),
            );
          },
        ),
      ),
    );
  }
}
