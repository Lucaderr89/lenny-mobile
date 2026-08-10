import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

/// Banner in testa alla navigazione: manovra corrente (o tappa) + dettaglio.
/// Stessa struttura del banner della console taxi, sui colori del tema Lenny.
class NavBanner extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String sottotitolo;
  final Color colore;

  const NavBanner({
    super.key,
    required this.icona,
    required this.titolo,
    required this.sottotitolo,
    required this.colore,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cCard.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cBordo),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: colore.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icona, color: colore, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                // Senza min la Column si prende TUTTA l'altezza che lo Stack
                // le concede e il banner copre lo schermo intero: il testo
                // della manovra e' due righe, l'altezza la fanno loro.
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.cTesto,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sottotitolo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.cTestoSec, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
