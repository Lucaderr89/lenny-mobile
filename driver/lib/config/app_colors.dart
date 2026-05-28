import 'package:flutter/material.dart';

/// Colori dell'app Lenny Driver
class AppColors {
  // Primary Colors - Blu driver (diverso dal rosso customer)
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF64B5F6);
  static const Color primaryDark = Color(0xFF1976D2);

  // Secondary Colors
  static const Color secondary = Color(0xFF00BCD4);
  static const Color accent = Color(0xFFFFC107);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Splash Screen Colors - Giallo (simile a customer)
  static const Color splashGradientStart = Color(0xFFF6E644);
  static const Color splashGradientEnd = Color(0xFFFFD000);
  static const Color splashAccent = Color(0xFF2196F3); // Blu invece di rosa
  static const Color splashDark = Color(0xFF003B73);

  // Neutral Colors
  static const Color dark = Color(0xFF212121);
  static const Color light = Color(0xFFFAFAFA);
  static const Color gray = Color(0xFF9E9E9E);
  static const Color lightGray = Color(0xFFEEEEEE);

  // Background
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;

  // Text Colors
  static const Color textPrimary = dark;
  static const Color textSecondary = gray;
  static const Color textOnPrimary = Colors.white;

  // Shadows
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.05),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  static BoxShadow cardShadowHover = BoxShadow(
    color: Colors.black.withValues(alpha: 0.15),
    blurRadius: 16,
    offset: const Offset(0, 8),
  );

  // Gradient
  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [splashGradientStart, splashGradientEnd],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary],
  );
}
