import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/theme_provider.dart';

/// Partículas ambientales sutiles que aparecen cuando el Color Dinámico está activo.
/// Se integran con el Ambient Glow y respetan la intensidad seleccionada.
class AmbientParticles extends StatefulWidget {
  final ThemeProvider theme;
  final bool isPlaying;

  const AmbientParticles({
    super.key,
    required this.theme,
    this.isPlaying = true,
  });

  @override
  State<AmbientParticles> createState() => _AmbientParticlesState();
}

class _AmbientParticlesState extends State<AmbientParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _generateParticles();
  }

  @override
  void didUpdateWidget(AmbientParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.theme.particleIntensity != oldWidget.theme.particleIntensity) {
      _generateParticles();
    }
  }

  void _generateParticles() {
    final count = _countForIntensity(widget.theme.particleIntensity);
    _particles = List.generate(count, (_) => _Particle.random(_rng));
  }

  int _countForIntensity(int intensity) {
    switch (intensity) {
      case 0: return 8;
      case 1: return 15;
      case 2: return 25;
      default: return 15;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.theme.autoColorEnabled) return const SizedBox.shrink();

    final accent = widget.theme.effectiveAccent;
    final opacityBase = _opacityForIntensity(widget.theme.particleIntensity);
    final speed = widget.isPlaying ? 1.0 : 0.3;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(
            particles: _particles,
            color: accent,
            opacityBase: opacityBase,
            time: _ctrl.value * 2 * pi * speed,
            isPlaying: widget.isPlaying,
          ),
        );
      },
    );
  }

  double _opacityForIntensity(int intensity) {
    switch (intensity) {
      case 0: return 0.08;
      case 1: return 0.15;
      case 2: return 0.25;
      default: return 0.15;
    }
  }
}

/// Modelo de una partícula individual.
class _Particle {
  double x;      // 0.0 - 1.0 (posición normalizada)
  double y;
  double radius; // tamaño relativo
  double speed;  // velocidad de movimiento
  double phase;  // fase inicial para seno/coseno
  double drift;  // amplitud de deriva

  _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.drift,
  });

  factory _Particle.random(Random rng) {
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: 2.0 + rng.nextDouble() * 4.0,
      speed: 0.3 + rng.nextDouble() * 0.7,
      phase: rng.nextDouble() * 2 * pi,
      drift: 5.0 + rng.nextDouble() * 15.0,
    );
  }
}

/// Painter que dibuja las partículas con movimiento orgánico.
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Color color;
  final double opacityBase;
  final double time;
  final bool isPlaying;

  _ParticlePainter({
    required this.particles,
    required this.color,
    required this.opacityBase,
    required this.time,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Movimiento orgánico con seno/coseno
      final dx = sin(time * p.speed + p.phase) * p.drift;
      final dy = cos(time * p.speed * 0.7 + p.phase * 1.3) * p.drift * 0.6;

      final cx = p.x * size.width + dx;
      final cy = p.y * size.height + dy;

      // Opacidad con variación sutil
      final opacityVar = (sin(time * 0.5 + p.phase) * 0.3 + 0.7);
      final alpha = (opacityBase * opacityVar).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

      canvas.drawCircle(Offset(cx, cy), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.color != color;
}
