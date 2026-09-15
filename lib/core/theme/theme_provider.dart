import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'melodia_colors.dart';

/// Estilos disponibles para la barra de progreso de la canción.
enum ProgressBarStyle { thin, thick, rounded, minimal, gradient, glow, dots, ring, reveal, neon, wave, comic }

/// Paleta de colores para el estilo "Revelar".
class RevealPalette {
  final String name;
  final List<Color> colors;
  const RevealPalette({required this.name, required this.colors});
}

const kRevealPalettes = <RevealPalette>[
  RevealPalette(name: 'Océano', colors: [Color(0xFF0066FF), Color(0xFF00CEC8)]),
  RevealPalette(name: 'Atardecer', colors: [Color(0xFFFF6B6B), Color(0xFFFFD32A)]),
  RevealPalette(name: 'Bosque', colors: [Color(0xFF00B894), Color(0xFF6C5CE7)]),
  RevealPalette(name: 'Neón', colors: [Color(0xFFF72585), Color(0xFF7209B7)]),
  RevealPalette(name: 'Lava', colors: [Color(0xFFFF4500), Color(0xFFFFD700)]),
  RevealPalette(name: 'Aurora', colors: [Color(0xFF00F5D4), Color(0xFF7B61FF)]),
  RevealPalette(name: 'Rosa', colors: [Color(0xFFFF6B9D), Color(0xFFC44569)]),
  RevealPalette(name: 'Hielo', colors: [Color(0xFF74B9FF), Color(0xFF0984E3)]),
];

/// Temas predefinidos de MELOD♪A (seleccionables desde el perfil).
class PresetTheme {
  final String id;
  final String name;
  final Color accent;
  final Color background;
  final bool dark;
  const PresetTheme({
    required this.id,
    required this.name,
    required this.accent,
    required this.background,
    this.dark = true,
  });
}

const kPresetThemes = <PresetTheme>[
  PresetTheme(id: 'melodia', name: 'MELOD♪A', accent: MelodiaColors.violetLight, background: MelodiaColors.midnight),
  PresetTheme(id: 'violeta', name: 'Violeta', accent: MelodiaColors.violetLight, background: MelodiaColors.purpleDeep),
  PresetTheme(id: 'magenta', name: 'Magenta', accent: MelodiaColors.magenta, background: Color(0xFF140B18)),
  PresetTheme(id: 'cyan', name: 'Cyan', accent: MelodiaColors.cyan, background: Color(0xFF06121E)),
  PresetTheme(id: 'spotify', name: 'Spotify', accent: Color(0xFF1DB954), background: Color(0xFF0B0B0B)),
  PresetTheme(id: 'sunset', name: 'Atardecer', accent: Color(0xFFFF9E2C), background: Color(0xFF2B1055)),
  PresetTheme(id: 'forest', name: 'Bosque', accent: Color(0xFF55E6A4), background: Color(0xFF0F2417)),
  PresetTheme(id: 'neon', name: 'Neón', accent: Color(0xFFF72585), background: Color(0xFF10002B)),
  PresetTheme(id: 'light', name: 'Claro', accent: MelodiaColors.violetLight, background: Color(0xFFFAFAFA), dark: false),
  PresetTheme(id: 'light_coral', name: 'Claro Coral', accent: Color(0xFFE17055), background: Color(0xFFFFF7EC), dark: false),
  PresetTheme(id: 'light_ocean', name: 'Claro Océano', accent: Color(0xFF0984E3), background: Color(0xFFF2F4FF), dark: false),
  PresetTheme(id: 'light_forest', name: 'Claro Bosque', accent: Color(0xFF00B894), background: Color(0xFFEFFCF6), dark: false),
  PresetTheme(id: 'light_rose', name: 'Claro Rosa', accent: Color(0xFFE84393), background: Color(0xFFFDEEF3), dark: false),
];

const kAccentSwatches = <Color>[
  MelodiaColors.violetLight, MelodiaColors.electricViolet, MelodiaColors.magenta, MelodiaColors.cyan,
  Color(0xFF6C5CE7), Color(0xFF0984E3), Color(0xFF00CEC8), Color(0xFF1DB954),
  Color(0xFFFFD32A), Color(0xFFFF9E2C), Color(0xFFF72585), Color(0xFFE17055),
];

const kBackgroundSwatchesDark = <Color>[
  MelodiaColors.midnight, MelodiaColors.purpleDeep, Color(0xFF000000),
  Color(0xFF04202C), Color(0xFF0F2417), Color(0xFF2B1055),
];

const kBackgroundSwatchesLight = <Color>[
  Color(0xFFFFFFFF), Color(0xFFFAFAFA), Color(0xFFF2F4FF),
  Color(0xFFFFF7EC), Color(0xFFEFFCF6), Color(0xFFFDEEF3),
];

/// Controla lo personalizable de MELODÍA.
/// El sistema dinámico (color de portada) extrae la paleta de la portada
/// y aplica transiciones suaves a toda la interfaz.
class ThemeProvider extends ChangeNotifier {
  late Box _box;

  Color _accentColor = MelodiaColors.violetLight;
  Color _backgroundColor = MelodiaColors.midnight;
  String? _backgroundImagePath;
  bool _isDarkMode = true;
  bool _blurBackground = true;
  ProgressBarStyle _progressBarStyle = ProgressBarStyle.rounded;
  bool _showBarTimes = true;
  bool _crossfadeEnabled = false;
  int _crossfadeDuration = 5;
  int _revealPaletteIndex = 0;

  // ── Color dinámico ──
  bool _autoColorEnabled = false;
  Color _dominantColor = MelodiaColors.midnight;
  Color _vibrantColor = MelodiaColors.violetLight;
  double _backgroundImageOpacity = 0.4;
  int _particleIntensity = 1; // 0=sutil, 1=medio, 2=intenso
  bool _particlesEnabled = true;
  bool _equalizerEnabled = false;

  // ── Estado animado ──
  Color _animatedVibrant = MelodiaColors.violetLight;
  Color _animatedDominant = MelodiaColors.midnight;
  Timer? _colorAnimationTimer;

  // ── Getters públicos ──
  Color get accentColor => _accentColor;
  Color get backgroundColor => _backgroundColor;
  String? get backgroundImagePath => _backgroundImagePath;
  bool get isDarkMode => _isDarkMode;
  bool get blurBackground => _blurBackground;
  ProgressBarStyle get progressBarStyle => _progressBarStyle;
  bool get showBarTimes => _showBarTimes;
  bool get crossfadeEnabled => _crossfadeEnabled;
  int get crossfadeDuration => _crossfadeDuration;
  int get revealPaletteIndex => _revealPaletteIndex;
  RevealPalette get revealPalette => kRevealPalettes[_revealPaletteIndex];
  bool get autoColorEnabled => _autoColorEnabled;
  Color get dominantColor => _dominantColor;
  Color get vibrantColor => _vibrantColor;
  double get backgroundImageOpacity => _backgroundImageOpacity;
  int get particleIntensity => _particleIntensity;
  bool get particlesEnabled => _particlesEnabled;
  bool get equalizerEnabled => _equalizerEnabled;

  /// Color efectivo del accent — animado cuando el color dinámico cambia.
  Color get effectiveAccent => _autoColorEnabled ? _animatedVibrant : _accentColor;
  /// Color efectivo del fondo — animado cuando el color dinámico cambia.
  Color get effectiveBackground => _autoColorEnabled ? _animatedDominant : _backgroundColor;

  // ═══════════════════ INIT ═══════════════════

  Future<void> init(Box box) async {
    _box = box;
    final accent = box.get('accentColor');
    final bg = box.get('backgroundColor');
    final bgImage = box.get('backgroundImagePath');
    final dark = box.get('isDarkMode');
    final blur = box.get('blurBackground');
    final barStyle = box.get('progressBarStyle');
    final showTimes = box.get('showBarTimes');
    final crossfadeOn = box.get('crossfadeEnabled');
    final crossfadeDur = box.get('crossfadeDuration');
    final revealIdx = box.get('revealPaletteIndex');
    final autoColor = box.get('autoColorEnabled');
    final bgOpacity = box.get('backgroundImageOpacity');
    final particleInt = box.get('particleIntensity');
    final particlesOn = box.get('particlesEnabled');
    final eqOn = box.get('equalizerEnabled');

    if (accent != null) _accentColor = Color(accent);
    if (bg != null) _backgroundColor = Color(bg);
    if (bgImage != null) _backgroundImagePath = bgImage;
    if (dark != null) _isDarkMode = dark;
    if (blur != null) _blurBackground = blur;
    if (barStyle != null && barStyle is int && barStyle >= 0 && barStyle < ProgressBarStyle.values.length) {
      _progressBarStyle = ProgressBarStyle.values[barStyle];
    }
    if (showTimes != null) _showBarTimes = showTimes;
    if (crossfadeOn != null) _crossfadeEnabled = crossfadeOn;
    if (crossfadeDur != null && crossfadeDur is int && crossfadeDur >= 2 && crossfadeDur <= 12) {
      _crossfadeDuration = crossfadeDur;
    }
    if (revealIdx != null && revealIdx is int && revealIdx >= 0 && revealIdx < kRevealPalettes.length) {
      _revealPaletteIndex = revealIdx;
    }
    if (autoColor != null) _autoColorEnabled = autoColor as bool;
    if (bgOpacity != null && bgOpacity is double) _backgroundImageOpacity = bgOpacity;
    if (particleInt != null && particleInt is int && particleInt >= 0 && particleInt <= 2) {
      _particleIntensity = particleInt;
    }
    if (particlesOn != null) _particlesEnabled = particlesOn as bool;
    if (eqOn != null) _equalizerEnabled = eqOn as bool;

    _animatedVibrant = _vibrantColor;
    _animatedDominant = _dominantColor;
    notifyListeners();
  }

  // ═══════════════════ COLOR DINÁMICO ═══════════════════

  /// Extrae colores de la portada y anima la transición (~300ms, ~60fps).
  void setAutoColorFromArtwork(Color dominant, Color vibrant) {
    _colorAnimationTimer?.cancel();

    final oldAccent = _animatedVibrant;
    final oldDominant = _animatedDominant;
    final newAccent = _ensureContrast(vibrant);
    final newDominant = dominant;
    _vibrantColor = newAccent;
    _dominantColor = newDominant;

    const totalMs = 300;
    const stepMs = 16;
    final totalSteps = totalMs ~/ stepMs;
    var step = 0;

    _colorAnimationTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      step++;
      final t = Curves.easeInOut.transform(step / totalSteps);
      _animatedVibrant = Color.lerp(oldAccent, newAccent, t)!;
      _animatedDominant = Color.lerp(oldDominant, newDominant, t)!;
      notifyListeners();
      if (step >= totalSteps) timer.cancel();
    });

    notifyListeners();
  }

  void setAutoColorEnabled(bool enabled) {
    _autoColorEnabled = enabled;
    _box.put('autoColorEnabled', enabled);
    notifyListeners();
  }

  void setParticleIntensity(int intensity) {
    _particleIntensity = intensity.clamp(0, 2);
    _box.put('particleIntensity', _particleIntensity);
    notifyListeners();
  }

  void setParticlesEnabled(bool enabled) {
    _particlesEnabled = enabled;
    _box.put('particlesEnabled', enabled);
    notifyListeners();
  }

  void setEqualizerEnabled(bool enabled) {
    _equalizerEnabled = enabled;
    _box.put('equalizerEnabled', enabled);
    notifyListeners();
  }

  // ═══════════════════ CONTRASTE ═══════════════════

  /// Ajusta luminancia si el contraste contra el fondo es menor a 3.0.
  Color _ensureContrast(Color color) {
    final bgLum = _relativeLuminance(effectiveBackground);
    final fgLum = _relativeLuminance(color);
    final ratio = (max(fgLum, bgLum) + 0.05) / (min(fgLum, bgLum) + 0.05);
    if (ratio >= 3.0) return color;

    // Ajustar brillo hacia la dirección que más contraste dé
    final hsl = HSLColor.fromColor(color);
    final step = ratio < 2.0 ? 15.0 : 8.0;
    for (var i = 0; i < 20; i++) {
      final lighter = hsl.withLightness((hsl.lightness + step * i / 100).clamp(0, 1)).toColor();
      final darker = hsl.withLightness((hsl.lightness - step * i / 100).clamp(0, 1)).toColor();
      final rL = (max(_relativeLuminance(lighter), bgLum) + 0.05) / (min(_relativeLuminance(lighter), bgLum) + 0.05);
      final rD = (max(_relativeLuminance(darker), bgLum) + 0.05) / (min(_relativeLuminance(darker), bgLum) + 0.05);
      if (rL >= 3.0) return lighter;
      if (rD >= 3.0) return darker;
    }
    return color;
  }

  static double _relativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  static double _linearize(double c) => c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

  // ═══════════════════ SETTERS ═══════════════════

  Future<void> applyPreset(PresetTheme preset) async {
    _accentColor = preset.accent;
    _backgroundColor = preset.background;
    _isDarkMode = preset.dark;
    await _save();
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _box.put('accentColor', color.toARGB32());
    notifyListeners();
  }

  Future<void> setBackgroundColor(Color color) async {
    _backgroundColor = color;
    await _box.put('backgroundColor', color.toARGB32());
    notifyListeners();
  }

  Future<void> setBackgroundImage(String? path) async {
    _backgroundImagePath = path;
    if (path != null) {
      await _box.put('backgroundImagePath', path);
    } else {
      await _box.delete('backgroundImagePath');
    }
    notifyListeners();
  }

  Future<void> setBackgroundImagePath(String? path) => setBackgroundImage(path);

  Future<void> setBlurBackground(bool value) async {
    _blurBackground = value;
    await _box.put('blurBackground', value);
    notifyListeners();
  }

  Future<void> toggleDarkMode(bool value) async {
    _isDarkMode = value;
    if (value) {
      _backgroundColor = MelodiaColors.midnight;
    } else {
      _backgroundColor = const Color(0xFFFAFAFA);
    }
    await _box.put('isDarkMode', value);
    await _box.put('backgroundColor', _backgroundColor.toARGB32());
    notifyListeners();
  }

  Future<void> setProgressBarStyle(ProgressBarStyle style) async {
    _progressBarStyle = style;
    await _box.put('progressBarStyle', style.index);
    notifyListeners();
  }

  Future<void> setShowBarTimes(bool value) async {
    _showBarTimes = value;
    await _box.put('showBarTimes', value);
    notifyListeners();
  }

  Future<void> setCrossfadeEnabled(bool value) async {
    _crossfadeEnabled = value;
    await _box.put('crossfadeEnabled', value);
    notifyListeners();
  }

  Future<void> setCrossfadeDuration(int seconds) async {
    _crossfadeDuration = seconds.clamp(2, 12);
    await _box.put('crossfadeDuration', _crossfadeDuration);
    notifyListeners();
  }

  Future<void> setRevealPaletteIndex(int index) async {
    if (index < 0 || index >= kRevealPalettes.length) return;
    _revealPaletteIndex = index;
    await _box.put('revealPaletteIndex', index);
    notifyListeners();
  }

  Future<void> setBackgroundImageOpacity(double value) async {
    _backgroundImageOpacity = value.clamp(0.0, 1.0);
    await _box.put('backgroundImageOpacity', _backgroundImageOpacity);
    notifyListeners();
  }

  Future<void> _save() async {
    await _box.put('accentColor', _accentColor.toARGB32());
    await _box.put('backgroundColor', _backgroundColor.toARGB32());
    await _box.put('isDarkMode', _isDarkMode);
    await _box.put('crossfadeEnabled', _crossfadeEnabled);
    await _box.put('crossfadeDuration', _crossfadeDuration);
    await _box.put('revealPaletteIndex', _revealPaletteIndex);
    await _box.put('autoColorEnabled', _autoColorEnabled);
  }
}
