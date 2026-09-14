import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final textColor = theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;
    final accent = theme.effectiveAccent;
    final secondary = MelodiaColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        title: Text('Acerca de',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Logo + nombre ──
          Center(
            child: Column(
              children: [
                Image.asset('assets/images/icon.png', width: 72, height: 72),
                const SizedBox(height: 12),
                Text('MELOD♪A',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
                const SizedBox(height: 4),
                Text('v1.1.0', style: TextStyle(fontSize: 14, color: secondary)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── Créditos ──
          _sectionTitle('Créditos', textColor),
          const SizedBox(height: 8),
          Text(
            'Desarrollado con Flutter.\n'
            'Audio: just_audio + audio_service.\n'
            'YouTube: YouTube Data API v3 + youtube_explode_dart.',
            style: TextStyle(fontSize: 13, height: 1.5, color: secondary),
          ),
          const SizedBox(height: 28),

          // ── Política de Privacidad ──
          _sectionTitle('Política de Privacidad', textColor),
          const SizedBox(height: 8),
          _privacyPolicy(textColor),
          const SizedBox(height: 28),

          // ── Términos y políticas externas ──
          _sectionTitle('Términos y Políticas', textColor),
          const SizedBox(height: 8),
          _linkButton(
            context,
            label: 'Términos de Servicio de YouTube',
            url: 'https://www.youtube.com/t/terms',
            accent: accent,
          ),
          const SizedBox(height: 4),
          _linkButton(
            context,
            label: 'Política de Privacidad de Google',
            url: 'https://policies.google.com/privacy',
            accent: accent,
          ),
          const SizedBox(height: 28),

          // ── Botón → YouTube API Services ──
          _sectionTitle('Servicios de YouTube', textColor),
          const SizedBox(height: 8),
          Text(
            'Información sobre el uso de YouTube API Services en esta aplicación.',
            style: TextStyle(fontSize: 13, height: 1.5, color: secondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const YouTubeApiScreen()),
                );
              },
              icon: Icon(Icons.arrow_forward_ios, size: 16, color: accent),
              label: Text('YouTube API Services', style: TextStyle(color: accent)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: accent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
    );
  }

  Widget _linkButton(BuildContext context,
      {required String label, required String url, required Color accent}) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 16, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: accent, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyPolicy(Color textColor) {
    return Text(
      'MELOD♪A respeta tu privacidad.\n\n'
      '• No recopilamos datos personales.\n'
      '• No enviamos información a servidores propios.\n'
      '• No compartimos datos con terceros.\n'
      '• No almacenamos ni rastreamos tu actividad.\n\n'
      'Permisos:\n'
      '• Audio/Almacenamiento: necesario para acceder a la música local.\n'
      '• Notificaciones: necesario para el control de reproducción en segundo plano (Android 13+).\n\n'
      'YouTube:\n'
      '• Las búsquedas se realizan a través de la YouTube Data API v3.\n'
      '• El audio se reproduce en memoria, sin descargar ni almacenar archivos.\n'
      '• No se recopilan datos de reproducción de YouTube.\n\n'
      'Si tenés preguntas, podés contactarnos a través de GitHub.',
      style: TextStyle(fontSize: 13, height: 1.6, color: MelodiaColors.textSecondary),
    );
  }
}

/// Pantalla dedicada con el disclaimer completo de YouTube API Services.
class YouTubeApiScreen extends StatelessWidget {
  const YouTubeApiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final textColor = theme.isDarkMode ? MelodiaColors.whiteSoft : Colors.black87;
    final accent = theme.effectiveAccent;
    final secondary = MelodiaColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.backgroundColor,
        title: Text('YouTube API Services',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
        iconTheme: IconThemeData(color: textColor),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.play_circle_outline, size: 48, color: accent),
          const SizedBox(height: 16),
          Text(
            'YouTube API Services',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textColor),
          ),
          const SizedBox(height: 16),

          Text(
            'Esta aplicación utiliza los YouTube API Services. '
            'El uso de estos servicios está sujeto a los Términos de Servicio de YouTube.',
            style: TextStyle(fontSize: 14, height: 1.6, color: secondary),
          ),
          const SizedBox(height: 20),

          Text(
            'Uso de la API',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '• La aplicación utiliza la YouTube Data API v3 para buscar y '
            'reproducir videos de YouTube en formato de streaming.\n'
            '• El audio se reproduce directamente en memoria mediante '
            'la API de streaming de YouTube.\n'
            '• No se descargan, almacenan ni distribuyen archivos multimedia.\n'
            '• No se recopilan datos personales de reproducción.\n'
            '• No se realizan llamadas a la API que no sean necesarias '
            'para el funcionamiento de la aplicación.',
            style: TextStyle(fontSize: 13, height: 1.7, color: secondary),
          ),
          const SizedBox(height: 20),

          Text(
            'Servicios utilizados',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '• YouTube Data API v3 — Búsqueda de videos y playlists.\n'
            '• YouTube Streaming API — Reproducción de audio en tiempo real.',
            style: TextStyle(fontSize: 13, height: 1.7, color: secondary),
          ),
          const SizedBox(height: 20),

          Text(
            'Enlaces importantes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 8),
          _linkTile(
            context,
            icon: Icons.description,
            label: 'Términos de Servicio de YouTube',
            url: 'https://www.youtube.com/t/terms',
            accent: accent,
          ),
          const SizedBox(height: 4),
          _linkTile(
            context,
            icon: Icons.privacy_tip,
            label: 'Política de Privacidad de Google',
            url: 'https://policies.google.com/privacy',
            accent: accent,
          ),
          const SizedBox(height: 4),
          _linkTile(
            context,
            icon: Icons.gavel,
            label: 'Política de API de Google',
            url: 'https://developers.google.com/terms',
            accent: accent,
          ),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Text(
              'Al usar esta aplicación, aceptás los Términos de Servicio '
              'de YouTube y la Política de Privacidad de Google.',
              style: TextStyle(fontSize: 13, height: 1.5, color: secondary, fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _linkTile(BuildContext context,
      {required IconData icon, required String label, required String url, required Color accent}) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: accent, decoration: TextDecoration.underline)),
            ),
            Icon(Icons.chevron_right, size: 18, color: accent.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
