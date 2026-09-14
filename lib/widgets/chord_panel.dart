import 'package:chord_diagrams/chord_diagrams.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/theme_provider.dart';
import '../services/chord_service.dart';

enum ChordInstrument { guitar, ukulele, piano }

/// Botón que se ilumina si la canción tiene acordes disponibles.
class ChordPanel extends StatefulWidget {
  final String title;
  final String artist;
  const ChordPanel({super.key, required this.title, required this.artist});

  @override
  State<ChordPanel> createState() => _ChordPanelState();
}

class _ChordPanelState extends State<ChordPanel> {
  final ChordService _service = ChordService();
  bool? _hasChords;
  String? _lastKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _check();
  }

  @override
  void didUpdateWidget(ChordPanel old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title || old.artist != widget.artist) _check();
  }

  void _check() {
    final key = '${widget.artist}|||${widget.title}';
    if (key == _lastKey) return;
    _lastKey = key;
    _hasChords = null;
    _service.fetchChords(widget.title, widget.artist).then((chords) {
      if (mounted) setState(() => _hasChords = chords.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.effectiveAccent;
    final hasChords = _hasChords ?? false;
    final loading = _hasChords == null;

    return GestureDetector(
      onTap: () => _openSheet(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: hasChords
              ? Border.all(color: accent.withValues(alpha: 0.5), width: 1.2)
              : null,
          boxShadow: hasChords
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
          gradient: hasChords
              ? LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.12),
                    accent.withValues(alpha: 0.04),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: hasChords
              ? null
              : theme.isDarkMode
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
        ),
        child: Row(
          children: [
            // Icono con glow si tiene acordes
            hasChords
                ? Icon(Icons.music_note_rounded, size: 20, color: accent)
                : Icon(Icons.music_note_rounded,
                    size: 18, color: Colors.white24),
            const SizedBox(width: 10),
            Text(
              loading
                  ? 'Buscando acordes…'
                  : hasChords
                      ? 'Ver acordes'
                      : 'Sin acordes',
              style: TextStyle(
                color: hasChords
                    ? accent
                    : theme.isDarkMode
                        ? Colors.white38
                        : Colors.black38,
                fontSize: 13,
                fontWeight: hasChords ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const Spacer(),
            if (hasChords)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '♫',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (!loading)
              Icon(
                Icons.keyboard_arrow_up,
                size: 20,
                color: hasChords ? accent.withValues(alpha: 0.6) : Colors.white24,
              ),
          ],
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChordBottomSheet(title: widget.title, artist: widget.artist),
    );
  }
}

/// Bottom sheet con diagramas de acordes, rasgueo y selector de instrumento.
class _ChordBottomSheet extends StatefulWidget {
  final String title;
  final String artist;
  const _ChordBottomSheet({required this.title, required this.artist});

  @override
  State<_ChordBottomSheet> createState() => _ChordBottomSheetState();
}

class _ChordBottomSheetState extends State<_ChordBottomSheet> {
  final ChordService _service = ChordService();
  List<String> _chords = [];
  bool _loading = true;
  ChordInstrument _instrument = ChordInstrument.guitar;

  @override
  void initState() {
    super.initState();
    _service.fetchChords(widget.title, widget.artist).then((chords) {
      if (mounted) setState(() { _chords = chords; _loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.effectiveAccent;
    final bg = theme.isDarkMode ? const Color(0xFF141B26) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: theme.isDarkMode ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Row(
                children: [
                  Icon(Icons.music_note_rounded, size: 20, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Acordes',
                          style: TextStyle(
                            color: theme.isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${widget.title} – ${widget.artist}',
                          style: TextStyle(color: theme.isDarkMode ? Colors.white38 : Colors.black38, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Instrument selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip('Guitarra', ChordInstrument.guitar, accent, theme),
                  const SizedBox(width: 8),
                  _chip('Ukulele', ChordInstrument.ukulele, accent, theme),
                  const SizedBox(width: 8),
                  _chip('Piano', ChordInstrument.piano, accent, theme),
                ],
              ),
              const SizedBox(height: 20),
              // Content
              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  ),
                )
              else if (_chords.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.music_off, size: 40, color: theme.isDarkMode ? Colors.white24 : Colors.black26),
                        const SizedBox(height: 12),
                        Text(
                          'Acordes no disponibles',
                          style: TextStyle(color: theme.isDarkMode ? Colors.white38 : Colors.black38, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intenta con otra canción',
                          style: TextStyle(color: theme.isDarkMode ? Colors.white24 : Colors.black26, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Diagramas
                if (_instrument == ChordInstrument.piano)
                  _buildPiano(theme, accent)
                else
                  _buildDiagrams(theme, accent),
                const SizedBox(height: 24),
                // Rasgueo (solo guitarra/ukulele)
                if (_instrument != ChordInstrument.piano) ...[
                  _buildStrumSection(theme, accent),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, ChordInstrument value, Color accent, ThemeProvider theme) {
    final sel = _instrument == value;
    return GestureDetector(
      onTap: () => setState(() => _instrument = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? accent.withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? accent : Colors.white54,
            fontSize: 12,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  // ─── Diagramas de acordes ───

  Widget _buildDiagrams(ThemeProvider theme, Color accent) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chords.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final chord = _chords[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ChordDiagram(
                  chord: chord,
                  instrument: _instrument == ChordInstrument.ukulele
                      ? Instrument.ukulele
                      : Instrument.guitar,
                  position: 0,
                  width: 90,
                ),
              ),
              const SizedBox(height: 8),
              Text(chord, style: TextStyle(
                color: theme.isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 13, fontWeight: FontWeight.w600,
              )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPiano(ThemeProvider theme, Color accent) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chords.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final chord = _chords[index];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100, height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _PianoChordWidget(chord: chord, accent: accent, isDark: theme.isDarkMode),
              ),
              const SizedBox(height: 8),
              Text(chord, style: TextStyle(
                color: theme.isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 13, fontWeight: FontWeight.w600,
              )),
            ],
          );
        },
      ),
    );
  }

  // ─── Sección de rasgueo ───

  Widget _buildStrumSection(ThemeProvider theme, Color accent) {
    final isUkulele = _instrument == ChordInstrument.ukulele;
    final pattern = _service.getStrumPattern(_chords, isUkulele: isUkulele);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUkulele ? Icons.music_note : Icons.queue_music,
                size: 16,
                color: accent.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Rasgueo sugerido',
                style: TextStyle(
                  color: theme.isDarkMode ? Colors.white60 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Pattern visualization
          _StrumPatternWidget(pattern: pattern, accent: accent, isUkulele: isUkulele),
          const SizedBox(height: 12),
          // Pattern legend
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legendItem('↓', 'Down', accent, theme),
              _legendItem('↑', 'Up', accent, theme),
              _legendItem('X', 'Slap', accent, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String symbol, String label, Color accent, ThemeProvider theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(symbol, style: TextStyle(
          color: accent, fontSize: 16, fontWeight: FontWeight.w700,
        )),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
          color: theme.isDarkMode ? Colors.white38 : Colors.black38, fontSize: 11,
        )),
      ],
    );
  }
}

/// Widget que dibuja el patrón de rasgueo con flechas visuales.
class _StrumPatternWidget extends StatelessWidget {
  final String pattern;
  final Color accent;
  final bool isUkulele;
  const _StrumPatternWidget({required this.pattern, required this.accent, required this.isUkulele});

  @override
  Widget build(BuildContext context) {
    // Parsear: '↓' = down, '↑' = up, 'X' = slap, ' ' = pausa
    final strokes = <_Stroke>[];
    for (int i = 0; i < pattern.length; i++) {
      final ch = pattern[i];
      if (ch == '↓') {
        strokes.add(_Stroke(type: _StrokeType.down));
      } else if (ch == '↑') {
        strokes.add(_Stroke(type: _StrokeType.up));
      } else if (ch == 'X') {
        strokes.add(_Stroke(type: _StrokeType.slap));
      }
      // spaces = pausa, no stroke
    }

    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: strokes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final s = strokes[index];
          final isAccent = index % 4 == 0; // acento en tiempos fuertes
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isAccent
                      ? accent.withValues(alpha: 0.2)
                      : accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: isAccent
                      ? Border.all(color: accent.withValues(alpha: 0.4), width: 1)
                      : null,
                ),
                child: Center(
                  child: Icon(
                    s.type == _StrokeType.down
                        ? Icons.arrow_downward
                        : s.type == _StrokeType.up
                            ? Icons.arrow_upward
                            : Icons.close,
                    size: 18,
                    color: s.type == _StrokeType.slap
                        ? accent
                        : isAccent
                            ? accent
                            : accent.withValues(alpha: 0.5),
                  ),
                ),
              ),
              if (isAccent) ...[
                const SizedBox(height: 4),
                Container(
                  width: 4, height: 4,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum _StrokeType { down, up, slap }
class _Stroke { final _StrokeType type; const _Stroke({required this.type}); }

/// Widget de piano.
class _PianoChordWidget extends StatelessWidget {
  final String chord;
  final Color accent;
  final bool isDark;
  const _PianoChordWidget({required this.chord, required this.accent, this.isDark = true});

  static const _chordNotes = <String, List<int>>{
    'C': [0, 4, 7], 'D': [2, 6, 9], 'E': [4, 7, 11],
    'F': [5, 9, 12], 'G': [7, 11, 14], 'A': [9, 13, 16], 'B': [11, 15, 18],
    'Cm': [0, 3, 7], 'Dm': [2, 5, 9], 'Em': [4, 7, 11],
    'Fm': [5, 8, 12], 'Gm': [7, 10, 14], 'Am': [9, 12, 16], 'Bm': [11, 14, 18],
    'C7': [0, 4, 7, 10], 'D7': [2, 6, 9, 12], 'E7': [4, 7, 11, 14],
    'F7': [5, 9, 12, 15], 'G7': [7, 11, 14, 17], 'A7': [9, 13, 16, 19], 'B7': [11, 15, 18, 21],
  };

  @override
  Widget build(BuildContext context) {
    final notes = _chordNotes[chord] ?? [0, 4, 7];
    return CustomPaint(
      painter: _PianoPainter(activeNotes: notes, accent: accent, isDark: isDark),
      size: Size.infinite,
    );
  }
}

class _PianoPainter extends CustomPainter {
  final List<int> activeNotes;
  final Color accent;
  final bool isDark;
  _PianoPainter({required this.activeNotes, required this.accent, this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final wkc = 7;
    final wkw = size.width / wkc;
    final whiteKeys = [0, 2, 4, 5, 7, 9, 11];

    for (int i = 0; i < wkc; i++) {
      final x = i * wkw;
      final note = whiteKeys[i];
      final active = activeNotes.any((n) => (n % 12) == note);
      final paint = Paint()
        ..color = active ? accent.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 0, wkw - 2, size.height), const Radius.circular(4)),
        paint,
      );
    }

    final bkPos = [0.7, 1.7, 3.7, 4.7, 5.7];
    final bNotes = [1, 3, 6, 8, 10];
    for (int i = 0; i < bkPos.length; i++) {
      final x = bkPos[i] * wkw;
      final note = bNotes[i];
      final active = activeNotes.any((n) => (n % 12) == note);
      final paint = Paint()
        ..color = active ? accent.withValues(alpha: 0.9) : (isDark ? Colors.white.withValues(alpha: 0.18) : Colors.grey.withValues(alpha: 0.4))
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, 0, wkw * 0.6, size.height * 0.6), const Radius.circular(3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PianoPainter old) =>
      old.accent != accent || old.isDark != isDark ||
      old.activeNotes.length != activeNotes.length ||
      !_listEquals(old.activeNotes, activeNotes);

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
