import 'package:flutter/material.dart';

/// Colori dell'app Lenny Customer basati sui prototipi HTML
class AppColors {
  // Primary Colors - Blu del logo Lenny (il cappellino)
  static const Color primary = Color(0xFF0F4E8C); // blu profondo del marchio
  static const Color primaryLight = Color(0xFF5B93C9); // blu chiaro
  static const Color primaryDark = Color(0xFF0B3A6B); // blu scuro (inizio gradiente)
  static const Color primaryEnd = Color(0xFF1E6FB0); // blu medio (fine gradiente)

  // Secondary Colors - dai colori del cappellino
  static const Color secondary = Color(0xFF2AAEDF); // ciano della calotta
  static const Color accent = Color(0xFFFDD017); // giallo della visiera

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Splash Screen Colors - Giallo (dal prototipo splash)
  static const Color splashGradientStart = Color(0xFFF6E644);
  static const Color splashGradientEnd = Color(0xFFFFD000);
  static const Color splashAccent = Color(0xFF0F4E8C);
  static const Color splashDark = Color(0xFF0B3A6B);

  // Neutral Colors
  static const Color dark = Color(0xFF212121);
  static const Color light = Color(0xFFFAFAFA);
  static const Color gray = Color(0xFF9E9E9E);
  static const Color lightGray = Color(0xFFEEEEEE);
  static const Color grayDark = Color(0xFF595959); // testo secondario scuro
  static const Color grayLight = Color(0xFFD8D8D8); // bordi, divisori

  // Background
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Colors.white;

  // Text Colors
  static const Color textPrimary = dark;
  static const Color textSecondary = gray;
  static const Color textOnPrimary = Colors.white;

  // ---------------------------------------------------------------------------
  //  Colori delle categorie di cucina
  // ---------------------------------------------------------------------------
  /// Tavolozza per le pastiglie delle cucine in home.
  ///
  /// Due criteri, oltre al gusto:
  ///
  /// 1. Tonalita' medie, mai scure. Le icone delle cucine sono illustrazioni
  ///    con il contorno nero: su un fondo scuro il contorno sparisce e il
  ///    disegno si impasta.
  /// 2. Prevalenza di tinte fredde. Il cibo nelle icone e' quasi sempre caldo
  ///    (giallo, arancio, rosso), quindi su fondi freddi risalta; l'ambra
  ///    resta abbastanza profonda da non confondersi con una pizza.
  static const List<Color> categorie = [
    Color(0xFF3E8ED0), // blu
    Color(0xFF45BCA8), // verde acqua
    Color(0xFF9B87DE), // viola
    Color(0xFF4FBEE0), // ciano
    Color(0xFFE8A33D), // ambra
    Color(0xFF6C8AE4), // indaco
    Color(0xFF7FBF6A), // verde
    Color(0xFFE2857A), // corallo
  ];

  /// Colore stabile per una categoria, ricavato dal suo id.
  ///
  /// Legato all'id e non alla posizione nell'elenco: se il server cambia
  /// l'ordine o se ne aggiunge una, Pizzeria resta del colore di sempre invece
  /// di cambiare tinta a ogni apertura dell'app.
  static Color coloreCategoria(int id) {
    return categorie[id.abs() % categorie.length];
  }

  // Shadows
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  static BoxShadow cardShadowHover = BoxShadow(
    color: Colors.black.withOpacity(0.15),
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
    colors: [primaryDark, primaryEnd], // #ff5a5f → #ff8f6b
  );
}
