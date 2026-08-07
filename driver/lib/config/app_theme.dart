import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tema dell'applicazione Lenny Driver.
///
/// UNA sola famiglia (Poppins) su TUTTO il TextTheme, con fontFamily di
/// default: gli slot non ridefiniti non devono mai ricadere sul font di
/// sistema (stesso difetto gia' corretto nell'app cliente).
///
/// Due temi completi: CHIARO per il giorno e NOTTE per il cruscotto — i
/// driver lavorano quasi solo la sera e uno schermo bianco abbaglia.
/// La scelta automatica/manuale la fa ThemeController.
class AppTheme {
  static TextTheme _testi(Color primario, Color secondario) {
    final base = GoogleFonts.poppinsTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: primario,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: primario,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: primario,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: primario,
      ),
      titleLarge: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: primario,
      ),
      titleMedium: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: primario,
      ),
      bodyLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: primario,
      ),
      bodyMedium: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: primario,
      ),
      bodySmall: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: secondario,
      ),
      labelLarge: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textOnPrimary,
      ),
    );
  }

  static InputDecorationTheme _input(Color bordo, Color focus) {
    OutlineInputBorder contorno(Color colore, [double spessore = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        borderSide: BorderSide(color: colore, width: spessore),
      );
    }

    return InputDecorationTheme(
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: contorno(bordo),
      enabledBorder: contorno(bordo),
      focusedBorder: contorno(focus, 2),
      errorBorder: contorno(AppColors.danger),
      focusedErrorBorder: contorno(AppColors.danger, 2),
    );
  }

  static ElevatedButtonThemeData _bottoni(Color sfondo) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: sfondo,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: _testi(AppColors.textPrimary, AppColors.textSecondary),
      inputDecorationTheme: _input(AppColors.lightGray, AppColors.primary),
      elevatedButtonTheme: _bottoni(AppColors.primary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        color: AppColors.surface,
        shadowColor: Colors.black.withValues(alpha: 0.05),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.nightPrimary,
        secondary: AppColors.secondary,
        surface: AppColors.nightSurface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.nightBackground,
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: _testi(AppColors.nightText, AppColors.nightTextSecondary),
      inputDecorationTheme: _input(
        AppColors.nightBorder,
        AppColors.nightPrimary,
      ),
      // I bottoni primari restano BLU pieno anche di notte: sono le azioni
      // principali e devono staccare dal fondo scuro.
      elevatedButtonTheme: _bottoni(AppColors.primary),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.nightPrimary,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.nightBorder),
        ),
        color: AppColors.nightSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.nightSurface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.nightText),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.nightText,
        ),
      ),
      dividerColor: AppColors.nightBorder,
    );
  }
}
