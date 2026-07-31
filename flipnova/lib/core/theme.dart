import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FlipNovaTheme {
  FlipNovaTheme._();

  static const Color bgPrimary = Color(0xFF0A0D14);
  static const Color bgCard = Color(0xFF111820);
  static const Color bgCardHover = Color(0xFF1A2332);
  static const Color cyan = Color(0xFF00E5FF);
  static const Color pink = Color(0xFFFF007F);
  static const Color orange = Color(0xFFFF6B00);
  static const Color green = Color(0xFF00FF41);
  static const Color greenDim = Color(0xFF00CC33);
  static const Color red = Color(0xFFFF1744);
  static const Color yellow = Color(0xFFFFD600);
  static const Color white = Color(0xFFE0E0E0);
  static const Color gray = Color(0xFF6B7A8D);
  static const Color border = Color(0xFF00E5FF);
  static const Color glassOverlay = Color(0x2600E5FF);

  static const double borderRadius = 12.0;
  static const double borderWidth = 1.0;
  static const double padding = 12.0;
  static const String fontFamily = 'JetBrains Mono';

  static TextStyle mono({Color color = white, double fontSize = 14, FontWeight weight = FontWeight.normal}) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: fontSize,
      fontWeight: weight,
      letterSpacing: 1,
    );
  }

  static ThemeData get theme {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: pink,
        surface: bgCard,
        error: red,
        onPrimary: bgPrimary,
        onSecondary: white,
        onSurface: white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          color: cyan,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
        iconTheme: const IconThemeData(color: cyan),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          side: const BorderSide(color: border, width: borderWidth),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.jetBrainsMono(color: white, fontSize: 16),
        bodyMedium: GoogleFonts.jetBrainsMono(color: white, fontSize: 14),
        bodySmall: GoogleFonts.jetBrainsMono(color: gray, fontSize: 12),
        titleLarge: GoogleFonts.jetBrainsMono(color: cyan, fontSize: 20, fontWeight: FontWeight.bold),
        titleMedium: GoogleFonts.jetBrainsMono(color: cyan, fontSize: 16, fontWeight: FontWeight.bold),
        labelLarge: GoogleFonts.jetBrainsMono(color: cyan, fontSize: 14, fontWeight: FontWeight.bold),
      ),
      dividerColor: bgCardHover,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgCard,
        hintStyle: GoogleFonts.jetBrainsMono(color: gray, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: gray, width: borderWidth),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: gray, width: borderWidth),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: cyan, width: borderWidth),
          borderRadius: BorderRadius.all(Radius.circular(borderRadius)),
        ),
        prefixIconColor: cyan,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgCard,
          foregroundColor: cyan,
          elevation: 0,
          side: const BorderSide(color: cyan, width: borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          textStyle: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: cyan),
    );
  }
}
