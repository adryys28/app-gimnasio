import 'package:flutter/material.dart';

/// Colores del prototipo: estilo "cuaderno de entrenamiento".
class Tema {
  static const fondo = Color(0xFFF3F0E8);
  static const tinta = Color(0xFF1B1A17);
  static const acento = Color(0xFFC2410C);
  static const secundario = Color(0xFF5C5850);
  static const borde = Color(0xFFDDD7CB);

  // Insignias de ajuste: el significado no depende solo del color (también icono y texto)
  static const sube = Color(0xFF9A3412);
  static const subeFondo = Color(0xFFFBE3D6);
  static const baja = Color(0xFF1D4E89);
  static const bajaFondo = Color(0xFFDCE7F3);
  static const mantiene = Color(0xFF45423C);
  static const mantieneFondo = Color(0xFFE9E5DC);

  static ThemeData claro() {
    final esquema = ColorScheme.fromSeed(seedColor: acento, primary: acento, surface: fondo);
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: fondo,
      appBarTheme: const AppBarTheme(backgroundColor: fondo, foregroundColor: tinta, elevation: 0),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: borde),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
