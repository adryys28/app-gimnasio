import 'package:flutter/material.dart';

/// Diseño V2: oscuro y deportivo (archivo de Figma "App Gimnasio - Rediseño oscuro").
class Tema {
  // Superficies
  static const fondo = Color(0xFF08090B);
  static const tarjeta = Color(0xFF121418);
  static const superficie2 = Color(0xFF22252C);
  static const borde = Color(0xFF2C3038);
  static const linea = Color(0x12FFFFFF); // blanco al 7 %

  // Texto
  static const texto = Color(0xFFF2F3F5);
  static const secundario = Color(0xFF9AA0AA);
  static const sobreAcento = Color(0xFF0E0F12);
  static const tinta = texto; // compatibilidad con pantallas anteriores

  // Acentos y estados (el estado nunca depende solo del color: también icono y texto)
  static const acento = Color(0xFFC6F432);
  static const baja = Color(0xFF38BDF8);
  static const fuego = Color(0xFFFF7A1A);
  static const sube = acento;
  static const mantiene = secundario;
  static const subeFondo = Color(0xFF2A3510);
  static const bajaFondo = Color(0xFF0C2A3A);
  static const mantieneFondo = Color(0xFF2A2D33);
  static const fuegoFondo = Color(0xFF3A1E0A);

  static const degradadoAcento = LinearGradient(colors: [acento, baja]);

  // Tipografía: Barlow Condensed en cursiva para cifras y titulares, Inter para el resto
  static const _display = 'Barlow Condensed';

  static TextStyle hero(double size, {Color color = texto}) => TextStyle(
      fontFamily: _display, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic,
      fontSize: size, height: 0.95, color: color);

  static TextStyle titular(double size, {Color color = texto}) => TextStyle(
      fontFamily: _display, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic,
      fontSize: size, height: 1, color: color);

  static TextStyle numero(double size, {Color color = texto}) => TextStyle(
      fontFamily: _display, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic,
      fontSize: size, height: 1, color: color);

  static TextStyle etiqueta({Color color = secundario}) =>
      TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 1, color: color);

  static ThemeData oscuro() {
    final esquema = ColorScheme.fromSeed(
      seedColor: acento,
      brightness: Brightness.dark,
      primary: acento,
      onPrimary: sobreAcento,
      surface: fondo,
      onSurface: texto,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: esquema,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: fondo,
      dividerColor: linea,
      appBarTheme: const AppBarTheme(backgroundColor: fondo, foregroundColor: texto, elevation: 0),
      cardTheme: CardThemeData(
        color: tarjeta,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: linea)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: acento,
          foregroundColor: sobreAcento,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: texto,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: borde, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: secundario)),
      chipTheme: ChipThemeData(
        backgroundColor: tarjeta,
        selectedColor: acento,
        side: const BorderSide(color: borde),
        labelStyle: const TextStyle(color: texto, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: sobreAcento, fontWeight: FontWeight.w600),
        checkmarkColor: sobreAcento,
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tarjeta,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: linea)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: linea)),
      ),
      snackBarTheme: const SnackBarThemeData(backgroundColor: superficie2, contentTextStyle: TextStyle(color: texto)),
    );
  }

  /// Compatibilidad: la app usa siempre el tema oscuro.
  static ThemeData claro() => oscuro();
}
