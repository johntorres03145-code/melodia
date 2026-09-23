import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';
import '../models/library_model.dart';
import '../models/player_model.dart';
import 'about_screen.dart';
import 'equalizer_screen.dart';
import 'hidden_songs_screen.dart';

/// Perfil: personalización visual completa (temas, acento, fondo, etc.).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Text(
            'Perfil',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: MelodiaColors.textColor(theme.isDarkMode),
                ),
          ),
          const SizedBox(height: 24),
          _avatar(theme),
          const SizedBox(height: 24),
          _CollapsibleCard(
            title: 'Tema',
            icon: Icons.palette_outlined,
            initiallyExpanded: true,
            children: [
              _presetChips(context, theme),
              const SizedBox(height: 20),
              _sectionLabel('Color de acento'),
              const SizedBox(height: 10),
              _accentSwatches(context, theme),
              const SizedBox(height: 20),
              _sectionLabel('Fondo'),
              const SizedBox(height: 10),
              _backgroundSwatches(context, theme),
              const SizedBox(height: 8),
              _backgroundImageOption(context, theme),
            ],
          ),
          const SizedBox(height: 12),
          _CollapsibleCard(
            title: 'Audio',
            icon: Icons.tune,
            children: [
              _crossfadeSettings(context, theme),
              const SizedBox(height: 16),
              _equalizerEntry(context, theme),
              const SizedBox(height: 16),
              _sectionLabel('Barra de progreso'),
              const SizedBox(height: 10),
              _progressStyle(theme),
            ],
          ),
          const SizedBox(height: 12),
          _CollapsibleCard(
            title: 'Apariencia',
            icon: Icons.visibility_outlined,
            children: [
              _switches(context, theme),
            ],
          ),
          const SizedBox(height: 12),
          _CollapsibleCard(
            title: 'Otros',
            icon: Icons.more_horiz,
            children: [
              _hiddenSongsEntry(context, theme),
              const SizedBox(height: 4),
              _aboutEntry(context, theme),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _avatar(ThemeProvider theme) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: MelodiaColors.linearGradientMain,
          ),
          child: Icon(Icons.person, size: 34, color: theme.isDarkMode ? Colors.white70 : Colors.black54),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Melodía',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MelodiaColors.textColor(theme.isDarkMode)),
            ),
            const SizedBox(height: 2),
            const Text(
              'Escucha lo que amas · sin límites',
              style: TextStyle(
                  fontSize: 12, color: MelodiaColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: MelodiaColors.textSecondary,
      ),
    );
  }

  Widget _presetChips(BuildContext context, ThemeProvider theme) {
    final darkThemes = kPresetThemes.where((t) => t.dark).toList();
    final lightThemes = kPresetThemes.where((t) => !t.dark).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Oscuros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: MelodiaColors.textSecondary)),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: darkThemes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final preset = darkThemes[i];
              final isSelected = theme.effectiveAccent == preset.accent && theme.backgroundColor == preset.background;
              return ChoiceChip(
                label: Text(preset.name),
                selected: isSelected,
                onSelected: (_) => theme.applyPreset(preset),
                selectedColor: theme.effectiveAccent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.black : MelodiaColors.textSecondary,
                ),
                side: BorderSide.none,
                backgroundColor: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text('Claros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: MelodiaColors.textSecondary)),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: lightThemes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final preset = lightThemes[i];
              final isSelected = theme.effectiveAccent == preset.accent && theme.backgroundColor == preset.background;
              return ChoiceChip(
                label: Text(preset.name),
                selected: isSelected,
                onSelected: (_) => theme.applyPreset(preset),
                selectedColor: theme.effectiveAccent,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.black : MelodiaColors.textSecondary,
                ),
                side: BorderSide.none,
                backgroundColor: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _accentSwatches(BuildContext context, ThemeProvider theme) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in kAccentSwatches)
          _colorDot(
            color: color,
            selected: theme.effectiveAccent == color,
            isDark: theme.isDarkMode,
            onTap: () => theme.setAccentColor(color),
          ),
      ],
    );
  }

  Widget _backgroundSwatches(BuildContext context, ThemeProvider theme) {
    final swatches =
        theme.isDarkMode ? kBackgroundSwatchesDark : kBackgroundSwatchesLight;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in swatches)
          _colorDot(
            color: color,
            selected: theme.backgroundColor == color,
            isDark: theme.isDarkMode,
            onTap: () => theme.setBackgroundColor(color),
          ),
      ],
    );
  }

  Widget _colorDot({
    required Color color,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : (isDark ? Colors.white24 : Colors.black26),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, size: 18, color: Colors.black)
            : null,
      ),
    );
  }

  Widget _switches(BuildContext context, ThemeProvider theme) {
    return Column(
      children: [
        _switchRow(
          context,
          title: 'Modo oscuro',
          value: theme.isDarkMode,
          onChanged: theme.toggleDarkMode,
        ),
        _switchRow(
          context,
          title: 'Desenfocar portadas (blur)',
          value: theme.blurBackground,
          onChanged: theme.setBlurBackground,
        ),
        _switchRow(
          context,
          title: 'Color dinámico de portada',
          value: theme.autoColorEnabled,
          onChanged: theme.setAutoColorEnabled,
        ),
        _switchRow(
          context,
          title: 'Partículas animadas',
          value: theme.particlesEnabled,
          onChanged: theme.setParticlesEnabled,
        ),
        if (theme.particlesEnabled) ...[
          const SizedBox(height: 10),
          _particleIntensitySelector(context, theme),
        ],
        _switchRow(
          context,
          title: 'Mostrar tiempos en la barra',
          value: theme.showBarTimes,
          onChanged: theme.setShowBarTimes,
        ),
      ],
    );
  }

  Widget _switchRow(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = context.watch<ThemeProvider>();
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
                fontSize: 14, color: MelodiaColors.textColor(theme.isDarkMode)),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: Theme.of(context).colorScheme.surface,
        ),
      ],
    );
  }

  Widget _progressStyle(ThemeProvider theme) {
    final labels = const ['Fina', 'Gruesa', 'Redonda', 'Mínima', 'Gradiente', 'Glow', 'Puntos', 'Anillo', 'Revelar', 'Neón', 'Ondas', 'Cómic'];
    return Column(
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < labels.length; i++)
              ChoiceChip(
                label: Text(labels[i]),
                selected: theme.progressBarStyle.index == i,
                onSelected: (_) =>
                    theme.setProgressBarStyle(ProgressBarStyle.values[i]),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: theme.progressBarStyle.index == i
                      ? Colors.black
                      : MelodiaColors.textSecondary,
                ),
                selectedColor: theme.effectiveAccent,
                backgroundColor: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                side: BorderSide.none,
              ),
          ],
        ),
        if (theme.progressBarStyle == ProgressBarStyle.reveal) ...[
          const SizedBox(height: 14),
          _sectionLabel('Paleta de colores (Revelar)'),
          const SizedBox(height: 8),
          _revealPaletteChips(theme),
        ],
      ],
    );
  }

  Widget _revealPaletteChips(ThemeProvider theme) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kRevealPalettes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = kRevealPalettes[i];
          final selected = theme.revealPaletteIndex == i;
          return ChoiceChip(
            label: Text(p.name),
            selected: selected,
            onSelected: (_) => theme.setRevealPaletteIndex(i),
            labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? Colors.black : MelodiaColors.textSecondary,
            ),
            selectedColor: p.colors.first,
            backgroundColor: MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
            side: BorderSide.none,
          );
        },
      ),
    );
  }

  Widget _crossfadeSettings(BuildContext context, ThemeProvider theme) {
    return const SizedBox.shrink();
    // ignore: dead_code
    final player = context.read<PlayerModel>();
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Crossfade',
                style: TextStyle(
                    fontSize: 14, color: MelodiaColors.textColor(theme.isDarkMode)),
              ),
            ),
            Switch(
              value: theme.crossfadeEnabled,
              onChanged: (v) {
                theme.setCrossfadeEnabled(v);
                player.setCrossfadeEnabled(v, theme.crossfadeDuration);
              },
              activeTrackColor: Theme.of(context).colorScheme.surface,
            ),
          ],
        ),
        if (theme.crossfadeEnabled) ...[
          const SizedBox(height: 10),
          Text(
            'Duración: ${theme.crossfadeDuration}s',
            style: const TextStyle(fontSize: 13, color: MelodiaColors.textSecondary),
          ),
          Slider(
            value: theme.crossfadeDuration.toDouble(),
            min: 2,
            max: 12,
            divisions: 10,
            activeColor: theme.effectiveAccent,
            inactiveColor: theme.effectiveAccent.withValues(alpha: 0.15),
            onChanged: (v) {
              theme.setCrossfadeDuration(v.round());
              player.setCrossfadeDuration(v.round());
            },
          ),
        ],
      ],
    );
  }

  Widget _hiddenSongsEntry(BuildContext context, ThemeProvider theme) {
    final library = context.watch<LibraryModel>();
    final count = library.hiddenIds.length;
    return ListTile(
      leading: Icon(Icons.visibility_off, color: theme.effectiveAccent),
      title: Text(
        'Canciones ocultas',
        style: TextStyle(fontSize: 14, color: MelodiaColors.textColor(theme.isDarkMode)),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.effectiveAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 12, color: theme.effectiveAccent)),
            ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: MelodiaColors.textColor(theme.isDarkMode)),
        ],
      ),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const HiddenSongsScreen(),
        ));
      },
    );
  }

  Widget _particleIntensitySelector(BuildContext context, ThemeProvider theme) {
    final labels = ['Sutil', 'Medio', 'Intenso'];
    return Row(
      children: List.generate(3, (i) {
        final selected = theme.particleIntensity == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => theme.setParticleIntensity(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? theme.effectiveAccent.withValues(alpha: 0.2)
                    : MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? theme.effectiveAccent
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? theme.effectiveAccent
                        : MelodiaColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _equalizerEntry(BuildContext context, ThemeProvider theme) {
    final accent = theme.effectiveAccent;
    final secondary = MelodiaColors.textSecondary;
    return ListTile(
      leading: Icon(Icons.equalizer, color: accent),
      title: const Text('Ecualizador'),
      subtitle: Text('Ajustar bandas y presets', style: TextStyle(color: secondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right, color: secondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EqualizerScreen()),
        );
      },
    );
  }

  Widget _aboutEntry(BuildContext context, ThemeProvider theme) {
    return ListTile(
      leading: Icon(Icons.info_outline, color: theme.effectiveAccent),
      title: Text(
        'Acerca de MELOD♪A',
        style: TextStyle(fontSize: 14, color: MelodiaColors.textColor(theme.isDarkMode)),
      ),
      trailing: Icon(Icons.chevron_right, color: MelodiaColors.textColor(theme.isDarkMode)),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => const AboutScreen(),
        ));
      },
    );
  }

  Widget _backgroundImageOption(BuildContext context, ThemeProvider theme) {
    final hasImage = theme.backgroundImagePath != null;
    return Column(
      children: [
        ListTile(
          leading: Icon(
            hasImage ? Icons.image : Icons.add_photo_alternate_outlined,
            color: theme.effectiveAccent,
          ),
          title: Text(
            hasImage ? 'Cambiar imagen de fondo' : 'Elegir imagen de fondo',
            style: TextStyle(fontSize: 14, color: MelodiaColors.textColor(theme.isDarkMode)),
          ),
          subtitle: hasImage
              ? const Text('Toque para cambiar', style: TextStyle(fontSize: 11, color: MelodiaColors.textInactive))
              : null,
          trailing: hasImage
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => theme.setBackgroundImagePath(null),
                )
              : Icon(Icons.chevron_right, color: MelodiaColors.textColor(theme.isDarkMode)),
          onTap: () async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (picked != null) {
              theme.setBackgroundImagePath(picked.path);
            }
          },
        ),
        if (hasImage) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.brightness_low, size: 16, color: MelodiaColors.textInactive),
                Expanded(
                  child: Slider(
                    value: theme.backgroundImageOpacity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    activeColor: theme.effectiveAccent,
                    inactiveColor: theme.effectiveAccent.withValues(alpha: 0.15),
                    onChanged: theme.setBackgroundImageOpacity,
                  ),
                ),
                const Icon(Icons.brightness_high, size: 16, color: MelodiaColors.textInactive),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Widget reutilizable: Card colapsable con animación
// ═══════════════════════════════════════════════════════════════════

class _CollapsibleCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _CollapsibleCard({
    required this.title,
    required this.icon,
    this.initiallyExpanded = false,
    required this.children,
  });

  @override
  State<_CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<_CollapsibleCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _controller;
  late Animation<double> _iconRotation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
      value: _expanded ? 1.0 : 0.0,
    );
    _iconRotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final accent = theme.effectiveAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: MelodiaColors.surfaceBaseFor(theme.isDarkMode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? accent.withValues(alpha: 0.3)
              : MelodiaColors.surfaceRaisedFor(theme.isDarkMode),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(widget.icon, size: 20, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: MelodiaColors.textColor(isDark),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _iconRotation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _iconRotation.value * 3.14159,
                        child: Icon(
                          Icons.keyboard_arrow_up,
                          size: 20,
                          color: MelodiaColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: widget.children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
