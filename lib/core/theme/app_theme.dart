import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'melodia_colors.dart';
import 'theme_provider.dart';

class AppTheme {
  static ThemeData build(ThemeProvider theme) {
    final brightness = theme.isDarkMode ? Brightness.dark : Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: theme.effectiveAccent,
      brightness: brightness,
      surface: theme.backgroundColor,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: theme.backgroundColor,
      colorScheme: scheme,
      textTheme: GoogleFonts.poppinsTextTheme(
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ),
      iconTheme: IconThemeData(
        color: brightness == Brightness.dark
            ? MelodiaColors.whiteSoft
            : Colors.black87,
      ),
      dividerColor: brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.06),
      splashColor: theme.effectiveAccent.withValues(alpha: 0.12),
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: brightness == Brightness.dark
            ? MelodiaColors.whiteSoft
            : Colors.black,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: brightness == Brightness.dark
              ? MelodiaColors.whiteSoft
              : Colors.black,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? const Color(0xFF12101A)
            : Colors.white,
        hintStyle: TextStyle(color: MelodiaColors.textSecondary, fontSize: 14),
        prefixIconColor: theme.effectiveAccent,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.effectiveAccent, width: 1),
          borderRadius: BorderRadius.circular(18),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}