import 'package:flutter/material.dart';

/// Rotta per i pannelli che salgono dal basso, al posto di
/// `showModalBottomSheet`.
///
/// Non e' un vezzo: `showModalBottomSheet` spinge una `ModalBottomSheetRoute`,
/// che e' una `PopupRoute`. Il controller degli Hero scarta il volo se la
/// rotta di partenza o di arrivo non e' una `PageRoute`
/// (`heroes.dart`, `_maybeStartHeroTransition`), quindi con un bottom sheet
/// l'Hero non parte mai: resta codice che non fa nulla. `PageRouteBuilder` e'
/// una `PageRoute`, e il volo funziona.
///
/// Il pannello sale di poco e sfuma, invece di scorrere per tutta l'altezza
/// dello schermo: mentre l'Hero e' in volo la sua destinazione si muove, e
/// meno si muove piu' l'atterraggio e' preciso. Il movimento lungo lo fa la
/// foto, non la cornice.
class RottaPannelloDalBasso<T> extends PageRouteBuilder<T> {
  RottaPannelloDalBasso({required WidgetBuilder costruttore})
    : super(
        pageBuilder: (context, _, _) => costruttore(context),
        // Sotto resta visibile il menu: senza questo lo sfondo diventa nero e
        // il pannello sembra staccato da dove si e' toccato.
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        barrierLabel: 'Chiudi',
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (context, animazione, _, child) {
          final curva = CurvedAnimation(
            parent: animazione,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curva,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curva),
              child: child,
            ),
          );
        },
      );
}
