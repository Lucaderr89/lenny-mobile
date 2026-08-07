import 'package:flutter/material.dart';

/// Colori dell'app Lenny Driver
class AppColors {
  // Primary Colors - Blu del logo Lenny (il cappellino)
  static const Color primary = Color(0xFF0F4E8C);
  static const Color primaryLight = Color(0xFF5B93C9);
  static const Color primaryDark = Color(0xFF0B3A6B);

  // Secondary Colors
  static const Color secondary = Color(0xFF2AAEDF);
  static const Color accent = Color(0xFFFDD017);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Splash Screen Colors - Giallo (simile a customer)
  static const Color splashGradientStart = Color(0xFFF6E644);
  static const Color splashGradientEnd = Color(0xFFFFD000);
  static const Color splashAccent = Color(0xFF0F4E8C);
  static const Color splashDark = Color(0xFF0B3A6B);

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

  // Testo secondario scuro e bordi (allineati all'app cliente)
  static const Color grayDark = Color(0xFF595959);
  static const Color grayLight = Color(0xFFD8D8D8);

  // ── TEMA NOTTE (cruscotto) ────────────────────────────────────────────
  // I driver lavorano quasi solo la sera: fondi quasi neri, testo caldo ad
  // alto contrasto, niente bianchi accecanti. Gli stati restano riconoscibili
  // ma desaturati quel tanto che basta a non abbagliare.
  static const Color nightBackground = Color(0xFF10151C);
  static const Color nightSurface = Color(0xFF1A222C);
  static const Color nightSurfaceHigh = Color(0xFF232D3A);
  static const Color nightBorder = Color(0xFF2C3846);
  static const Color nightText = Color(0xFFF1F4F8);
  static const Color nightTextSecondary = Color(0xFF9AA7B4);
  static const Color nightPrimary = Color(0xFF5B93C9); // blu brand schiarito

  /// Ombra unica delle card (tema chiaro; di notte si usano i bordi)
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x14000000),
    blurRadius: 10,
    offset: Offset(0, 3),
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

  /// Gradiente dello splash NOTTE del driver (blu profondo, mondo "strada")
  static const LinearGradient splashNotteGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1626), Color(0xFF0B3A6B)],
  );
}

/// Ponte fra le schermate e il tema attivo.
///
/// Le schermate NON devono piu' scrivere colori fissi (bianco, grigio,
/// #212121): quelli restano chiari anche col tema notte attivo. Passando da
/// qui il colore lo decide il tema corrente, quindi lo stesso codice funziona
/// di giorno e di notte.
extension ColoriTema on BuildContext {
  bool get notte => Theme.of(this).brightness == Brightness.dark;

  /// Fondo della pagina
  Color get cSfondo =>
      notte ? AppColors.nightBackground : AppColors.background;

  /// Fondo delle card e delle superfici in rilievo
  Color get cCard => notte ? AppColors.nightSurface : Colors.white;

  /// Fondo delle superfici dentro una card (righe, box interni)
  Color get cCardAlta =>
      notte ? AppColors.nightSurfaceHigh : AppColors.background;

  /// Testo principale
  Color get cTesto => notte ? AppColors.nightText : AppColors.dark;

  /// Testo secondario / etichette
  Color get cTestoSec =>
      notte ? AppColors.nightTextSecondary : AppColors.gray;

  /// Bordi e separatori
  Color get cBordo => notte ? AppColors.nightBorder : AppColors.lightGray;

  /// Blu del brand, schiarito di notte per restare leggibile sul fondo scuro
  Color get cPrimario => notte ? AppColors.nightPrimary : AppColors.primary;

  /// Ombra delle card: di notte si usano i bordi, l'ombra sparirebbe comunque
  List<BoxShadow> get cOmbra =>
      notte ? const <BoxShadow>[] : const [AppColors.cardShadow];

  /// Bordo delle card: SOLO di notte. Su fondo scuro l'ombra non si vede e
  /// senza bordo la card si confonde col fondo; di giorno resta l'ombra.
  BoxBorder? get cBordoCard =>
      notte ? Border.all(color: AppColors.nightBorder) : null;
}

/// Raggi condivisi con l'app cliente: card 12, chip 8, sheet 24, pillola 100.
class AppRadius {
  AppRadius._();

  static const double card = 12.0;
  static const double chip = 8.0;
  static const double sheet = 24.0;
  static const double pill = 100.0;
}
