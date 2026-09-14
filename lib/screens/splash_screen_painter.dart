import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/melodia_colors.dart';

/// Painter personalizado para la animación de splash de MELOD♪A.
///
/// Fases de la animación (progreso 0→1):
///  - 0.00→0.25: Círculo + corchete musical aparecen (fade+scale)
///  - 0.20→0.45: Círculo se encoge a la mitad, ondas salen
///  - 0.35→0.75: Arco de colores se pinta alrededor (pincelada)
///  - 0.65→0.85: Texto "MELOD♪A" aparece (fade+slide)
///  - 0.85→1.00: Todo se desvanece
class SplashScreenPainter extends CustomPainter {
  final double progress;

  SplashScreenPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final baseRadius = size.width * 0.18;

    // ── FASE 1: Círculo + corchete aparecen ──
    final appearProgress = _clamp(0.0, 0.25, progress);
    final appearOpacity = _easeOut(appearProgress);
    final appearScale = 0.5 + 0.5 * _easeOutBack(appearProgress);

    // ── FASE 2: Círculo se encoge + ondas ──
    final shrinkProgress = _clamp(0.20, 0.45, progress);
    final shrinkFactor = 1.0 - 0.5 * _easeInOut(shrinkProgress);
    final circleRadius = baseRadius * appearScale * shrinkFactor;

    // Ondas emanando
    final waveProgress = _clamp(0.20, 0.55, progress);

    // ── FASE 3: Arco de colores ──
    final arcProgress = _clamp(0.35, 0.75, progress);

    // ── FASE 4: Texto aparece ──
    final textProgress = _clamp(0.65, 0.85, progress);

    // ── FASE 5: Desvanecer ──
    final fadeOutProgress = _clamp(0.85, 1.0, progress);
    final fadeOut = 1.0 - _easeIn(fadeOutProgress);

    canvas.save();
    canvas.translate(cx, cy);

    // ── Dibujar ondas emanantes ──
    if (waveProgress > 0 && fadeOut > 0) {
      _drawWaves(canvas, circleRadius, waveProgress, fadeOut);
    }

    // ── Dibujar arco de colores ──
    if (arcProgress > 0 && fadeOut > 0) {
      _drawColoredArc(canvas, circleRadius, arcProgress, fadeOut);
    }

    // ── Dibujar círculo base ──
    if (appearOpacity > 0 && fadeOut > 0) {
      final circlePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 * appearOpacity * fadeOut)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset.zero, circleRadius, circlePaint);

      final fillPaint = Paint()
        ..color = MelodiaColors.midnight.withValues(alpha: 0.6 * appearOpacity * fadeOut)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, circleRadius, fillPaint);
    }

    // ── Dibujar corchete musical (♪) ──
    if (appearOpacity > 0 && fadeOut > 0) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '♪',
          style: TextStyle(
            fontSize: circleRadius * 1.3,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: appearOpacity * fadeOut),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
    }

    // ── Dibujar texto "MELOD♪A" ──
    if (textProgress > 0 && fadeOut > 0) {
      final textOpacity = _easeOut(textProgress) * fadeOut;
      final slideY = 20.0 * (1.0 - _easeOut(textProgress));

      final titlePainter = TextPainter(
        text: TextSpan(
          text: 'MELOD',
          style: TextStyle(
            fontSize: size.width * 0.08,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: textOpacity),
            letterSpacing: 3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final notePainter = TextPainter(
        text: TextSpan(
          text: '♪',
          style: TextStyle(
            fontSize: size.width * 0.09,
            fontWeight: FontWeight.w700,
            color: MelodiaColors.violetLight.withValues(alpha: textOpacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final lastPainter = TextPainter(
        text: TextSpan(
          text: 'A',
          style: TextStyle(
            fontSize: size.width * 0.08,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: textOpacity),
            letterSpacing: 3,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final totalW = titlePainter.width + notePainter.width + lastPainter.width;
      final startX = -totalW / 2;
      final textY = circleRadius + size.height * 0.08 + slideY;

      titlePainter.paint(canvas, Offset(startX, textY));
      notePainter.paint(canvas, Offset(startX + titlePainter.width, textY - 2));
      lastPainter.paint(canvas, Offset(startX + titlePainter.width + notePainter.width, textY));
    }

    canvas.restore();
  }

  void _drawWaves(Canvas canvas, double circleRadius, double waveProgress, double fadeOut) {
    for (int i = 0; i < 3; i++) {
      final delay = i * 0.15;
      final p = _clamp(delay, delay + 0.4, waveProgress);
      if (p <= 0) continue;

      final expandRadius = circleRadius + circleRadius * 1.5 * _easeOut(p);
      final alpha = (1.0 - _easeIn(p)) * 0.25 * fadeOut;

      final wavePaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset.zero, expandRadius, wavePaint);
    }
  }

  void _drawColoredArc(Canvas canvas, double circleRadius, double arcProgress, double fadeOut) {
    final arcRadius = circleRadius * 1.6;
    final rect = Rect.fromCircle(center: Offset.zero, radius: arcRadius);

    const startAngle = math.pi * 0.65;
    const totalSweep = math.pi * 1.22;
    final currentSweep = totalSweep * _easeInOut(arcProgress);

    final colors = [
      MelodiaColors.electricViolet,
      MelodiaColors.magenta,
      MelodiaColors.cyan,
      MelodiaColors.violetLight,
      MelodiaColors.electricViolet,
    ];

    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        colors: colors,
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = arcRadius * 0.18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, currentSweep, false, arcPaint);

    if (arcProgress < 0.95) {
      final tipAngle = startAngle + currentSweep;
      final tipX = math.cos(tipAngle) * arcRadius;
      final tipY = math.sin(tipAngle) * arcRadius;

      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.6 * fadeOut)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(tipX, tipY), arcRadius * 0.08, glowPaint);
    }

    final highlightPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle + 0.3,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = arcRadius * 0.08
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle + 0.1, currentSweep * 0.6, false, highlightPaint);
  }

  double _clamp(double min, double max, double value) {
    if (value <= min) return 0.0;
    if (value >= max) return 1.0;
    return (value - min) / (max - min);
  }

  double _easeOut(double t) => t * (2.0 - t);
  double _easeIn(double t) => t * t;
  double _easeInOut(double t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

  double _easeOutBack(double t) {
    const s = 1.70158;
    return 1 + (--t) * t * ((s + 1) * t + s);
  }

  @override
  bool shouldRepaint(SplashScreenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
