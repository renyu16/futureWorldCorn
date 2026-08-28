import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF617BFF);
  static const Color yes = Color(0xFF16A34A);
  static const Color no = Color(0xFFDC2626);
  static const Color background = Color(0xFFF8F9FB);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E5E5);
  static const Color muted = Color(0xFF737373);
  static const Color foreground = Color(0xFF0A0A0A);

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      surface: card,
      onPrimary: Colors.white,
      onSurface: foreground,
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: border, width: 0.5),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: card,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: foreground),
      titleTextStyle: TextStyle(
        color: foreground,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: card,
      selectedColor: primary.withAlpha(25),
      side: const BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontSize: 13, color: foreground),
    ),
  );
}
