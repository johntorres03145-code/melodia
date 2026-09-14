import 'package:flutter/material.dart';

/// Identidad visual MELODÍA — fuente única de verdad para el arte.
/// Base Midnight (nunca negro puro), violeta como acento de interacción,
/// gris para elementos inactivos y superficies sutiles de Midnight.
abstract final class MelodiaColors {
  static const midnight = Color(0xFF080B12);
  static const purpleDeep = Color(0xFF171126);
  static const electricViolet = Color(0xFF7C3AED);
  static const violetLight = Color(0xFFA855F7);
  static const magenta = Color(0xFFFF4DA6);
  static const cyan = Color(0xFF29B6F6);
  static const whiteSoft = Color(0xFFF5F5F7);
  /// Texto primario según modo oscuro/claro.
  static Color textColor(bool isDark) =>
      isDark ? whiteSoft : const Color(0xFF1A1A1A);

  /// Texto secundario — visible en ambos modos.
  static const textSecondary = Color(0xFFA1A1AA);
  static const textInactive = Color(0xFF666672);

  /// Superficies: variaciones muy sutiles de Midnight.
  static const surfaceBase = Color(0xFF0E131C);
  static const surfaceRaised = Color(0xFF141B26);

  /// Violeta → Magenta (identidad).
  static const linearGradientMain = LinearGradient(
    colors: [electricViolet, magenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Glow ambiental derivado de un color de portada.
  static List<BoxShadow> ambientGlow(Color color, {double alpha = 0.15}) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}