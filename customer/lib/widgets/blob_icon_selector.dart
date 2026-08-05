import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pastiglia con forma organica per le categorie di cucina.
///
/// Ogni categoria ha il proprio colore e lo tiene sempre, anche da ferma:
/// prima erano tutte grigie finche' non le toccavi, e la home sembrava spenta
/// rispetto al selettore iniziale delle categorie.
///
/// La selezione non puo' quindi piu' essere segnalata dal colore, che adesso
/// c'e' sempre: la indica un alone attorno alla pastiglia, piu' la lieve
/// inclinazione dell'icona.
///
/// ## Perche' l'alone non viene tagliato
///
/// Un alone e' una sfocatura che si estende oltre la sagoma. Disegnarlo
/// ingenuamente lo esporrebbe a due tagli: la ListView orizzontale ritaglia il
/// proprio riquadro, quindi la prima e l'ultima pastiglia lo perderebbero da
/// un lato; e con pochi pixel fra una pastiglia e l'altra finirebbe addosso
/// alla vicina.
///
/// Per questo la sagoma non riempie tutto il riquadro assegnato: [size] e' la
/// misura della casella, mentre la forma viene disegnata piu' piccola
/// lasciando attorno un margine (vedi [BlobPainter.margineAlone]) in cui
/// l'alone sta comodo. Cosi' resta dentro i confini della casella e non
/// dipende dallo spazio della vicina ne' dal ritaglio della lista.
class BlobIconSelector extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final VoidCallback onTap;

  /// Colore pieno della categoria.
  final Color selectedColor;

  /// Ignorato: resta per non rompere le chiamate esistenti.
  final Color unselectedColor;

  /// Lato della casella, alone compreso. La sagoma e' piu' piccola.
  final double size;

  const BlobIconSelector({
    super.key,
    required this.child,
    required this.isSelected,
    required this.onTap,
    this.selectedColor = const Color(0xFFFFD042),
    this.unselectedColor = const Color(0xFFE8E8E8),
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: BlobPainter(color: selectedColor, isSelected: isSelected),
          child: Center(
            child: Padding(
              // Il margine dell'alone piu' l'aria attorno all'icona.
              padding: EdgeInsets.all(BlobPainter.margineAlone + 6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: isSelected ? -0.15 : 0, // Inclinazione di ~8,6 gradi
                ),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, angle, child) {
                  return Transform.rotate(angle: angle, child: child);
                },
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Disegna la forma organica della pastiglia e, da selezionata, il suo alone.
class BlobPainter extends CustomPainter {
  /// Colore pieno della categoria.
  final Color color;
  final bool isSelected;

  /// Spazio lasciato libero fra il bordo della casella e la sagoma.
  ///
  /// E' la stanza in cui vive l'alone. Tenerlo qui, e non nel widget che
  /// disegna, e' cio' che impedisce all'alone di sconfinare sulla pastiglia
  /// vicina o di essere tagliato dal bordo della lista.
  static const double margineAlone = 9.0;

  /// Sigma della sfocatura interna.
  ///
  /// Una MaskFilter.blur si estende all'incirca per tre volte il proprio
  /// sigma: 3,5 significa una decina di pixel, cioe' quanto basta a stare in
  /// [margineAlone]. Alzarlo ancora renderebbe l'alone piu' ampio ma
  /// comincerebbe a invadere la pastiglia vicina.
  static const double _sigmaInterno = 3.5;

  /// Sigma della sfumatura esterna, quella che evita il bordo netto.
  static const double _sigmaEsterno = 5.5;

  /// Quanto l'alone viene allargato rispetto alla sagoma prima di sfocarlo.
  ///
  /// E' l'accorgimento che lo rende visibile. Sfocando la sagoma alla sua
  /// misura, meta' della sfocatura finisce sotto il riempimento opaco che
  /// viene disegnato sopra: si butta via meta' dell'alone e quel che resta si
  /// nota appena. Allargando il contorno prima di sfocarlo, la parte luminosa
  /// cade fuori dalla pastiglia, dove si vede.
  static const double _allargamentoAlone = 1.10;

  BlobPainter({required this.color, required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createBlobPath(size);

    // L'alone va sotto: disegnato dopo, la sfocatura coprirebbe il colore
    // pieno e lo intorbidirebbe.
    if (isSelected) {
      final centro = Offset(size.width / 2, size.height / 2);
      final ingrandimento = Matrix4.identity()
        ..translateByDouble(centro.dx, centro.dy, 0, 1)
        ..scaleByDouble(
          _allargamentoAlone,
          _allargamentoAlone,
          _allargamentoAlone,
          1,
        )
        ..translateByDouble(-centro.dx, -centro.dy, 0, 1);
      final sagomaAlone = path.transform(ingrandimento.storage);

      canvas.drawPath(
        sagomaAlone,
        Paint()
          ..color = color.withValues(alpha: 0.95)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _sigmaInterno),
      );
      canvas.drawPath(
        sagomaAlone,
        Paint()
          ..color = color.withValues(alpha: 0.40)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, _sigmaEsterno),
      );
    }

    // Colore pieno in entrambi gli stati: e' quello che tiene viva la home.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  /// Crea un path blob irregolare usando curve di Bézier
  /// Partendo da un cerchio, lo rende irregolare come nelle categorie
  Path _createBlobPath(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final centerX = width / 2;
    final centerY = height / 2;

    // La sagoma non riempie la casella: si ritira di [margineAlone] per
    // lasciare posto all'alone. Il divisore tiene conto della variazione
    // organica applicata sotto, che puo' allargare il raggio fino a circa
    // l'8%: senza, i lobi piu' sporgenti mangerebbero il margine.
    const massimaSporgenza = 1.08;
    final baseRadius =
        (math.min(width, height) / 2 - margineAlone) / massimaSporgenza;

    // Molti punti per forma fluida senza spigoli (come category screen)
    const numPoints = 24;
    final points = <Offset>[];

    // Crea un cerchio base e poi lo rende irregolare
    for (int i = 0; i < numPoints; i++) {
      final angle = (i / numPoints) * 2 * math.pi;

      // Piccole variazioni organiche per rendere il cerchio irregolare
      final noise1 = math.sin(angle * 2.3) * 0.035;
      final noise2 = math.cos(angle * 3.7) * 0.025;
      final noise3 = math.sin(angle * 5.1) * 0.015;

      final radiusVariation = 1.0 + noise1 + noise2 + noise3;
      final radius = baseRadius * radiusVariation;

      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      points.add(Offset(x, y));
    }

    // Inizio percorso
    path.moveTo(points[0].dx, points[0].dy);

    // Crea curve super fluide usando Catmull-Rom spline (come category screen)
    for (int i = 0; i < points.length; i++) {
      final p0 = points[(i - 1 + points.length) % points.length];
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      final p3 = points[(i + 2) % points.length];

      // Calcola punti di controllo per Catmull-Rom spline (massima morbidezza)
      const tension = 0.5;

      final cp1x = p1.dx + (p2.dx - p0.dx) / 6 * tension;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6 * tension;

      final cp2x = p2.dx - (p3.dx - p1.dx) / 6 * tension;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6 * tension;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant BlobPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isSelected != isSelected;
  }
}
