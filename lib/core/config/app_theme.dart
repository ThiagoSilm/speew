import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tema de Terminal Militar/Médico (Mission-Critical)
/// 
/// Utiliza cores de alto contraste, fundo escuro e fonte monoespaçada
/// para simular um display de terminal.
class AppTheme {
  static const Color primaryColor = Color(0xFF00FF41); // Verde Neon (Status OK)
  static const Color accentColor = Color(0xFFFF0041); // Vermelho Neon (Crítico)
  static const Color backgroundColor = Color(0xFF000000); // Preto Puro
  static const Color foregroundColor = Color(0xFF00FF41); // Cor principal do texto
  static const Color warningColor = Color(0xFFFFC300); // Amarelo (Aviso)
  static const Color infoColor = Color(0xFF00BFFF); // Azul (Informação)

  static ThemeData get missionCriticalTheme {
    final baseTheme = ThemeData.dark();

    return baseTheme.copyWith(
      // Cores principais
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      cardColor: Color(0xFF111111), // Fundo de cards levemente mais claro
      
      // Esquema de cores
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: primaryColor,
        secondary: accentColor,
        surface: backgroundColor,
        background: backgroundColor,
        error: accentColor,
        onPrimary: backgroundColor,
        onSecondary: backgroundColor,
        onSurface: foregroundColor,
        onBackground: foregroundColor,
        onError: backgroundColor,
        brightness: Brightness.dark,
      ),

      // Tipografia monoespaçada (Google Fonts - VT323 ou similar)
      textTheme: GoogleFonts.vt323TextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.vt323(fontSize: 57, color: foregroundColor),
        displayMedium: GoogleFonts.vt323(fontSize: 45, color: foregroundColor),
        displaySmall: GoogleFonts.vt323(fontSize: 36, color: foregroundColor),
        headlineLarge: GoogleFonts.vt323(fontSize: 32, color: foregroundColor),
        headlineMedium: GoogleFonts.vt323(fontSize: 28, color: foregroundColor),
        headlineSmall: GoogleFonts.vt323(fontSize: 24, color: foregroundColor),
        titleLarge: GoogleFonts.vt323(fontSize: 22, color: foregroundColor),
        titleMedium: GoogleFonts.vt323(fontSize: 16, color: foregroundColor),
        titleSmall: GoogleFonts.vt323(fontSize: 14, color: foregroundColor),
        bodyLarge: GoogleFonts.vt323(fontSize: 16, color: foregroundColor),
        bodyMedium: GoogleFonts.vt323(fontSize: 14, color: foregroundColor),
        bodySmall: GoogleFonts.vt323(fontSize: 12, color: foregroundColor),
        labelLarge: GoogleFonts.vt323(fontSize: 14, color: foregroundColor),
        labelMedium: GoogleFonts.vt323(fontSize: 12, color: foregroundColor),
        labelSmall: GoogleFonts.vt323(fontSize: 10, color: foregroundColor),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: primaryColor,
        elevation: 0,
        titleTextStyle: GoogleFonts.vt323(fontSize: 24, color: primaryColor),
      ),

      // Botões
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
          textStyle: GoogleFonts.vt323(fontSize: 18),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: BorderSide(color: primaryColor, width: 2),
          ),
        ),
      ),

      // Ícones
      iconTheme: IconThemeData(color: primaryColor),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: primaryColor.withOpacity(0.5),
        thickness: 1,
      ),
      
      // Card
      cardTheme: CardTheme(
        color: Color(0xFF0A0A0A),
        elevation: 5,
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: primaryColor.withOpacity(0.7), width: 1),
        ),
      ),
    );
  }
}
