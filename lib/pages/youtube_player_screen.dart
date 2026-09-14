import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/theme/melodia_colors.dart';
import '../services/youtube_search.dart';

/// Reproduce un video de YouTube con el embebido oficial.
class YouTubePlayerScreen extends StatefulWidget {
  final YouTubeVideo video;
  const YouTubePlayerScreen({super.key, required this.video});

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen> {
  late final WebViewController _controller;
  bool _loadError = false;
  Timer? _errorCheckTimer;

  @override
  void initState() {
    super.initState();
    final html = '''
      <html>
        <head>
          <meta name="viewport"
            content="width=device-width, initial-scale=1.0, user-scalable=no">
          <style>
            html, body { margin:0; padding:0; background:#000; }
            #player { width:100vw; height:100vh; }
          </style>
        </head>
        <body>
          <iframe id="player"
            src="${widget.video.embedUrl}"
            title="YouTube" frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media;
                  gyroscope; picture-in-picture; web-share"
            referrerpolicy="strict-origin-when-cross-origin"
            allowfullscreen></iframe>
        </body>
      </html>
    ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final host = Uri.tryParse(request.url)?.host ?? '';
            if (host.endsWith('youtube.com') ||
                host.endsWith('google.com') ||
                host.endsWith('googlevideo.com') ||
                host.endsWith('ytimg.com') ||
                host.endsWith('ggpht.com')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (url) async {
            _checkForError();
          },
        ),
      )
      ..loadHtmlString(html);
  }

  /// Detecta el error 153 (y otros) mediante múltiples métodos.
  void _checkForError() async {
    if (!mounted || _loadError) return;

    // 1. Chequeo inmediato del document.title (ya existente).
    try {
      final title = await _controller.runJavaScriptReturningResult(
        "document.title",
      );
      final t = title.toString().toLowerCase();
      if (t.contains('error') || t.contains('no está disponible') ||
          t.contains('unavailable')) {
        if (mounted) setState(() => _loadError = true);
        return;
      }
    } catch (_) {}

    // 2. Timer de verificación: busca el overlay .ytp-error en el DOM.
    _errorCheckTimer?.cancel();
    _errorCheckTimer = Timer(const Duration(milliseconds: 2500), () async {
      if (!mounted || _loadError) return;
      try {
        final hasError = await _controller.runJavaScriptReturningResult(
          "document.querySelector('.ytp-error') !== null",
        );
        if (hasError.toString() == 'true' && mounted) {
          setState(() => _loadError = true);
        }
      } catch (_) {
        // Si falla la inyección JS, asumimos error.
        if (mounted) setState(() => _loadError = true);
      }
    });
  }

  Future<void> _openInYouTube() async {
    final url = Uri.parse(widget.video.watchUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _errorCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          widget.video.title,
          style: const TextStyle(fontSize: 16, color: MelodiaColors.whiteSoft),
        ),
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _loadError
                ? _fallbackPlayer()
                : WebViewWidget(controller: _controller),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: MelodiaColors.whiteSoft),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.channel,
                    style: const TextStyle(
                        fontSize: 14, color: MelodiaColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  if (_loadError) ...[
                    const Text(
                      'Este video no se puede reproducir embebido.\n'
                      'Puedes abrirlo en YouTube para escucharlo completo.',
                      style: TextStyle(
                          fontSize: 13, color: MelodiaColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Abrir en YouTube'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openInYouTube,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Reproducido con el reproductor oficial de YouTube.\n'
                      'Al cerrar esta pantalla, la música local sigue en tu mini player.',
                      style: TextStyle(
                          fontSize: 12, color: MelodiaColors.textInactive),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackPlayer() {
    return GestureDetector(
      onTap: _openInYouTube,
      child: Container(
        color: const Color(0xFF1A1A2E),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_circle_fill,
                  size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'Toca para abrir en YouTube',
                style: TextStyle(fontSize: 14, color: Colors.white54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
