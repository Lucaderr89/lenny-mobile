import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Trascina da qualunque punto per tornare indietro.
///
/// iOS di serie ascolta solo una striscia di una ventina di pixel sul bordo
/// sinistro, e su Android non c'e' nulla: in pratica l'unico modo di tornare
/// indietro era la freccia in alto, che nelle schermate lunghe sparisce appena
/// si scorre. Questo avvolge l'intera app e riconosce il gesto ovunque.
///
/// Sta SOPRA il Navigator, quindi partecipa all'arena dei gesti come antenato:
/// se il dito si trova dentro qualcosa che scorre in orizzontale — la barra
/// delle categorie, un carosello di piatti — vince quello, che e' piu' vicino
/// al tocco. Il gesto indietro scatta solo quando nessun altro lo reclama.
class GestoIndietroGlobale extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> chiaveNavigatore;

  const GestoIndietroGlobale({
    super.key,
    required this.child,
    required this.chiaveNavigatore,
  });

  @override
  State<GestoIndietroGlobale> createState() => _GestoIndietroGlobaleState();
}

class _GestoIndietroGlobaleState extends State<GestoIndietroGlobale> {
  double _percorso = 0;

  /// Quanto bisogna trascinare perche' valga come "indietro".
  ///
  /// Due strade alternative: un trascinamento ampio e deciso, oppure uno piu'
  /// corto ma lanciato. Serve a distinguerlo da uno scarto involontario del
  /// pollice mentre si legge.
  static const double _distanzaMinima = 90;
  static const double _velocitaMinima = 450;

  void _valuta(double velocita) {
    final navigatore = widget.chiaveNavigatore.currentState;
    if (navigatore == null || !navigatore.canPop()) {
      _percorso = 0;
      return;
    }

    final abbastanzaLungo = _percorso > _distanzaMinima;
    final abbastanzaVeloce = velocita > _velocitaMinima && _percorso > 24;

    if (abbastanzaLungo || abbastanzaVeloce) {
      HapticFeedback.lightImpact();
      navigatore.maybePop();
    }
    _percorso = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // deferToChild: i tocchi normali non passano di qui. Reclamiamo soltanto
      // i trascinamenti orizzontali, e solo se nessun figlio li vuole.
      behavior: HitTestBehavior.deferToChild,
      onHorizontalDragStart: (_) => _percorso = 0,
      onHorizontalDragUpdate: (d) {
        // Solo verso destra: trascinare a sinistra non riporta indietro.
        final delta = d.primaryDelta ?? 0;
        _percorso = delta > 0 ? _percorso + delta : 0;
      },
      onHorizontalDragEnd: (d) => _valuta(d.velocity.pixelsPerSecond.dx),
      onHorizontalDragCancel: () => _percorso = 0,
      child: widget.child,
    );
  }
}
