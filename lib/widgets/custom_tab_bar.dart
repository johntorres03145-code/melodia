import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/melodia_colors.dart';
import '../core/theme/theme_provider.dart';

class CustomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const CustomTabBar({super.key, required this.currentIndex, required this.onTap});

  static const _tabs = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.search, Icons.search, 'Explorar'),
    (Icons.library_music_outlined, Icons.library_music, 'Library'),
    (Icons.favorite_outline, Icons.favorite, 'Favoritos'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final active = theme.effectiveAccent;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      decoration: BoxDecoration(
        color: theme.isDarkMode
            ? MelodiaColors.surfaceRaised
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    borderRadius: BorderRadius.circular(28),
                    splashColor: active.withValues(alpha: 0.1),
                    highlightColor: active.withValues(alpha: 0.05),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          i == currentIndex ? _tabs[i].$2 : _tabs[i].$1,
                          size: 22,
                          color: i == currentIndex
                              ? active
                              : MelodiaColors.textInactive,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].$3,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: i == currentIndex
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: i == currentIndex
                                ? active
                                : MelodiaColors.textInactive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
