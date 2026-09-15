import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/player_model.dart';
import '../widgets/animated_equalizer_icon.dart';

/// Preset del ecualizador con niveles predefinidos por banda.
class EqualizerPreset {
  final String name;
  final IconData icon;
  final List<double> gains; // -1.0 a 1.0 por cada banda
  const EqualizerPreset({required this.name, required this.icon, required this.gains});
}

const kEqualizerPresets = <EqualizerPreset>[
  EqualizerPreset(name: 'Plano', icon: Icons.horizontal_rule, gains: [0, 0, 0, 0, 0]),
  EqualizerPreset(name: 'Rock', icon: Icons.music_note, gains: [0.5, 0.3, -0.2, 0.3, 0.5]),
  EqualizerPreset(name: 'Pop', icon: Icons.star, gains: [-0.2, 0.3, 0.5, 0.3, -0.1]),
  EqualizerPreset(name: 'Jazz', icon: Icons.piano, gains: [0.3, 0.1, -0.1, 0.1, 0.3]),
  EqualizerPreset(name: 'Clásica', icon: Icons.theater_comedy, gains: [0.4, 0.2, -0.3, 0.2, 0.4]),
  EqualizerPreset(name: 'Bass Boost', icon: Icons.surround_sound, gains: [0.8, 0.4, 0.1, -0.1, -0.2]),
  EqualizerPreset(name: 'Agudos', icon: Icons.graphic_eq, gains: [-0.2, -0.1, 0.1, 0.4, 0.7]),
  EqualizerPreset(name: 'Voz', icon: Icons.record_voice_over, gains: [-0.3, 0.2, 0.6, 0.4, -0.1]),
  EqualizerPreset(name: 'Baile', icon: Icons.nightlife, gains: [0.6, 0.3, -0.1, 0.2, 0.5]),
  EqualizerPreset(name: 'Relajante', icon: Icons.spa, gains: [0.2, 0.1, -0.2, -0.1, -0.3]),
];

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  int _selectedPreset = 0;

  @override
  void initState() {
    super.initState();
    // Sincronizar el estado del ecualizador al abrir la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final theme = context.read<ThemeProvider>();
      final player = context.read<PlayerModel>();
      if (player.equalizer != null) {
        player.equalizer!.setEnabled(theme.equalizerEnabled);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerModel>();
    final textColor = theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;
    final accent = theme.effectiveAccent;
    final secondary = MelodiaColors.textSecondary;
    final equalizer = player.equalizer;

    if (!Platform.isAndroid || equalizer == null) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.backgroundColor,
          title: Text('Ecualizador', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Center(
          child: Text(
            'El ecualizador solo está disponible en Android.',
            style: TextStyle(color: secondary, fontSize: 14),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedEqualizerIcon(size: 24, color: accent, animate: player.playing),
            const SizedBox(width: 10),
            Text('Ecualizador',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
          ],
        ),
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: FutureBuilder<AndroidEqualizerParameters>(
        future: equalizer.parameters,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final params = snapshot.data!;
          final bands = params.bands;
          final minDb = params.minDecibels;
          final maxDb = params.maxDecibels;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // ── Toggle activar/desactivar ──
              Row(
                children: [
                  Icon(Icons.equalizer, color: accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Ecualizador activo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                  ),
                  Switch(
                    value: theme.equalizerEnabled,
                    onChanged: (v) {
                      theme.setEqualizerEnabled(v);
                      equalizer.setEnabled(v);
                    },
                    activeColor: accent,
                  ),
                ],
              ),
              if (!theme.equalizerEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(
                    'Activá el ecualizador para ajustar las bandas de audio.',
                    style: TextStyle(fontSize: 12, color: secondary),
                  ),
                ),
              const SizedBox(height: 16),

              // ── Mejora de sonido (LoudnessEnhancer) ──
              Row(
                children: [
                  Icon(Icons.hearing, color: accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mejorar sonido',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                        Text('Normaliza y amplifica el volumen',
                            style: TextStyle(fontSize: 11, color: secondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: player.soundEnhancement,
                    onChanged: (v) => player.setSoundEnhancement(v),
                    activeColor: accent,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Presets ──
              Opacity(
                opacity: theme.equalizerEnabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !theme.equalizerEnabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Presets',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kEqualizerPresets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final preset = kEqualizerPresets[i];
                    final selected = _selectedPreset == i;
                    return GestureDetector(
                      onTap: () => _applyPreset(preset, bands, minDb, maxDb, i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withValues(alpha: 0.2)
                              : MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? accent : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(preset.icon,
                                size: 22, color: selected ? accent : secondary),
                            const SizedBox(height: 6),
                            Text(
                              preset.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? accent : secondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
                    ], // children Column
                  ),
                ), // IgnorePointer
              ), // Opacity

              // ── Bandas ──
              Opacity(
                opacity: theme.equalizerEnabled ? 1.0 : 0.4,
                child: IgnorePointer(
                  ignoring: !theme.equalizerEnabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bandas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                      const SizedBox(height: 8),
                      Text(
                        'Deslizá para ajustar la ganancia de cada frecuencia.',
                        style: TextStyle(fontSize: 12, color: secondary),
                      ),
                      const SizedBox(height: 20),

                      // Sliders verticales
                      SizedBox(
                        height: 220,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(bands.length, (i) {
                            return _BandSlider(
                              band: bands[i],
                              minDb: minDb,
                              maxDb: maxDb,
                              accent: accent,
                              secondary: secondary,
                              onChanged: (gain) {
                                setState(() => _selectedPreset = -1);
                                bands[i].setGain(gain);
                              },
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Info ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'El ecualizador ajusta la ecuación de tono del audio. '
                  'Los cambios se aplican en tiempo real.',
                  style: TextStyle(fontSize: 12, color: secondary, height: 1.5),
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }

  void _applyPreset(EqualizerPreset preset, List<AndroidEqualizerBand> bands,
      double minDb, double maxDb, int index) {
    final range = maxDb - minDb;
    for (int i = 0; i < bands.length && i < preset.gains.length; i++) {
      final targetGain = minDb + (preset.gains[i] + 1.0) / 2.0 * range;
      bands[i].setGain(targetGain);
    }
    setState(() => _selectedPreset = index);
  }
}

class _BandSlider extends StatelessWidget {
  final AndroidEqualizerBand band;
  final double minDb;
  final double maxDb;
  final Color accent;
  final Color secondary;
  final ValueChanged<double> onChanged;

  const _BandSlider({
    required this.band,
    required this.minDb,
    required this.maxDb,
    required this.accent,
    required this.secondary,
    required this.onChanged,
  });

  String _freqLabel(double centerHz) {
    if (centerHz >= 1000) return '${(centerHz / 1000).toStringAsFixed(1)}k';
    return centerHz.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Frecuencia
        Text(
          _freqLabel(band.centerFrequency),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: secondary),
        ),
        const SizedBox(height: 8),
        // Slider vertical
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: StreamBuilder<double>(
              stream: band.gainStream,
              builder: (context, snapshot) {
                final currentGain = snapshot.data ?? 0.0;
                return Slider(
                  value: currentGain.clamp(minDb, maxDb),
                  min: minDb,
                  max: maxDb,
                  activeColor: accent,
                  inactiveColor: accent.withValues(alpha: 0.15),
                  onChanged: onChanged,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        // dB actual
        StreamBuilder<double>(
          stream: band.gainStream,
          builder: (context, snapshot) {
            final gain = snapshot.data ?? 0.0;
            return Text(
              '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}dB',
              style: TextStyle(
                fontSize: 10,
                color: gain.abs() < 0.5 ? secondary : accent,
                fontWeight: FontWeight.w500,
              ),
            );
          },
        ),
      ],
    );
  }
}
