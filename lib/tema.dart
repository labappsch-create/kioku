import 'package:flutter/material.dart';

/// Colores de Kioku: Tradicional Kyokushin (ver docs/decisiones.md).
const Color rojoKioku = Color(0xFFC8102E);
const Color negroKioku = Color(0xFF111111);

ThemeData temaKioku() {
  final esquema = ColorScheme.fromSeed(seedColor: rojoKioku).copyWith(
    primary: rojoKioku,
    onPrimary: Colors.white,
    secondary: negroKioku,
    onSecondary: Colors.white,
    surface: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: negroKioku,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: rojoKioku,
      dividerColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: negroKioku,
      indicatorColor: rojoKioku,
      iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: rojoKioku,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: negroKioku,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
