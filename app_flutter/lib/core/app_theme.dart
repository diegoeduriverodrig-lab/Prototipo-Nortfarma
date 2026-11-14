import 'package:flutter/material.dart';

/// Colores de marca de Boticas Felicidad (tomados del logo).
class AppColors {
  static const turquesa = Color(0xFF28A8AB);
  static const turquesaOscuro = Color(0xFF1E8487);
  static const turquesaClaro = Color(0xFFE6F5F5);
  static const rojo = Color(0xFFFE0002);
  static const fondo = Color(0xFFF4F8F8);
  static const texto = Color(0xFF1F2A2E);
  static const textoSecundario = Color(0xFF6B7A80);
  static const borde = Color(0xFFDCE5E6);
  static const exito = Color(0xFF2E7D32);
  static const exitoClaro = Color(0xFFE8F5E9);
}

class AppTheme {
  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppColors.turquesa,
      primary: AppColors.turquesa,
      error: AppColors.rojo,
      surface: Colors.white,
    );

    final bordeRedondeado = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.borde),
    );

    return ThemeData(
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fondo,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: bordeRedondeado,
        enabledBorder: bordeRedondeado,
        focusedBorder: bordeRedondeado.copyWith(
          borderSide: const BorderSide(color: AppColors.turquesa, width: 1.6),
        ),
        errorBorder: bordeRedondeado.copyWith(
          borderSide: const BorderSide(color: AppColors.rojo),
        ),
        labelStyle: const TextStyle(color: AppColors.textoSecundario),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.turquesa,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.texto,
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.borde),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.turquesaOscuro),
      ),
    );
  }
}
