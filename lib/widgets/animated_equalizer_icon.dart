import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Icono animado de ecualizador con 5 barras que rebotan.
/// Se usa en el botón del Now Playing y en el header del EqualizerScreen.
class AnimatedEqualizerIcon extends StatefulWidget {
  final double size;
  final Color color;
  final bool animate;

  const AnimatedEqualizerIcon({
    super.key,
    this.size = 18,
    this.color = Colors.white,
    this.animate = true,
  });

  @override
  State<AnimatedEqualizerIcon> createState() => _AnimatedEqualizerIconState();
}

class _AnimatedEqualizerIconState extends State<AnimatedEqualizerIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.animate) {
      _ctrl.repeat();
    }
  }

  @override
  void didUpdateWidget(AnimatedEqualizerIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barCount = 5;
    final spacing = math.max(1.0, widget.size * 0.08);
    final barWidth = (widget.size - spacing * (barCount - 1)) / barCount;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _EqualizerBarPainter(
            barCount: barCount,
            barWidth: barWidth,
            spacing: spacing,
            color: widget.color,
            time: _ctrl.value * 2 * math.pi,
          ),
        );
      },
    );
  }
}

class _EqualizerBarPainter extends CustomPainter {
  final int barCount;
  final double barWidth;
  final double spacing;
  final Color color;
  final double time;

  _EqualizerBarPainter({
    required this.barCount,
    required this.barWidth,
    required this.spacing,
    required this.color,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = math.Random(42);

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing);

      // Frecuencia y fase diferentes por barra (simula ritmo)
      final freq = 2.0 + rng.nextDouble() * 2.0;
      final phase = rng.nextDouble() * 2 * math.pi;
      final wave = math.sin(time * freq + phase);

      // Altura: base 30% + onda 70%
      final normalizedHeight = 0.3 + (wave * 0.5 + 0.5) * 0.7;
      final barHeight = normalizedHeight * size.height;
      final radius = barWidth / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        Radius.circular(radius),
      );

      // Opacidad variable por barra
      final alpha = (0.5 + normalizedHeight * 0.5).clamp(0.0, 1.0);
      paint.color = color.withOpacity(alpha);

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_EqualizerBarPainter oldDelegate) =>
      oldDelegate.time != time;
}
