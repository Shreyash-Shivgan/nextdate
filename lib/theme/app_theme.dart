import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primaryNavy = Color(0xff0d1b2a);
  static const Color coralAccent = Color(0xffff6b6b);
  static const Color bgLight = Color(0xfffaf8f5);
  static const Color warmGold = Color(0xffffd166);
  static const Color cardWhite = Color(0xffffffff);
  static const Color softGrey = Color(0xff8e9aaf);

  // Afternoon Theme (Light Mode)
  static ThemeData get afternoonTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryNavy,
      colorScheme: const ColorScheme.light(
        primary: primaryNavy,
        secondary: coralAccent,
        tertiary: warmGold,
        surface: bgLight,
        onSurface: primaryNavy,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: bgLight,
      cardTheme: const CardThemeData(
        color: cardWhite,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        disabledColor: softGrey.withOpacity(0.2),
        selectedColor: coralAccent.withOpacity(0.15),
        secondarySelectedColor: warmGold.withOpacity(0.15),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: primaryNavy,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: coralAccent, width: 1),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: primaryNavy),
        displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: primaryNavy),
        displaySmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: primaryNavy),
        headlineLarge: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: primaryNavy),
        headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: primaryNavy),
        titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy),
        titleMedium: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: primaryNavy),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: primaryNavy),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: primaryNavy.withOpacity(0.8)),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: softGrey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coralAccent,
          foregroundColor: Colors.white,
          elevation: 4,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: coralAccent,
          side: const BorderSide(color: coralAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Evening Theme (Dark Mode)
  static ThemeData get eveningTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: coralAccent,
      colorScheme: const ColorScheme.dark(
        primary: coralAccent,
        secondary: coralAccent,
        tertiary: warmGold,
        surface: primaryNavy,
        onSurface: Colors.white,
        onPrimary: primaryNavy,
      ),
      scaffoldBackgroundColor: primaryNavy,
      cardTheme: const CardThemeData(
        color: Color(0xff162536),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        disabledColor: softGrey.withOpacity(0.2),
        selectedColor: coralAccent.withOpacity(0.2),
        secondarySelectedColor: warmGold.withOpacity(0.2),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: coralAccent, width: 1),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        displayMedium: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
        displaySmall: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        headlineLarge: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        headlineMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: Colors.white),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: Colors.white.withOpacity(0.8)),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: softGrey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: coralAccent,
          foregroundColor: primaryNavy,
          elevation: 6,
          shadowColor: coralAccent.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: coralAccent,
          side: const BorderSide(color: coralAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
