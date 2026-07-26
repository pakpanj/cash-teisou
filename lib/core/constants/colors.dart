import 'package:flutter/material.dart';

enum AppThemeMode { teisouHijau, darkMode, oceanBlue, sunsetOrange }

class AppThemes {
  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.darkMode:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE3F2FD),
          primaryColor: const Color.fromARGB(255, 64, 65, 66),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 64, 65, 66),
            foregroundColor: Colors.white,
          ),
          colorScheme: const ColorScheme.light(
            primary: Color.fromARGB(255, 64, 65, 66),
            secondary: Color.fromARGB(255, 64, 65, 66),
            surface: Colors.white,
          ),
        );

      case AppThemeMode.oceanBlue:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFE3F2FD),
          primaryColor: const Color(0xFF1565C0),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1565C0),
            foregroundColor: Colors.white,
          ),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1565C0),
            secondary: Color(0xFF0D47A1),
            surface: Colors.white,
          ),
        );

      case AppThemeMode.sunsetOrange:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFFFF3E0),
          primaryColor: const Color(0xFFF57C00),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF57C00),
            foregroundColor: Colors.white,
          ),
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFF57C00),
            secondary: Color(0xFFE65100),
            surface: Colors.white,
          ),
        );

      case AppThemeMode.teisouHijau:
        return ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          primaryColor: const Color.fromARGB(255, 2, 184, 14),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color.fromARGB(255, 2, 184, 14),
            foregroundColor: Colors.white,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 2, 184, 14),
            primary: const Color.fromARGB(255, 2, 184, 14),
          ),
        );
    }
  }
}

final ValueNotifier<AppThemeMode> globalThemeNotifier = ValueNotifier<AppThemeMode>(AppThemeMode.teisouHijau);