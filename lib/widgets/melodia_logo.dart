import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/melodia_colors.dart';

/// Logo de MELOD♪A: la nota musical ♪ con semicírculo multicolor tipo pincelada.
class MelodiaLogo extends StatelessWidget {
  final double fontSize;
  final Color color;
  final FontWeight fontWeight;
  final double letterSpacing;

  const MelodiaLogo({
    super.key,
    this.fontSize = 34,
    this.color = Colors.white,
    this.fontWeight = FontWeight.w600,
    this.letterSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final arcRadius = fontSize * 0.72;
    final noteSize = fontSize * 0.9;

    return SizedBox(
      width: fontSize * 1.9,
      height: fontSize * 1.3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Semicírculo multicolor (pincelada)
          CustomPaint(
            size: Size(fontSize * 1.9, fontSize * 1.3),
            painter: _BrushArcPainter(
              radius: arcRadius,
              color: color,
            ),
          ),
          // Nota ♪
          Text(
            '♪',
            style: TextStyle(
              fontSize: noteSize,
              fontWeight: fontWeight,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrushArcPainter extends CustomPainter {
  final double radius;
  final Color color;

  _BrushArcPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + radius * 0.15);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Arco de 220° que rodea la nota desde abajo-izquierda hasta abajo-derecha
    const startAngle = math.pi * 0.65; // ~117°
    const sweepAngle = math.pi * 1.22;  // ~220°

    // Gradiente principal: violeta → magenta → cyan
    final gradientPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        colors: const [
          MelodiaColors.electricViolet,
          MelodiaColors.violetLight,
          MelodiaColors.magenta,
          MelodiaColors.cyan,
          MelodiaColors.electricViolet,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.26
      ..strokeCap = StrokeCap.round;

    // Primera pasada: arco base
    canvas.drawArc(rect, startAngle, sweepAngle, false, gradientPaint);

    // Segunda pasada: brillo sutil (simula pincelada con más opacidad)
    final highlightPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle + 0.3,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle + 0.1, sweepAngle * 0.6, false, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BrushArcPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
